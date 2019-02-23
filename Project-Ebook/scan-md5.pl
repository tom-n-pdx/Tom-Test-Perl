#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use NodeTree;
use FileUtility qw(osx_check_flags_binary %osx_flags 
		   dir_list 
		   stats_delta_binary %stats_names);

use lib 'MooNode';
use MooDir;
use MooFile;

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * Cleanup debug prints & add a write to log?
# !! try if move dir, name dir changes

# Notes Perf
# 
# Tested on ~/Downloads, no updates required. PLUGGED IN
# time ./scan-md5.pl -f -v 2 -t ~/Downloads
#
# scan-md5         9.647u 7.403s 0:24.47 69.6%	0+0k 0+9io 0pf+0w
# * 1 less stat    4.736u 3.386s 0:11.72 69.1%	0+0k 0+3io 0pf+0w
#                  4.715u 3.868s 0:11.64 73.6%	0+0k 0+3io 0pf+0w
#
# scan-md5-old     9.729u 7.648s 0:24.81 69.9%	0+0k 0+4io 0pf+0w
# scan-smart-md5   4.722u 3.266s 0:11.74 67.9%	0+0k 0+0io 0pf+0w
#                  0.483u 0.050s 0:00.54 98.1%	0+0k 0+1io 29pf+0w

my %size_count;
 
our ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);

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
	scan_dir_md5(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
    }
}

&save_dupes(dupes => \%size_count);

exit;



#
# File find wanted sub. For any file that is a readable and writeable dir 
# 
sub wanted {
    return unless (-d $File::Find::name);   # if not dir, skip
    return unless (-r _);   # if not readable skip
    return unless (-w _);   # if not writeable skip

    my  $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs

    # Skip dirs with hidden or write protected flags set
    my $flags = osx_check_flags_binary($dir);
    if ($flags & ($osx_flags{hidden} | $osx_flags{uchg}) ){
	return;
    }
    scan_dir_md5(dir=>$dir, fast_scan=>$fast_scan, fast_dir=>$fast_dir);

    return;
}

#
#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
#
sub scan_dir_md5 {
    my %opt = @_;
    my $fast_scan =  delete $opt{fast_scan} // 0;
    my $fast_dir  =  delete $opt{fast_dir}  // 0;
    my $dir       =  delete $opt{dir} or die "Missing param to scan_dir_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
    say "  Checking $dir" if ($verbose >= 2);

    my $Dir_old;
    my $Tree_old;

    my $Dir_new;
    my $Tree_new = NodeTree->new(name => $dir);

    #
    # Recode - can we combine two loops?
    #
    if (-e "$dir/$db_name"){
	my $db_mtime = (stat(_))[9];
	say "\tdb_file exists " if ($verbose >= 3);

	$Dir_new = MooDir->new(filepath => $dir, update_dtime => $fast_dir);	

	if ($fast_dir && $db_mtime >= $Dir_new->dtime){
	    say "\tQuick Dir scan enabled, No Files chaged, Skip scan" if ($verbose >= 2);
	    return( () );
	}

	# say "Loaded Tree Packed";
	# $Tree_old = NodeTree->load_packed(dir => $dir);
	$Tree_old = NodeTree->load(dir => $dir);
	
	# First process Dir, then Files
	my @Dirs_old = $Tree_old->Search(dir => 1);
	if (@Dirs_old != 1){
	    die "db_file does not contain only one Dir record $dir";
	}
	$Dir_old = $Dirs_old[0];


	# Delete from old list, update & insert in new list
	$Tree_old->Delete($Dir_old);

	# Check for changes and mask atime changes - a dir name change will not change dir stats
	my $changes = stats_delta_binary($Dir_new->stats, $Dir_old->stats) & ~$stats_names{atime};
	
	# say "Dir Delta: $changes";
	# say "Dir Old Before Change: ", $Dir_old->dump;

	if ($changes or $Dir_old->filepath ne $dir){
	    update_file_md5(Node => $Dir_old, changes => $changes, stats => $Dir_new->stats, update_md5 => ! $fast_scan);

	    if ($Dir_old->filepath ne $Dir_new->filepath){
		$Dir_old->filepath($Dir_new->filepath);
		say "    Dir rename";
	    }
	    update_dir_md5(Dir => $Dir_old, changes => $changes, stats => $Dir_new->stats, 
			   Tree_new => $Tree_new, Tree_old => $Tree_old, 
			   update_md5 => ! $fast_scan, inc_dir => 0);
	    $files_change++;
	}
	$Tree_new->insert( $Dir_old );
	# say "Dir Old After Change: ", $Dir_old->dump;


	# Now scan through files
	foreach my $Node ($Tree_old->Search(file => 1) ){
	    say "    ", $Node->type, " ", $Node->filename if ($verbose >= 3);

	    # If doesn't exist on disk - leave in old list for now
	    my @stats_new = lstat($Node->filepath); # If no stats, file does not exist
	    next if (! @stats_new);

	    # Check changes and mask off atime changes
	    my $changes = stats_delta_binary($Node->stats,  \@stats_new) & ~$stats_names{atime};

	    # If the inode has changed, this is not the same file
	    next if ($changes & $stats_names{ino});

	    # Remove from Old List
	    # Since some changes modify size, md5 - and they are indexed by that, we need
	    # to remove from old List, update, then insert into new list
	    $Tree_old->Delete($Node);

	    # Make requied updates
	    # update_file($Node, $changes, @stats_new);

	    if ($changes){
		update_file_md5(Node => $Node, changes => $changes, stats => \@stats_new, 
				update_md5 => ! $fast_scan);
	    }
	    # Insert in new list
	    $Tree_new->insert($Node);

	}
    } else {
	# No db_file exists
	$Tree_old = NodeTree->new(name => $dir);

	# Trick. Create empty db_file and update Dir object, so when check later no changes to dir
	say "\tdb_file does not exists - create empty one." if ($verbose >= 2);
     	`touch "$dir/$db_name"`;
     	$Dir_new = MooDir->new(filepath => $dir, update_dtime => 0);

	# New Dir - Insert Dir object and then list dir and add files
	$Tree_new->insert($Dir_new);
	$files_change += update_dir_md5(Dir => $Dir_new, stats => $Dir_new->stats, changes => 0,
					Tree_new => $Tree_new, Tree_old => $Tree_old, 
					update_md5 => ! $fast_scan);
    }


    # Done scanning old files, check if any objs left - file must have been deleted, or moved to new dir
    # A renamed file we would have caught becuase the inode stayed the same
    my @Files = $Tree_old->List;
    $files_delete += scalar(@Files);
    $files_change += scalar(@Files);
    if (@Files >= 1 && $verbose >= 1){
    	say "\tDeleted files:";
    	foreach my $File (@Files){
    	    say "\t\t", $File->filename;
    	}
    }

    if ($files_change > 0 or $files_md5 > 0){ 
	say "Saved File";
	$Tree_new->save(name => $db_name);
	# $Tree_new->save_packed; # For debug
    }

    say ("    Changes: $files_change New: $files_new") if ($verbose >= 2 or ($files_change > 0 && $verbose >= 2));
    return;
}

# # Required changes based upon stats changed
# #
# # Files
# #
# # dev inode size - delete from List and re-insert since index values will change
# # mode nlink uid gid rdev   - update stats
# # size mtime blksize blocks - update md5, stats
# # ctime      - update flags - update flags, maybe filename
# #
# sub update_file {
#     my $Node      = shift(@_);
#     my $changes   = shift(@_);
#     my @stats_new = @_;

#     if ($changes){
# 	$files_change++;
# 	my @changes = FileUtility::stats_delta_array($changes);
# 	say "    File: ", $Node->filename if ($verbose == 2);
# 	say "        Delta: ", join(", ", @changes) if ($verbose >= 2);
# 	printf "\t\t\tThe binary representation is: %013b\n", $changes if ($verbose >= 2);

# 	$Node->stats(\@stats_new);        # always update stats if some changed

# 	# Decide what needs to be changed based upon what stats changed
# 	# if dev or blksize changes - is error - should not happen
# 	if ($changes & ( $stats_names{dev} | $stats_names{blksize} )) {
# 	    die("Stats Delta Illegal stats change: ", join(", ", @changes));
# 	}

# 	# If ctime - maybe flags changed
# 	if ($changes & ( $stats_names{ctime})) {
# 	    $Node->update_flags
# 	}

# 	# If mtime, size or blocks changed - then clear old md5
# 	if ( $changes & ( $stats_names{mtime} | $stats_names{size}) ){
# 	    if ($Node->can('md5')){
# 		$Node->md5(undef);
# 	    }	
# 	}
#     }

#     # Even if no changs, need to maybe update md5
#     $size_count{$Node->size}++;
#     my $count = $size_count{$Node->size};

#     if ($Node->can('md5') && ! defined $Node->md5 && $Node->isreadable) {
# 	if (! $fast_scan or  $count >= 2){
# 	    say "    Update MD5: ", $Node->filename if ($verbose == 2);
# 	    $Node->update_md5;
# 	    $files_change++
# 	}
#     }
#     return;
# }


# #
# # Pass in Dir object, link to new files list, old files list
# # This function does not deal with dirs in dir - only files in dir
# #
# sub update_dir {
#     my %opt = @_;
#     my $new_files = 0;

#     my $Dir         = delete $opt{dir} or die "Missing param 'Dir'";

#     my $Tree_old    = delete $opt{Files_old} or die "Missing param 'Files_old' to update_file";
#     my $Tree_new    = delete $opt{Files_New} or die "Missing param 'Files_new' to update_file";

#     my $update_md5  = delete $opt{update_md5} // 1;
#     my $verbose     = delete $opt{verbose}    // $main::verbose;
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $filepath = $Dir->filepath;
  
#     say "    Dir Changes Check File: $filepath";

#     # Loop through files in dir & process. Use extended version of dir_list so have stats & flags
#     my ($filepaths_r, $names_r, $stats_AoA_r, $flags_r) = dir_list(dir => $filepath, inc_file => 1, use_ref => 1);
#     foreach ( 0..$#{$filepaths_r} ){
# 	my $filepath  = @{$filepaths_r}[$_];
# 	my @stats     = @{ ${$stats_AoA_r}[$_] };
# 	my $flags     = @{$flags_r}[$_];

# 	my $hash      = $stats[0].'-'.$stats[1];

# 	if ( $Tree_new->Exist(hash => $hash) ){ # In New tree - can skip further processing
# 	    say "    Update dir - existing - new List skip $filepath";
# 	    next;
# 	}

# 	# Obj In Old Tree - update filepath if needed & do file updates
# 	# Optimize - have stats, update file
# 	# But problem is that if we move from old to new, will have error becuase it's still in old list
# 	#
# 	my ($Old_file) = $Tree_old->Exist(hash => $hash);
# 	if ($Old_file){ 
# 	    if ($filepath ne $Old_file->filepath){
# 		$Old_file->filepath($filepath);
# 		say "    Update dir - rename existing - old List skip $filepath";
# 		$files_change++;
# 	    }
# 	    next;
# 	}
	
# 	# Not in either tree so must be new file
# 	say "    Update Dir - new file - $filepath";
# 	my $File = MooFile->new(filepath => $filepath, 
# 				stats => [ @stats ], update_stats => 0, 
# 				flags => $flags,     update_flags => 0,
# 				opt_update_md5 => 0);

# 	$size_count{$File->size}++;
# 	my $count = $size_count{$File->size};

# 	my $calc_md5 = ($update_md5 or ($count >= 2));
# 	if ($calc_md5 && $File->isreadable && $File->can('md5')){
# 	    $File->update_md5;
# 	}

# 	$Tree_new->insert($File);
# 	$files_new++;
# 	$files_change++
#     }

#     return ($new_files);
# }

