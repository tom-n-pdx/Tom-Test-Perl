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
use FileUtility;

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * return number of changes for dir update - total changes
# * Cleanup debug prints & add a write to log?
# * Move capture dupes, check dupes, save dupes to module
# * Function, check if dir need scan?
# * test if list dir function really geting flags

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
	update_dir_md5(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
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

    my $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs

    # Skip hidden or write protected dirs
    my $flags = FileUtility::osx_check_flags_binary($dir);
    if ($flags & ($FileUtility::osx_flags{"hidden"} | $FileUtility::osx_flags{uchg}) ){
	return;
    }

    update_dir_md5(dir=>$dir, fast_scan=>$fast_scan, fast_dir=>$fast_dir);

    return;
}


#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
sub update_dir_md5 {
    my %opt = @_;
    my $fast_scan =  delete $opt{fast_scan} // 0;
    my $fast_dir  =  delete $opt{fast_dir}  // 0;
    my $dir       =  delete $opt{dir} or die "Missing param to scan_dir_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    return unless (-d $dir);  # if not dir, skip
    return unless (-r _);     # if not readable skip
    return unless (-w _);     # if not writeable skip


    ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
    say "Scanning $dir" if ($verbose >= 2);

    # If not doing fast dir check, don't need he slow calc of dtime
    my $Dir  = MooDir->new(filepath => $dir, update_dtime => ! $fast_dir);

    my $Tree_old = NodeTree->new(name => $dir);
    my $Tree_new = NodeTree->new(name => $dir);      # Store new files in Tree

    # Check if exiisting datafile
    if (-e "$dir/$db_name"){
	say "\tdb_file exists " if ($verbose >= 2);
	my $db_mtime = (stat(_))[9];
	if ($fast_dir && $db_mtime >= $Dir->dtime){
	    say "\tQuick Dir scan enabled, No Files chaged, skip scan" if ($verbose >= 2);
	    return( () );
	}

	$Tree_old = NodeTree->load(dir => $dir, name => $db_name);
    } else {
	# trick, need to create empty datafile at start of check, so Dir changes mtime includes the new file
	say "\tdb_file does not exists - create empty one." if ($verbose >= 2);
	`touch "$dir/$db_name"`;
    }
    # Make sure Dor obj updated after done messing around with save file
    $Dir  = MooDir->new(filepath => $dir, update_dtime => 0);

    
    # Scan through all files in dir and the Dir obj. Can process Dir just like any other object
    # By default, Dir->List returns only normal files, not sym links, dirs, invisable or dot files
    # Includ Dir Obj as first item in list
    #
    my @Nodes = ($Dir);

    #
    # Create list of nodes
    #
    my ($filepaths_r, $names_r, $stats_AoA_r, $flags_r) = FileUtility::dir_list(dir => $dir, inc_file => 1, use_ref => 1);
    foreach (0..$#{$filepaths_r} ){
	my $filepath = ${$filepaths_r}[$_];
	my $Node = MooFile->new(filepath => $filepath, 
				stats => @{$stats_AoA_r}[$_], update_stats => 0, 
				# flags => @{$flags_r}[$_],     update_flags => 0,
				update_md5 => 0);
	push (@Nodes, $Node);
    }

    # 
    # Now check each node
    #
    foreach my $Node (@Nodes) {
	update_file(file => $Node, Files_old_ref => $Tree_old, fast_scan=>$fast_scan);
	$Tree_new->insert($Node);

	# Save every so often
	if ($files_md5 > 0 && $files_md5 % $md5_save_limit == 0){
	    $Tree_new -> save(dir => $dir, name => $db_name);
	    say "\tCheckpoint Save File Changes: New: $files_new Changed: $files_change MD5: $files_md5 Deleted: $files_delete";
	}
    }

    # Done scanning new files, check if any old values left - file must have been deleted, or moved to new dir
    # Renamed file we would have caught becuase of same inode
    my @Files = $Tree_old->List;
    $files_delete += scalar(@Files);
    if (@Files >= 1 && $verbose >= 1){
	say "\tDeleted files:";
	foreach my $File (@Files){
	    say "\t\t", $File->filename;
	}
    }

    my $total_change = $files_new + $files_delete + $files_change + $files_md5 + $files_rename;
    if ( $total_change > 0){
	$Tree_new -> save(name => $db_name);
	say "\tFile Changes: New: $files_new Changed: $files_change MD5: $files_md5 Deleted: $files_delete Rename: $files_rename";
    }

    # DEBUG
    # $Tree_new->save_packed;

    return ($Tree_new->List);
}

#
# Process one file
# * Pass in a File Object, ref to old files
# * Retuns updated File Object
# 
sub update_file {
    my %opt = @_;

    my $File        = delete $opt{file} or die "Missing param 'File' to update_file";
    my $Tree_old    = delete $opt{Files_old_ref} or die "Missing param 'Files_old_ref' to update_file";
    my $fast_scan   = delete $opt{fast_scan} // 0;
    die "Unknown params:", join ", ", keys %opt if %opt;

    say "\tChecking: ", $File->filename if ($verbose >= 3);

    # 
    # This checks for changes and determines what needs to be updated.
    # 
    my ($File_old) = $Tree_old->Search(hash => $File);

    if (! defined $File_old) {
	# If no old file with inode, must be new file (could be new file with same name, and diff inode)
	say "\t\tNew File: ", $File->filename if ($verbose >= 2);
	# $File->update_flags;
	$files_new++;
    } else {
	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($File->stats, $File_old->stats) & ~$FileUtility::stats_names{atime};

	if ($changes){
	    my @changes = FileUtility::stats_delta_array($changes);
	    $files_change++;

	    if ($verbose >= 2){
		say "\t\tDelta: ", join(", ", @changes);
		printf "\t\t\tThe binary representation is: %013b\n", $changes;
	    }

	    # Decide what needs to be changed based upon what stats changed
	    # if dev, ino or blksize changes - is error - should not happen
	    if ($changes & ( $FileUtility::stats_names{dev} | $FileUtility::stats_names{ino} |
				 $FileUtility::stats_names{blksize} )) {
		die("Stats Delta Illegal stats change: ", join(", ", @changes));
	    }

	    # If ctime - maybe flags, maybe filename changed - seperate check filename change
	    if ($changes & ( $FileUtility::stats_names{ctime})) {
		$File->update_flags;
		if ($File->flags){
		    my $str = FileUtility::osx_flags_binary_string($File->flags);
		    say "After Update Flags: $str";
		}
	    }

	    # If NOT mtime, size or blocks - then we can reuse old md5 if it exists
	    if (! $changes & ( $FileUtility::stats_names{mtime} | $FileUtility::stats_names{size} |
				   $FileUtility::stats_names{blocks} )){
		say "\t\tExisitng Unchanged: ", $File->filename if ($verbose >= 3);
		
		if ($File->can('md5') && $File_old->can('md5') && defined $File_old->md5){
		    $File->_set_md5($File_old->md5);
		}	
	    }
	
	} else { # End If File Changed
	    # If file unchanged - copy md5 value if it exists
	    say "\t\tExisitng Unchanged: ", $File->filename if ($verbose >= 3);
	    if ($File->can('md5') && $File_old->can('md5') && defined $File_old->md5){
		$File->_set_md5($File_old->md5);
	    }

	}

	# Need independent check for if file was renamed - rename does not change any of file stats, just
	# dir stats.
	# Could optimize by remembering if dir changed and only check if dir changed
	if ($File->filepath ne $File_old->filepath){
	    $files_rename++;
	    say "\t\tRenamed: ",$File_old->filename, 
		"\n\t\t     To: ", $File->filename if ($verbose >= 2);
	}

	$Tree_old->Delete($File);
    }
    $size_count{$File->size}++;

    # if obj supports md5 and it's not set and object is readable then calc md5 (only files today)
    if ($File->can('md5') && !defined($File->md5) && $File->isreadable){
	my $count = $size_count{$File->size};

	# Skip if fast scan, unless it's a dupe size, then calc MD5
	if ( !$fast_scan or $count >= 2) {	    
	    say "\t\tCalc md5: ", $File->filename if ($verbose >= 2 or $count >= 2);
	    say "\t\t\tPossible Dupe # $count" if ($count >=2);

	    $File->update_md5;
	    $files_md5++;
	}
    }
    return ($File);
}

