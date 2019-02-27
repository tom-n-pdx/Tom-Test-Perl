#!/usr/bin/env perl
#

# ToDo
# * Checkpoint save - make work as alarm
# !! Fatal errors: /Volumes/MyBook/Video_4/_Inbox
# * Consider list iterator so don't create huge list of old nodes to process
# * Make load file work as iterator
#   Thread read / write in obj?
#   If no heap for tree - look for dbfile on each new dir scan?
#
use Modern::Perl; 		         # Implies strict, warnings
# use autodie;
# use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use NodeHeap;

use lib 'MooNode';
use MooNode;
use MooDir;
use MooFile;
use FileUtility qw(%stats_names dir_list);
use Carp;
# use utf8;
# use open qw(:std :utf8);

#
# Threaded Code
#
# use threads;
# use Thread::Queue;


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
#           0.455u 0.040s 0:00.50 98.0%	0+0k 0+0io 0pf+0w
#           0.477u 0.044s 0:00.52 98.0%	0+0k 0+0io 0pf+0w -    - in new dir, put new in old list
#           0.548u 0.060s 0:00.61 98.3%	0+0k 0+3io 0pf+0w      load dir into new, do check on file
#
#
# empty tree - -f ~/Downloads
#                 7.245u 5.715s 0:17.67 73.2%	0+0k 0+3io 0pf+0w
# w/ iter dir     3.703u 2.473s 0:08.94 69.0%	0+0k 0+4io 34pf+0w
#                 7.211u 5.675s 0:17.71 72.7%	0+0k 275+5io 0pf+0w
#                 7.005u 5.002s 0:17.37 69.0%	0+0k 0+5io 0pf+0w    - in new dir sub, put new dir in old list
#                 7.500u 5.476s 0:18.95 68.4%	0+0k 0+7io 0pf+0w

my $files_change_total = 0;
my $files_change = 0;

my $checkpoint_last = time;
my $checkpoint_limit = 60 * 10; # 10 mins (60 seconds X 10 mins)
# $checkpoint_limit = 60 * 2; # 


our $verbose = 1;
our $fast_scan = 0;

GetOptions (
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
);

my $update_md5 = ! $fast_scan;

if ($verbose >= 2){
    say "Options";

    say "\tVerbose: ", $verbose;
    say "\tFast: ", $fast_scan;

    say " ";
}


# For each tree, load old data & walk nodes
my $db_name      =  ".moo.db";
my $db_tree_name =  ".moo.tree.db";

# my $queue_load = Thread::Queue->new();

# Load Dupes
my %size_count;
&load_dupes(dupes => \%size_count);


my $dir = shift(@ARGV);

say "Updating Tree: $dir";
say " ";

my $Tree_old    = NodeHeap->new;
my $Tree_new    = NodeHeap->new;

if (!-e "$dir/$db_tree_name"){
    warn "No exiisting tree datafile: $dir";

    # Create new Dir node with forced change
    my @stats = lstat($dir);
    $stats[9] = 0;		# Modify mtime
    my $Dir = MooDir->new(filepath => $dir, 
			stats => [ @stats ], update_stats => 0, 
			update_dtime => 0);

    # Insert into old tree
    $Tree_old = NodeHeap->new;
    $Tree_old->insert($Dir);

} else {
    # $Tree_old    = NodeHeap->load(dir => $dir, name => $db_tree_name);
    # $Tree_old    = dbfile_load_md5(dir => $dir, name => $db_tree_name);

    db_file_load_optimized_md5(dir => $dir, name => $db_tree_name, 
     			       Tree_new => $Tree_new, Tree_old => $Tree_old);
}


say " ";
say "Start Old: ", $Tree_old->count, " New: ", $Tree_new->count;
say " ";

#
# Keep processing list until nothing changes or the old queue is empty
#


# While - if nothing in old queue then done 
my $i = 0;

do {
    &files_change_clear;
    $i++;

    # ToDo
    foreach my $Node ( $Tree_old->List ) {

	# Checkpoint save
	if (time > $checkpoint_last + $checkpoint_limit){
	    &save_checkpoint;
	    $checkpoint_last = time;
	}

	# File does not exisit, deleed or renamed
	my @stats_new = lstat($Node->filepath);
	if (! @stats_new){
	    say "    Missing Node: ", $Node->filename if ($verbose >= 3);
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
	# Need to check for dupes and touch file to force update
	if ($changes) {
	    &update_file_md5(Node => $Node,   changes => $changes, stats => \@stats_new, update_md5 => $update_md5);

	    if ($Node->isdir) {
		&update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats_new, update_md5 => $update_md5,
				Tree_old => $Tree_old, Tree_new => $Tree_new, 
				inc_dir => 1);
	    }
	}
	$Tree_new->insert($Node);
    }
    
    $files_change = &files_change_total;
    $files_change_total += $files_change;
    say "After Pass # $i - $files_change Old: ", $Tree_old->count, " New: ", $Tree_new->count;


    say("    Changes: $files_change (", &files_change_string, ")") 
	if ($verbose >= 2 or ($files_change > 0 && $verbose >= 1));

    say " ";

    # If old list is empty, we have processed everything.
    # If we didn't make any changes this loop - there is nothing left to do even if files left in old list
    # And keep a limit count in case we blow up. Limit is also how deep in tree we can go

} while ($files_change > 0 && $Tree_old->count > 0 && $i < 20);

#
# Check what was Deleted
# If still in old list, but we are done making changes, must have been deleted
#
my @Nodes = $Tree_old->List;

if(@Nodes > 0){
    $files_change_total   += scalar(@Nodes);
    $files_change{delete} += scalar(@Nodes);

    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
}
say("    Changes Total: $files_change_total") if ($verbose >= 2 or ($files_change_total > 0 && $verbose >= 1));

if ($files_change_total > 0){
    # $Tree_new->save(dir => $dir, name => $db_tree_name);
    dbfile_save_md5(List => $Tree_new, dir => $dir, name => $db_tree_name);
    say "Saved File";

    &save_dupes(dupes => \%size_count);
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

