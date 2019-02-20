#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use NodeTree;

use lib 'MooNode';
use MooDir;
use MooFile;

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * return number of changes for dir update - total changes
# * Cleanup debug prints & add a write to log?
# * Move capture dupes, check dupes, save dupes to module
# * Make scan dir smarter - check and move to new list
# * Function, check if dir need scan?
# * Delta stats function
# * update based upon what's changed.
# * Change Dir List to dir_list?


# Notes Perf
# 
# Tested on ~/Downloads, no updates required
# time ./scan-md5.pl -f -v 2 -t ~/Downloads
#
# scan-md5-2       9.647u 7.403s 0:24.47 69.6%	0+0k 0+9io 0pf+0w
# scan-md5         9.729u 7.648s 0:24.81 69.9%	0+0k 0+4io 0pf+0w
# scan-smart-md5   4.722u 3.266s 0:11.74 67.9%	0+0k 0+0io 0pf+0w

my %size_count;

my ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);

my $db_name =  ".moo.db";

our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree = 0;
our $md5_save_limit = 100;

GetOptions (
    'debug=i'     => \$debug,
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
    'quick'       => \$fast_dir,
    'tree'        => \$tree,
);

if ($debug or $verbose >= 2){
    say "Options";

    say "\tDebug: ", $debug;
    say "\tVerbose: ", $verbose;
    say "\tFast: ", $fast_scan;
    say "\tQuick Dir: ", $fast_dir;
    say "\tTree: ", $tree;

    say " ";
}

# If existing file of dupe sizes, load
&load_dupes(dupes => \%size_count);

#
# Scan each arg as dir, using dir or tree scan.
#
foreach my $dir (@ARGV){
    if ($tree){
	say "Scanning Tree: $dir" if ($verbose >= 0); 
	find(\&wanted,  $dir);
    } else {
	say "Scanning Dir: $dir" if ($verbose >=0 ); 
	update_dir_md5_2(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
    }
}

&save_dupes(dupes => \%size_count);

exit;



#
# File find wanted sub. For any file that is a readable and writeable dir 
# 
sub wanted {
    return unless (-d $File::Find::name);   # if not dir, skip
    return unless (-r $File::Find::name);   # if not readable skip
    return unless (-w $File::Find::name);   # if not writeable skip

    my  $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs

    # Skip hidden or write protected dirs
    my $flags = FileUtility::osx_check_flags_binary($dir);
    if ($flags & ($FileUtility::osx_flags{"hidden"} | $FileUtility::osx_flags{uchg}) ){
	return;
    }
    update_dir_md5_2(dir=>$dir, fast_scan=>$fast_scan, fast_dir=>$fast_dir);

    return;
}

#
# Required changes based upon stats changed
#
# Files
#
# dev inode size - delete from List and re-insert since index values will change
# mode nlink uid gid rdev   - update stats
# size mtime blksize blocks - update md5, stats
# ctime      - update flags - update flags, maybe filename
# 
#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
#
# BUG  -need to update dir before other files
#
sub update_dir_md5_2 {
    my %opt = @_;
    my $fast_scan =  delete $opt{fast_scan} // 0;
    my $fast_dir  =  delete $opt{fast_dir}  // 0;
    my $dir       =  delete $opt{dir} or die "Missing param to scan_dir_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;


    ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
    say "Scanning $dir" if ($verbose >= 2);

    my $Dir = MooDir->new(filepath => $dir);

    my $Tree_old = NodeTree->new(name => $dir);
    my $Tree_new = NodeTree->new(name => $dir);

    #
    # Recode - can we combine two loops?
    #
    if (-e "$dir/$db_name"){
	$Tree_old = NodeTree->load(dir => $dir, name => $db_name);
	
	# Scan through objs and see if any changed.
	# Problem if go pass File, not exist, then find later. Or if process and move out

	# 
	my @Nodes = ($Tree_old->Search(dir => 1), $Tree_old->Search(file => 1));
	
	foreach my $Node (@Nodes){
	    my $changes;

	    say "    File: ", $Node->filename if ($verbose >= 3);

	    # If doesn't exist on disk - leave in old list for now
	    next if (!-e $Node->filepath);
	    #
	    # ToDo
	    # * optimize - can use lstat to detect file dos not exist, save a stat
	    my @stats_new = lstat($Node->filepath);

	    # Check changes and mask off atime changes
	    $changes = FileUtility::stats_delta_binary($Node->stat,  \@stats_new);
	    $changes = $changes & ~$FileUtility::stats_names{atime};

	    # If the inode has changed, this is not the same file. We used filename and did stat on new file
	    # Dir must have changed.
	    if ($changes & $FileUtility::stats_names{ino}){
		say "Skipping file - inode changed Old Name", $Node->filename;
		next;
	    }

	    # Remove from Old List
	    # Since some changes modify size, md5 or inode - and they are indexed by that, we need
	    # to remove from old List. modify, then insert into new list
	    $Tree_old->Delete($Node);

	    # Make requied updates
	    if ($changes){
		my @changes = FileUtility::stats_delta_array($changes);
		say "    File: ", $Node->filename if ($verbose == 2);
		say "        Delta: ", join(", ", @changes) if ($verbose >= 2);
		printf "\t\t\tThe binary representation is: %013b\n", $changes if ($verbose >= 2);

		$Node->stat(\@stats_new);                    # always update stats some changed

		# Decide what needs to be changed based upon what stats changed
		# if dev or blksize changes - is error - should not happen
		if ($changes & ( $FileUtility::stats_names{dev} | $FileUtility::stats_names{blksize} )) {
		    die("Stats Delta Illegal stats change: ", join(", ", @changes));
		}

		# If ctime - maybe flags changed
		# ToDo
		# * print flags delta
		if ($changes & ( $FileUtility::stats_names{ctime})) {
		    $Node->update_flags
		}

		# If mtime, size or blocks changed - then clear old md5
		if ( $changes & ( $FileUtility::stats_names{mtime} | $FileUtility::stats_names{size}) ){
		    if ($Node->can('md5')){
			# say "Clear md5";
			$Node->_set_md5(undef);
		    }	
		}

		if ($Node->isdir){
		    update_dir(dir => $Dir, Files_New => $Tree_new, Files_old => $Tree_old, 
			       update_md5 => ! $fast_scan)
		}
		$files_change++;
	    }

	    $size_count{$Node->size}++;
	    my $count = $size_count{$Node->size};

	    # If can do MD5 value, the obj dos not have one and is readable - calculate it
	    if ($Node->can('md5') && ! defined $Node->md5 && $Node->isreadable) {
		if (! $fast_scan or  $count >= 2){
		    say "    Update MD5: ", $Node->filename if ($verbose == 2);
		    $Node->update_md5;
		    $files_change++
		}
	    }


	    # Insert in new list
	    if ($Tree_new->Search(hash => $Node)) {
		warn "    Tried to inert dupe Node ".$Node->filename;
		my ($Dupe) = $Tree_new->Search(hash => $Node);
		warn "        Old: ".$Dupe->filename;
	    } else {
		$Tree_new->insert($Node);
	    }
	    

	}

    } else {
	# No db_file exists

	# Trick. Create empty db_file and update Dir object, so when check later no changes to dir
	say "\tdb_file does not exists - create empty one." if ($verbose >= 2);
     	`touch "$dir/$db_name"`;
     	$Dir = MooDir->new(filepath => $dir);

	# New Dir - Insert Dir object and then list dir and add files
	$Tree_new->insert($Dir);
	$files_change += update_dir(dir => $Dir, Files_New => $Tree_new, Files_old => $Tree_old, 
				    update_md5 => ! $fast_scan);
    }


    # Done scanning old files, check if records left - file must have been deleted, or moved to new dir
    # A renamed file we would have caught becuase the inode stayed the same
    my @Files = $Tree_old->List;
    $files_delete += scalar(@Files);
    if (@Files >= 1 && $verbose >= 1){
    	say "\tDeleted files:";
    	foreach my $File (@Files){
    	    say "\t\t", $File->filename;
    	}
    }

    if ($files_change > 0){ 
	$Tree_new->save(name => $db_name);
	# $Tree_new->save_packed;	# For debug
    }

    return;
}

#
# Process New Dir
# * This is only for creating a new dir where we have no db_file already.
#   Skips dir, does not follow sym links
#
# Pass in Dir object, link to new files list
#
# sub add_dir {
#     my %opt = @_;
#     my $new_files = 0;

#     my $Dir         = delete $opt{dir} or die "Missing param 'Dir'";
#     # my $Tree_old    = delete $opt{Files_old} or die "Missing param 'Files_old' to update_file";
#     my $Tree_new    = delete $opt{Files_New} or die "Missing param 'Files_new' to update_file";
#     # my $fast_scan   = delete $opt{fast_scan} // 0;
#     my $update_md5  = delete $opt{update_md5} // 0;
#     my $verbose     = delete $opt{verbose} // $main::verbose;
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     # First check that dir exists, is dir, is readable & writeable
#     my $filepath = $Dir->filepath;
#     if (!-e $filepath or ! -r _ or ! -w _){
# 	warn("Bad dir: $filepath for add dir");
# 	return($new_files);
#     }

#     # Now process each file
#     # Need parm to list for md5 update or not
#     my @Files = $Dir->List(update_md5 => $update_md5);

#     foreach my $File (@Files) {
# 	# Debug check - check if file already in new files list
# 	if ($Tree_new->Search(hash => $File) ){
# 	    warn("Tried to insert file already in new files list");
# 	} else {
# 	    $Tree_new->insert($File);
# 	    $new_files++;
# 	}
#     }
#     say "Added $new_files files";

#     return($new_files);
# }


#
# Pass in Dir object, link to new files list, old files list
# This function does not deal with new dirs in dir - only new files in dir
#
sub update_dir {
    my %opt = @_;
    my $new_files = 0;

    my $Dir         = delete $opt{dir} or die "Missing param 'Dir'";
    my $Tree_old    = delete $opt{Files_old} or die "Missing param 'Files_old' to update_file";
    my $Tree_new    = delete $opt{Files_New} or die "Missing param 'Files_new' to update_file";
    my $update_md5  = delete $opt{update_md5} // 1;
    my $verbose     = delete $opt{verbose} // $main::verbose;
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $filepath = $Dir->filepath;
  
    # Loop through files in dir & process. Do own dir list so can save stats and use
    # my @filepaths = $Dir->list_filepaths;
    my ($filepaths_r, $names_r, $stats_AoA_r, $flags_AoA_r) = FileUtility::dir_list(dir => $filepath, inc_file => 1, use_ref => 1);

    # my @filepaths = @{$filepaths_r}; 

    say "    New Dir Check File: $filepath";

    # foreach my $filepath (@filepaths){
    foreach (0..( scalar(@{$filepaths_r}) - 1) ){
	my $filepath = @{$filepaths_r}[$_];
	# my @stats = lstat($filepath);
	my @stats = @{ ${$stats_AoA_r}[$_] };
	my $hash = $stats[0].'-'.$stats[1];
	
	if ( $Tree_new->Search(hash => $hash) ){ # In New tree - can skip further processing
	    say "    Update dir - existing - new List skip $filepath";
	    next;
	}

	# Optimize - while have stats update file and move to new
	# Obj In Old Tree - update filepath if needed and leave in old tree
	my ($Old_file) = $Tree_old->Search(hash => $hash);
	if ($Old_file){ 
	    if ($filepath ne $Old_file->filepath){
		$Old_file->filepath($filepath);
		say "Update dir - rename existing - old List skip $filepath";
	    }
	    next;
	}
	
	# Not in either tree so must be new file
	say "Update Dir - new file - $filepath";
	my $File = MooFile->new(filepath => $filepath, stat => [ @stats ], update_stat => 0, 
				opt_update_md5 => 0);

	$size_count{$File->size}++;
	my $count = $size_count{$File->size};
	my $calc_md5 = ($update_md5 or ($count >= 2));
	if ($calc_md5){
	    $File->update_md5;
	}

	$Tree_new->insert($File);
	$new_files++;
    }

    return ($new_files);
}

