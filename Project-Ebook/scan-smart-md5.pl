#!/usr/bin/env perl
#

# !! Add - new dir
# Optimize  - if dir not chaanged  - can we move all files in subdir without checking if changed?
# + Need search match path
# + trigger rescan dir and update dir?
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
use FileUtility qw(%stats_names);

# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * return number of changes for dir update - total changes
#
# Perf
# time ./scan-smart-md5.pl ~/Downloads
# 0.513u 0.048s 0:00.57 96.4%	0+0k 0+3io 0pf+0w
# 
my %size_count;

my ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);

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

if (!-e "$dir/$db_tree_name"){
    die "No exiisting tree daatfile: $dir";
}

my $Tree_old    = NodeTree->load(dir => $dir, name => $db_tree_name);
my $Tree_new    = NodeTree->new;
# my $Tree_trash  = NodeTree->new;

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

    # foreach my $Node (  $Tree_old->Search(dir => 1), $Tree_old->Search(file => 1) ) {
    foreach my $Node ( $Tree_old->List ) {
	my @stats_new = lstat($Node->filepath);
	next if (!  @stats_new);

	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($Node->stats,  \@stats_new);
	$changes = $changes & ~$stats_names{atime};
    
	if ($changes & $stats_names{ino}) {
	    say "  Skipping Node - inode changed Old Name", $Node->filename;
	    next;
	}
    
	# remove from old list, update values, insert into new list
	$Tree_old->Delete($Node);

	# need to always call update file since may need to do md6 calc een if no changes
	&update_file($Node, $changes, @stats_new);
	if ($changes && $Node->isdir) {
	    &update_dir($Node, $changes, @stats_new);
	}

	$Tree_new->insert($Node);
    }
    
    say " ";
    say "After Pass # $i - Changes: $files_change Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
    say " ";
} while ($Tree_old->List > 0 && $files_change > 0 && $i < 10);


#
# Check Deleted
# Still in old list, but we are done making changes, must be deleted
#
my @Nodes = $Tree_old->List;
if(@Nodes > 0){
    $files_change++;
    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
}

if ($files_change > 0){
    $Tree_new -> save(dir => $dir, name => $db_tree_name);
    say "Saved File";
}

exit;


sub update_file {
    my $Node = shift(@_);
    my $changes = shift(@_);
    my @stats_new = @_;

    my @changes = FileUtility::stats_delta_array($changes);
    say "    File: ", $Node->filename if ($verbose == 2);
    say "        Delta: ", join(", ", @changes) if ($verbose >= 2);
    printf "\t\t\tThe binary representation is: %013b\n", $changes if ($verbose >= 2);

    if ($changes){
	$files_change++;

	# Always update stats if any changed
	$Node->stats(\@stats_new); 

	# Decide what needs to be changed based upon what stats changed
	# if dev or blksize changes - is an error - should not happen
	if ($changes & ( $stats_names{dev} | $stats_names{blksize} )) {
	    die("Stats Delta Illegal stats change: ", join(", ", @changes));
	}
	
	# If ctime - maybe flags changed
	if ($changes & ( $stats_names{ctime})) {
	    $Node->update_flags
	}

	# If mtime, size or blocks changed - then clear old md5
	if ( $changes & ( $stats_names{mtime} | $stats_names{size}) ) {
	    if ($Node->can('md5') && defined $Node->md5) {
		$Node->_set_md5(undef);
	    }	
	}
    } # End Changes

    # Even if no changs, need to maybe update md5
    $size_count{$Node->size}++;
    my $count = $size_count{$Node->size};

    if ( ($Node->can('md5') && ! defined $Node->md5 && $Node->isreadable)  
	     &&  (! $fast_scan or  $count >= 2)) {
	say "    Update MD5: ", $Node->filename if ($verbose == 2);
	$Node->update_md5;
	$files_md5++;
	$files_change++
    }
}

# Need to deal with new dirs
# Exists on disk & changed, so list files in dir and see what to do
# ToDo
# * not use global values for Tree's
#
sub update_dir {
    my $Dir = shift(@_);
    my $changes = shift(@_);
    my @stats_new = @_;

    # Optimize - grab stats and files
    my @Nodes = $Dir->List(inc_file => 1, inc_dir => 1);

    say "  Update Dir: ", $Dir->filepath;
    foreach my $Node (@Nodes) {
	# If is in new list, know is unchanged, we can skip checking
	if ($Tree_new->Exist(hash => $Node->hash)) {
	    next;
	}

	# If in old list, check if we need to update path and leave in Old list to process on next iteration
	my $old_node = $Tree_old->Exist(hash => $Node->hash);
	if (defined $old_node) {
	    if ($old_node->filepath ne $Node->filepath) {
		say "  Update filepath: ", $old_node->filepath;
		$old_node->filepath($Node->filepath);
		$files_change++;
	    }
	    next;
	}
	    
	# New for or dir, can directlly put in new list
	say "  New Node in Dir: ", $Node->filename;
	$Tree_new->insert($Node);
	$files_change++;
	$files_new++;

	update_dir($Node, 0x00, @{$Node->stats}) if $Node->isdir;

    }

}
