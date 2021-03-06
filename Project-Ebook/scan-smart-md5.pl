#!/usr/bin/env perl -CA
#

# ToDo
# Bugs
# * Fix problem with dev changing for drive when offline
# * Add switch no md5
# * Fix if a dir become invisable - delete all files under dir
# * Checkpoint save - make work as alarm
# * alarm - user feedback
# * need option no md5 at all
# * Consider list iterator so don't create huge list of old nodes to process
#   Optimized load somewhat better
# * Make load file work as iterator
#   Thread read / write in obj?
# * Call a tree find - summerize - collcet - files
# !! Fatal errors: /Volumes/MyBook/Video_4/_Inbox
# * Bug - if make dir Hidden, does not kill subdirs
# * Make able update part of tree - all md5 for Dir e.g.


use Modern::Perl; 		         # Implies strict, warnings
# use autodie;
# use File::Find;
use open ':encoding(UTF-8)';
binmode STDOUT, ":utf8";
use Encode qw(decode_utf8);

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
# time ./scan-smart-md5.pl -m 1 -v 2 ~/Downloads
#           0.513u 0.048s 0:00.57 96.4%	0+0k 0+3io 0pf+0w
#           0.470u 0.045s 0:00.52 98.0%	0+0k 0+0io 0pf+0w
#           1.607u 0.150s 0:01.77 98.8%	0+0k 0+0io 0pf+0w
# packed   14.642u 8.478s 0:33.85 68.2%	0+0k 0+0io 0pf+0w !!!
# use heap  0.515u 0.044s 0:00.56 98.2%	0+0k 0+0io 0pf+0w
#           0.455u 0.040s 0:00.50 98.0%	0+0k 0+0io 0pf+0w
#           0.477u 0.044s 0:00.52 98.0%	0+0k 0+0io 0pf+0w -    - in new dir, put new in old list
#           0.548u 0.060s 0:00.61 98.3%	0+0k 0+3io 0pf+0w      load dir into new, do check on file
#           0.634u 0.058s 0:00.70 97.1%	0+0k 0+4io 0pf+0w      not optimized load
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
my $checkpoint_limit = 60 * 5; # 5 mins (60 seconds X 10 mins)
# $checkpoint_limit = 60 * 2; # 


our $verbose = 1;
our $calc_md5 = 1;
our $fast_dir = 0;

GetOptions (
    'verbose=i'   => \$verbose,
    'md5=i'       => \$calc_md5,
    'quick'       => \$fast_dir,
);

if ($verbose >= 2){
    say "Options";

    say "\tVerbose: ", $verbose;
    say "\tCalc MD5: ", $calc_md5;
    say "\tQuick: ", $fast_dir;

    say " ";
}


# For each tree, load old data & walk nodes
# my $db_name      =  ".moo.db";
# my $db_tree_name =  ".moo.tree.db";

# my $queue_load = Thread::Queue->new();

my $collect_dbfile = 0;

# Load Dupes
# our %size_count;
# &load_dupes(dupes => \%size_count);
load_dupes;

my $dir = shift(@ARGV);

say "Updating Tree: $dir";
say " ";

my $Files_old    = NodeHeap->new;
my $Files_new    = NodeHeap->new;

# if (!-e "$dir/$db_tree_name"){
my $db_mtime = dbfile_exist_md5(dir => $dir, type => 'tree');
if (! $db_mtime){
    warn "No exiisting tree datafile: $dir";

    # Add Dir & force need update
    my @stats = lstat($dir);
    my $Dir = MooDir->new(filepath => $dir,  need_update  => 1,
			stats => [ @stats ], update_stats => 0, 
			update_dtime => 0);

    # Flag to look for older dbfile in dirs
    $collect_dbfile = 1;


    # Insert into old tree
    $Files_old = NodeHeap->new;
    $Files_old->insert($Dir);

} else {
    if ($fast_dir) {
	db_file_load_optimized_md5(dir => $dir,   type => "tree", 
				   Files_new => $Files_new, Files_old => $Files_old);
    } else { 
	$Files_old = dbfile_load_md5(dir => $dir, type => "tree");
    }
}


say " ";
say "Start Old: ", $Files_old->count, " New: ", $Files_new->count;
say " ";

#
# Keep processing list until nothing changes or the old queue is empty
# ToDo
# * skip loop if all new already
#

# While - if nothing in old queue then done 
my $i = 0;

do {
    &files_change_clear;
    $i++;

    # ToDo
    foreach my $Node ( $Files_old->List ) {

	# Checkpoint save
	if (time > $checkpoint_last + $checkpoint_limit){
	    &save_checkpoint;
	    $checkpoint_last = time;
	}

	# File does not exisit, deleted or renamed
	my @stats_new = lstat($Node->filepath);
	if (! @stats_new){
	    say "    Missing Node: ", $Node->filename if ($verbose >= 3);
	    next;
	}

	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($Node->stats,  \@stats_new) & ~$stats_names{atime} & ~$stats_names{dev};
	my $need_update = $changes || $Node->need_update;

	# This is likely a file that has been renamed and a new file has the old name
	if ($changes & $stats_names{ino}) {
	    say "    Skipping Node - inode changed. Old Name", $Node->filename if ($verbose >= 3);
	    next;
	}
    
	# Update file also updates dir basic info
	# remove from old list, update values, insert into new list. Call update evn if new changes since migh need to calc MD5
	$Files_old->Delete($Node);
	&update_file_md5(Node => $Node, changes => $changes, stats => \@stats_new, calc_md5 => $calc_md5);
	$Files_new->insert($Node);

	if ( $need_update && $Node->isdir) {
	    &update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats_new, calc_md5 => $calc_md5,
			    Files_old => $Files_old, Files_new => $Files_new, 
			    inc_dir => 1,  load_dbfile => $collect_dbfile);
	}

    }
    
    $files_change = &files_change_total;
    $files_change_total += $files_change;
    say "After Pass # $i - $files_change Old: ", $Files_old->count, " New: ", $Files_new->count;


    say("    Changes: $files_change (", &files_change_string, ")") 
	if ($verbose >= 2 or ($files_change > 0 && $verbose >= 1));

    say " ";

    # If old list is empty, we have processed everything.
    # If we didn't make any changes this loop - there is nothing left to do even if files left in old list
    # And keep a limit count in case we blow up. Limit is also how deep in tree we can go

} while ($files_change > 0 && $Files_old->count > 0 && $i < 20);

#
# Check what file / dirs were deleted
# If still in old list, but we are done making changes, must have been deleted
#
my @Nodes = $Files_old->List;

if(@Nodes > 0){
    $files_change_total   += scalar(@Nodes);
    $files_change{delete} += scalar(@Nodes);

    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
}


say("    Changes Total: $files_change_total") if ($verbose >= 2 or ($files_change_total > 0 && $verbose >= 1));


say "\nUpdate Unicode: ", $ScanDirMD5::update_unicode;

if ($files_change_total > 0){
    dbfile_save_md5(List => $Files_new, dir => $dir, type => "tree");
    say "Saved File";

}
# &save_dupes(dupes => \%size_count);
save_dupes;

exit;

#
# Todo checkpoint save need to combine old and new lists and save
#
sub save_checkpoint {
    my $Files_save = NodeHeap->new();
    
    $Files_save->insert($Files_old->List);
    $Files_save->insert($Files_new->List);

    # ToDo
    # * use save routeen 
    # $Files_save->save(dir => $dir,type => "tree");
    dbfile_save_md5(List => $Files_save, dir => $dir, type => "tree");

    say("Check Point Save: (", &files_change_string, ")") if ($verbose >= 1);
}

