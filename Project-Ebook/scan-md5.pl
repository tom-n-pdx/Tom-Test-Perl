#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
# use open qw(:std :utf8);
use NodeTree;
use NodeHeap;
use FileUtility qw(osx_check_flags_binary %osx_flags 
		   dir_list 
		   stats_delta_binary %stats_names);

use lib 'MooNode';
use MooDir;
use MooFile;
use Carp;

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * combine / leverage smart scan core code
# * rewrite, leverage new md5 lib and how smart one is coded.
# * Can this be a variant of smart scan?
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
# + iter dir       5.032u 3.658s 0:12.22 71.0%	0+0k 0+10io 7pf+0w
# use heap         3.925u 2.608s 0:09.51 68.5%	0+0k 0+1io 0pf+0w
#                  3.864u 3.204s 0:09.34 75.5%	0+0k 0+0io 0pf+0w  optimized incremental load
#
#
# scan-md5-old     9.729u 7.648s 0:24.81 69.9%	0+0k 0+4io 0pf+0w
# scan-smart-md5   4.722u 3.266s 0:11.74 67.9%	0+0k 0+0io 0pf+0w
#                  0.483u 0.050s 0:00.54 98.1%	0+0k 0+1io 29pf+0w

our $total_changes = 0;



our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree = 0;
our $force_update = 0;

our $md5_save_limit = 100;

GetOptions (
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
    'quick'       => \$fast_dir,
    'tree'        => \$tree,
    'update'      => \$force_update,
);
our $update_md5 = ! $fast_scan;

if ($verbose >= 2){
    say "Options";

    say "\tVerbose: ",  $verbose;
    say "\tFast: ",     $fast_scan;
    say "\tQuick Dir: ",$fast_dir;
    say "\tTree: ",     $tree;
    say "\tUpdate: ",   $force_update;

    say " ";
}

# If existing file of dupe sizes, load
my %size_count;
&load_dupes(dupes => \%size_count);

my $Files_old = NodeHeap->new;
my $Files_new = NodeHeap->new;

#
# Scan each arg as dir, using dir or tree scan.
#
foreach my $dir (@ARGV){
    if ($tree){
	say "Scanning Tree: $dir" if ($verbose >= 0); 
	find(\&wanted,  $dir);
    } else {
 	say "Scanning Dir: $dir" if ($verbose >= 0 ); 
	scan_dir_md5(dir=>$dir, update_md5=> $update_md5, fast_dir => $fast_dir, 
		   Tree_old => $Files_old, Tree_new => $Files_new);
    }
}

say "Total Changes: $total_changes";
&save_dupes(dupes => \%size_count) if ($total_changes > 0);

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
    scan_dir_md5(dir => $dir, update_md5 => $update_md5, fast_dir => $fast_dir, 
		 Tree_old => $Files_old, Tree_new => $Files_new);

    return;
}


#
#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
#
sub scan_dir_md5 {
    my %opt = @_;
    my $dir         = delete $opt{dir} or die "Missing param to scan_dir_md5";

    my $Tree_new    = delete $opt{Tree_new}   // croak "Missing param 'Tree_new'";
    my $Tree_old    = delete $opt{Tree_old}   // croak "Missing param 'Tree_old'";

    my $update_md5  = delete $opt{update_md5} // 0;
    my $fast_dir    = delete $opt{fast_dir}   // 0;
    die "Unknown params:", join ", ", keys %opt if %opt;

    &files_change_clear;
    say "  Checking $dir" if ($verbose >= 2);

    my $Dir_old;
    my $Files_old = NodeHeap->new(name => $dir);

    my $Dir_new   = MooDir->new(filepath => $dir, update_dtime => 1);
    my $Files_new = NodeHeap->new(name => $dir);


    # Check if existing db file or not
    if ( my $db_mtime = dbfile_exist_md5(dir => $dir) ){
	say "\tdb_file exists " if ($verbose >= 3);

	if ($fast_dir && $db_mtime >= $Dir_new->dtime){
	    say "\tQuick Dir scan enabled, No Files chaged, Skip scan" if ($verbose >= 2);
	    return;
	}

	$Files_old = dbfile_load_md5(dir => $dir);

    } else {
	# No Db file - Insert Dir object into old list. force change to dir stats to make sure is processed
	my @stats = @{$Dir_new->stats};
	$stats[9] = 0;
	$Dir_new->stats( [@stats] );

	$Files_old->insert($Dir_new);
    }	    

    # 
    # Now, old list loaded - loop through files in dir
    #
    foreach my $Node ($Files_old->List ){
	say "    ", $Node->type, " ", $Node->filename if ($verbose >= 3);

	# If doesn't exist on disk - leave in old list for now
	my @stats = lstat($Node->filepath); # If no stats, file does not exist
	next if (! @stats);

	# Check changes and mask off atime changes
	my $changes = stats_delta_binary($Node->stats,  \@stats) & ~$stats_names{atime} & ~$stats_names{dev};

	# If the inode has changed, this is not the same file
	next if ($changes & $stats_names{ino});

	# Remove from Old List
	# Since some changes modify size, md5 - and they are indexed by that, we need
	# to remove from old List, update, then insert into new list

	$Files_old->Delete($Node);
	update_file_md5(Node => $Node, changes => $changes, stats => \@stats, update_md5 => $update_md5);
	$Files_new->insert($Node);

	# If changes & dir - need to do more work
	if ($changes && $Node->isdir) {
	    &update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats, update_md5 => $update_md5,
 				Tree_old => $Files_old, Tree_new => $Files_new, 
				inc_dir => 0);
	}	
    }
    

    # Done scanning old files, check if any objs left - file must have been deleted, or moved to new dir
    # A renamed file we would have caught becuase the inode stayed the same and we did a update dir
    my @Files_deleted = $Files_old->List;
    $files_change{delete} += scalar(@Files_deleted);

    if (@Files_deleted >= 1 && $verbose >= 1){
    	say "    Deleted files:";
    	foreach my $File (@Files_deleted){
    	    say "      ", $File->filename;
    	}
    }

    my $changes = &files_change_total;
    $total_changes = $total_changes + $changes;

    if ($force_update or $changes > 0){ 
	say "    Saved Datafile" if ($verbose >= 2);
	dbfile_save_md5(List => $Files_new, dir => $dir);
    }
    say "  Checking $dir" if ($verbose == 1 && $changes > 0);
    say("    Changes: $changes (", &files_change_string, ")") 
	if ($verbose >= 2 or ($changes > 0 && $verbose >= 1));

    return;
}


