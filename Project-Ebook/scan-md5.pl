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
# * only save dupes when found more - move to md6 lib
# * Add a every so often save
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
# +hash md5        4.840u 3.690s 0:12.06 70.7%	0+0k 0+9io 0pf+0w
#                  3.951u 2.802s 0:09.76 69.1%	0+0k 0+50io 0pf+0w
#
# scan-md5-old     9.729u 7.648s 0:24.81 69.9%	0+0k 0+4io 0pf+0w
# scan-smart-md5   4.722u 3.266s 0:11.74 67.9%	0+0k 0+0io 0pf+0w
#                  0.483u 0.050s 0:00.54 98.1%	0+0k 0+1io 29pf+0w

my %size_count;
 
our ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
our $total_changes = 0;

my $db_name =  ".moo.db";

our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree = 0;
our $force_update = 0;
our $save_packed = 0;
our $md5_save_limit = 100;

GetOptions (
    'debug=i'     => \$debug,
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
    'quick'       => \$fast_dir,
    'tree'        => \$tree,
    'update'      => \$force_update,
    'packed'      => \$save_packed,
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

say "Total Changes: $total_changes";

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
	    warn "db_file does not contain only one Dir record $dir";
	    if (-e "$dir/$db_name"){
		rename("$dir/$db_name", "$dir/$db_name.old");
	    }
	    return;

	}
	$Dir_old = $Dirs_old[0];


	# Delete from old list, update & insert in new list
	$Tree_old->Delete($Dir_old);

	# Check for changes and mask atime changes - a dir name change will not change dir stats
	my $changes = stats_delta_binary($Dir_new->stats, $Dir_old->stats) & ~$stats_names{atime};
	
	if ($changes or $Dir_old->filepath ne $dir){
	    update_file_md5(Node => $Dir_old, changes => $changes, stats => $Dir_new->stats, update_md5 => ! $fast_scan);

	    if ($Dir_old->filepath ne $Dir_new->filepath){
		$Dir_old->filepath($Dir_new->filepath);
		say "    Dir rename";
		$files_rename++;
	    }
	    update_dir_md5(Dir => $Dir_old, changes => $changes, stats => $Dir_new->stats, 
			   Tree_new => $Tree_new, Tree_old => $Tree_old, 
			   update_md5 => ! $fast_scan, inc_dir => 0);
	}
	$Tree_new->insert( $Dir_old );


	# Now scan through whats left in list
	foreach my $Node ($Tree_old->List ){
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


	    # Call even if no changes - may need md5 calculated
	    update_file_md5(Node => $Node, changes => $changes, stats => \@stats_new, 
			    update_md5 => ! $fast_scan);

	    $Tree_new->insert($Node);


	    if ($files_md5 >= 1 && ($files_md5 % $md5_save_limit == 0)){
		say "    Saved Checkpoint Datafile" if ($verbose >= 2);
		$Tree_new->save(name => $db_name);
	    }



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
	update_dir_md5(Dir => $Dir_new, stats => $Dir_new->stats, changes => 0,
			Tree_new => $Tree_new, Tree_old => $Tree_old, 
			update_md5 => ! $fast_scan)

    }


    # Done scanning old files, check if any objs left - file must have been deleted, or moved to new dir
    # A renamed file we would have caught becuase the inode stayed the same
    my @Files = $Tree_old->List;
    $files_delete += scalar(@Files);
    if (@Files >= 1 && $verbose >= 1){
    	say "    Deleted files:";
    	foreach my $File (@Files){
    	    say "      ", $File->filename;
    	}
    }

    my $changes = $files_new + $files_delete + $files_change + $files_md5 + $files_rename;
    $total_changes = $total_changes + $changes;

    if ($force_update or $changes > 0){ 
	say "    Saved Datafile" if ($verbose >= 2);
	$Tree_new->save(name => $db_name);
	if ($save_packed){
	    say "    Saved Packed Datafile" if ($verbose >= 1);
	    $Tree_new->save_packed; # For debug
	}
    }
    say "  Checking $dir" if ($verbose == 1 && $changes > 0);
    say("    Changes: $changes - New: $files_new Deleted: $files_delete", 
	" Change: $files_change MD5: $files_md5 Rename: $files_rename") 
	if ($verbose >= 2 or ($files_change > 0 && $verbose >= 1));

    return;
}


