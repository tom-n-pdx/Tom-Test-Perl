#!/usr/bin/env perl
#

# ToDo
# * Checkpoint save - make by time
#
# Fatal errors: /Volumes/MyBook/Video_4/_Inbox
# * make smart enough to load subtree or dir if found?
# * routeen run if no datafile in dir?
#    
#   top down, dumb search, find like, get prune to work
use Modern::Perl; 		         # Implies strict, warnings
# use autodie;
# use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
# use NodeTree;
use NodeHeap;

use lib 'MooNode';
use MooNode;
use MooDir;
use MooFile;
use FileUtility qw(%stats_names dir_list);
use utf8;
use open qw(:std :utf8);

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
#
# Perf
# time ./scan-smart-md5.pl -f ~/Downloads
#           0.513u 0.048s 0:00.57 96.4%	0+0k 0+3io 0pf+0w
#           0.470u 0.045s 0:00.52 98.0%	0+0k 0+0io 0pf+0w
#           1.607u 0.150s 0:01.77 98.8%	0+0k 0+0io 0pf+0w
# packed   14.642u 8.478s 0:33.85 68.2%	0+0k 0+0io 0pf+0w !!!
# use heap  0.515u 0.044s 0:00.56 98.2%	0+0k 0+0io 0pf+0w


# empty tree - -f ~/Downloads
#                 7.245u 5.715s 0:17.67 73.2%	0+0k 0+3io 0pf+0w
# w/ iter dir     3.703u 2.473s 0:08.94 69.0%	0+0k 0+4io 34pf+0w


my %size_count;
my $files_change_total = 0;
my $files_change = 0;
my $files_md5_total = 0;


our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
# our $fast_dir  = 0;
# our $tree=0;
our $md5_save_limit = 100;

GetOptions (
    'debug=i'     => \$debug,
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
#    'quick'       => \$fast_dir,
#    'tree'        => \$tree,
);

if ($debug or $verbose >= 2){
    say "Options";

    say "\tDebug: ", $debug;
    say "\tVerbose: ", $verbose;
    say "\tFast: ", $fast_scan;
#    say "\tQuick Dir: ", $fast_dir;
#    say "\tTree: ", $tree;

    say " ";
}


# For each tree, load old data & walk nodes
my $db_name =  ".moo.db";
my $db_tree_name =  ".moo.tree.yaml";
# my $db_tree_name_packed =  ".moo.tree.dbp";

my $dir = shift(@ARGV);

say "Updating Tree: $dir";
say " ";

my $Tree_old;
if (!-e "$dir/$db_tree_name"){
    # die "No exiisting tree datafile: $dir";
    warn "No exiisting tree datafile: $dir";

    # Create new Dir node with forced changes
    my @stats = lstat($dir);
    $stats[9] = 0;		# Modify mtime
    my $Dir = MooDir->new(filepath => $dir, 
			stats => [ @stats ], update_stats => 0, 
			update_dtime => 0);

    # Insert into old tree
    $Tree_old = NodeHeap->new;
    $Tree_old->insert($Dir);

} else {
    $Tree_old    = NodeHeap->load(dir => $dir, name => $db_tree_name);
    # $Tree_old    = NodeTree->load_packed(dir => $dir, name => $db_tree_name_packed);
}

my $Tree_new    = NodeHeap->new;


$Tree_old->summerize;

say " ";
say "Start Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";

#
# Keep processing list until nothing changes or the old queue is empty
#

my $i = 0;

# While - if nothing in old queue then done 
do {
    $files_md5_total += $files_change{md5};
    $files_change = 0;
    &files_change_clear;

    $i++;
    # say "Start Loop $i";
    &files_change_clear;

    foreach my $Node ( $Tree_old->List ) {
	my $count = $files_change{md5} + $files_md5_total;
	if ($count >= 1 && $count % $md5_save_limit == 0){
	    &save_checkpoint;
	}

	my @stats_new = lstat($Node->filepath);
	if (! @stats_new){
	    say "    Missing File: ", $Node->filename if ($verbose >= 3);
	    next;
	}

	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($Node->stats,  \@stats_new) & ~$stats_names{atime};
    
	# This is likely a file that has been renamed and a new file has the old name
	if ($changes & $stats_names{ino}) {
	    say "    Skipping Node - inode changed. Old Name", $Node->filename if ($verbose >= 2);
	    next;
	}
    
	# remove from old list, update values, insert into new list
	$Tree_old->Delete($Node);

	# need to always call update file since may need to do md5 calc even if no changes
	# Update file also updates dir stats
	&update_file_md5(Node => $Node,   changes => $changes, stats => \@stats_new, update_md5 => ! $fast_scan);

	if ($changes && $Node->isdir) {
	    &update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats_new, 
			    Tree_old => $Tree_old, Tree_new => $Tree_new,
			    update_md5 => ! $fast_scan, inc_dir => 1);
	}

	$Tree_new->insert($Node);
    }
    
    say "After Pass # $i - Changes: $files_change Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);

    $files_change = &files_change_total;
    $files_change_total += $files_change;

    # $total_changes = $total_changes + $changes;
    # say("    Changes: $changes - New: $files_new Deleted: $files_delete", 
    # 	" Change: $files_change MD5: $files_md5 Rename: $files_rename") 
    # 	if ($verbose >= 2 or ($files_change > 0 && $verbose >= 1));
    say("    Changes: $files_change (", &files_change_string, ")") 
	if ($verbose >= 2 or ($files_change > 0 && $verbose >= 1));



    say " ";

    # If old dir is empty, we have processed everything.
    # If we didn't make any changes this loop - there is nothing left to do
    # And keep a limit count in case we blow up.


} while ($Tree_old->List > 0 && $files_change > 0 && $i < 10);


#
# Check Deleted
# Still in old list, but we are done making changes, must have been deleted
#
my @Nodes = $Tree_old->List;
if(@Nodes > 0){
    $files_change++;
    $files_change_total++;
    $files_change{delete}++;

    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
}
say("    Changes Total: $files_change_total") if ($verbose >= 2 or ($files_change_total > 0 && $verbose >= 1));

if ($files_change_total > 0){
    $Tree_new->save(dir => $dir, name => $db_tree_name);
    # $Tree_new->save_packed (dir => $dir, name => $db_tree_name_packed) ;    # For debug
    say "Saved File";
}

exit;

#
# Todo checkpoint save need to combine old and new lists and save
#
sub save_checkpoint {
    my $Tree_save = NodeHeap->new();
    
    $Tree_save->insert($Tree_old->List);
    $Tree_save->insert($Tree_new->List);

    $Tree_save->save(dir => $dir, name => $db_tree_name);

    say("Check Point Save: (", &files_change_string, ")") if ($verbose >= 1);
}
