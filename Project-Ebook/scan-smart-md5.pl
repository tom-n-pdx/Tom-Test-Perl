#!/usr/bin/env perl
#

# !! Add - new dir
# Optimize  - if dir not chaanged  - can we move all files in subdir without checking if changed?
# + Need search match path
# + trigger rescan dir and update dir?
#

use Modern::Perl; 		         # Implies strict, warnings
# use autodie;
# use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use NodeTree;

use lib 'MooNode';
use MooNode;
use MooDir;
use MooFile;
use FileUtility qw(%stats_names dir_list);

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
#
# Perf
# time ./scan-smart-md5.pl -f ~/Downloads
# 0.513u 0.048s 0:00.57 96.4%	0+0k 0+3io 0pf+0w
# 0.470u 0.045s 0:00.52 98.0%	0+0k 0+0io 0pf+0w
#

my %size_count;

our ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
my $files_change_total = 0;

my $db_name =  ".moo.db";

our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree=0;
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


# For each tree, load old data & walk nodes
my $db_tree_name =  ".moo.tree.db";

my $dir = shift(@ARGV);

say "Updating Tree: $dir";
say " ";


my $Tree_old;
if (!-e "$dir/$db_tree_name"){
    die "No exiisting tree datafile: $dir";
} else {
    $Tree_old    = NodeTree->load(dir => $dir, name => $db_tree_name);
}

my $Tree_new    = NodeTree->new;


$Tree_old->summerize;

say " ";
say "Start Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";

#
# Keep processing list until nothing changes or the old queue is empty
# More effecient if process any dir changes first
#

my $i = 0;

# While - if nothing in old queue then done 
do {
    $files_change = 0;
    $i++;
    say "Start Loop $i";

    foreach my $Node ( $Tree_old->List ) {
	my @stats_new = lstat($Node->filepath);
	next if (!  @stats_new);                                       # File Does not exist at old filename - deleted or renamed

	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($Node->stats,  \@stats_new) & ~$stats_names{atime};
    
	# This is likely a file that has been renamed and a new file has the old name
	if ($changes & $stats_names{ino}) {
	    say "  Skipping Node - inode changed. Old Name", $Node->filename;
	    next;
	}
    
	# remove from old list, update values, insert into new list
	$Tree_old->Delete($Node);

	# need to always call update file since may need to do md6 calc even if no changes
	# Update file also updates the basic dir stats
	&update_file_md5(Node => $Node,   changes => $changes, stats => \@stats_new, update_md5 => ! $fast_scan);
	if ($changes && $Node->isdir) {
	    &update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats_new, 
			    Tree_old => $Tree_old, Tree_new => $Tree_new,
			    update_md5 => ! $fast_scan);
	}

	$Tree_new->insert($Node);
    }
    
    say " ";
    say "After Pass # $i - Changes: $files_change Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
    say " ";

    # If old dir is empty, we have processed everything.
    # If we didn't make any changes this loop - there is nothing left to do
    # And keep a limit count in case we blow up.

    $files_change_total += $files_change;

} while ($Tree_old->List > 0 && $files_change > 0 && $i < 10);


#
# Check Deleted
# Still in old list, but we are done making changes, must be deleted
#
my @Nodes = $Tree_old->List;
if(@Nodes > 0){
    $files_change++;
    $files_change_total++;
    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
}

if ($files_change_total > 0){
    $Tree_new -> save(dir => $dir, name => $db_tree_name);
    say "Saved File";
}

exit;


