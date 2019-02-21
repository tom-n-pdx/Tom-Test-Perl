#!/usr/bin/env perl
#

# ? If dirs not changed - do we have to check if files changed?
# ? Do we need to check dirs first?
# ? Do we update dir datafile?
# New smart scan method.
# Load an exisiting tree.
# 1. Go thru dir nodes
#    + If unchanged, move to new
#    + If deleted?
#    + If changed, scan dir???
#      Scan for dirs & files?
# 2. Go thru file nodes
#    + If deleted - move to trash
#    + If unchanged - move to new
#    + Update?

# !! Add - new dir
# Optimize  - if dir not chaanged  - can we move all files in subdir without checking if changed?
# + Need search match path


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
my $file_changes = 0;
my $dir_changes = 0;

my $Tree_old    = NodeTree->load(dir => $dir, name => $db_tree_name);
my $Tree_new    = NodeTree->new;
my $Tree_trash  = NodeTree->new;

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
    $file_changes = 0;
    $i++;
    say "Start Loop $i";

    foreach my $Node (  $Tree_old->Search(dir => 1), $Tree_old->Search(file => 1) ){
	my @stats_new = lstat($Node->filepath);
	next if (!  @stats_new);

	# Check changes and mask off atime changes
	my $changes = FileUtility::stats_delta_binary($Node->stats,  \@stats_new);
	$changes = $changes & ~$FileUtility::stats_names{atime};
    
	if ($changes & $FileUtility::stats_names{ino}){
	    say "Skipping Node - inode changed Old Name", $Node->filename;
	    next;
	}
    
	# remove from old list, update values, insert into new list
	$Tree_old->Delete($Node);

	if ($changes){
	    $file_changes++;

	    my @changes = FileUtility::stats_delta_array($changes);
	    say "Detect Changes in ", $Node->isdir ? "Dir " : "File ", $Node->filename, " Changes: ", join(", ", @changes);
	    &update_file($Node, $changes, @stats_new);
	    &update_dir($Node, $changes, @stats_new) if $Node->isdir;
	}

	$Tree_new->insert($Node);
    }

    say " ";
    say "After Pass Changes: $file_changes Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
    say " ";

} while ($Tree_old->List > 0 && $i < 10);


$verbose = 2;
exit;

#
# Check Dirs
# - problem - did we use files, dot files, etc when ran before?
# - may insert more dirs so have to double loop

foreach my $Node( $Tree_old->Search(dir => 1) ){
    my @stats_new = lstat($Node->filepath);
    next if (!  @stats_new);

    # Check changes and mask off atime changes
    my $changes = FileUtility::stats_delta_binary($Node->stats, \@stats_new);
    $changes = $changes & ~$FileUtility::stats_names{atime};

    if ($changes & $FileUtility::stats_names{ino}){
	say "Skipping Dir - inode changed Old Name", $Node->filename;
	next;
    }

    # Since things may change - delete from old list, make changes, add to new
    $Tree_old->Delete($Node);

    if ($changes){
	$dir_changes++;
	&update_file($Node, $changes, @stats_new);
	
	&update_dir($Node, $changes, @stats_new);
    }

    $Tree_new->insert($Node);
    

}


say " ";
say "After Second Dir Pass  Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";


#
# Check Files
#
foreach my $Node ($Tree_old->Search(file => 1)){
    my @stats_new = lstat($Node->filepath);
    next if (!  @stats_new);

    # Check changes and mask off atime changes
    my $changes = FileUtility::stats_delta_binary($Node->stat, \@stats_new);
    $changes = $changes & ~$FileUtility::stats_names{atime};

    if ($changes & $FileUtility::stats_names{ino}){
	say "Skipping File - inode changed Old Name", $Node->filename;
	next;
    }

    # Remove from Old List
    # Since some changes modify size, md5 or inode - and they are indexed by that, we need
    # to remove from old List. modify, then insert into new list
    $Tree_old->Delete($Node);

    # Make requied updates
    if ($changes){
	$file_changes++;
	&update_file($Node, $changes, @stats_new);
    }

    # Insert in new list
    if ($Tree_new->Search(hash => $Node)) {
	warn "    Tried to insert dupe Node ".$Node->filename;
	my ($Dupe) = $Tree_new->Search(hash => $Node);
	warn "        Old: ".$Dupe->filename;
    } else {
	$Tree_new->insert($Node);
    }
	    
}


#
# OK - any files left in Old List must have been deleted
#
my @Nodes = $Tree_old->Search(file => 1);
if(@Nodes > 0){
    say " ";
    say "Files Deleted: ", join(", ", map($_->filename, @Nodes));
    foreach my $Node (@Nodes){
	if (!-e $Node->filepath){
	    $Tree_old->Delete($Node);
	}
    }
}


say " ";
say "After Second File Pass  Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";

#if (! $Tree_old->count){
say "Saved File";
$Tree_new -> save(dir => $dir, name => $db_tree_name);
#}

exit;

sub update_file {
    my $Node = shift(@_);
    my $changes = shift(@_);
    my @stats_new = @_;

    my @changes = FileUtility::stats_delta_array($changes);
    say "    File: ", $Node->filename if ($verbose == 2);
    say "        Delta: ", join(", ", @changes) if ($verbose >= 2);
    printf "\t\t\tThe binary representation is: %013b\n", $changes if ($verbose >= 2);

    $Node->stats(\@stats_new);                    # always update stats some changed

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
	    $Node->_set_md5(undef);
	}	
    }

    # If can do MD5 value, and the obj does not have one and is readable - calculate it
    if ($Node->can('md5') && ! defined $Node->md5 && $Node->isreadable) {
	if (! $fast_scan){
	    say "    Update MD5: ", $Node->filename if ($verbose == 2);
	    $Node->update_md5;
	}
    }
}

# Need to deal with new dirs
# Exists on disk & changed, so list files in dir and see what to do
# ToDo
# * optimize  - use list files so can use stats? skip useless object creation?
# * not use global values for Tree's
#
sub update_dir {
    my $Node = shift(@_);
    my $changes = shift(@_);
    my @stats_new = @_;

    my @Nodes = $Node->List(inc_file => 1, inc_dir => 1);

    foreach my $Node (@Nodes) {
	# If is in new list, know unchanged, can skip
	if ($Tree_new->Search(hash => $Node)) {
	    next;
	}

	# In old list, check if need to update path
	# And leave in Old list to process on next iteration
	if (my ($old_node) = $Tree_old->Search(hash => $Node)) {
	    if ($old_node->filepath ne $Node->filepath) {
		say "Update filepath: ", $old_node->filename;
		$old_node->filepath($Node->filepath);
	    }
	    next;
	}
	    
	# New file, can directlly put in new list
	# Do we need to check for dupe filepath in old list and cleanup?
	say "New File in Dir: ", $Node->filename;
	$Tree_new->insert($Node);
	
	# If new node, place in old list?

    }

}



sub where_found {
    my $Obj = shift(@_);

    my @where;
    
    push(@where, "new")   if ( scalar($Tree_new->Search(hash => $Obj)) > 0);
    push(@where, "old")   if ( scalar($Tree_old->Search(hash => $Obj)) > 0);
    push(@where, "trash") if ( scalar($Tree_trash->Search(hash => $Obj)) > 0);

    if (@where > 1){
	warn("Found in more then one Tree ".join(", ", @where));
    }	

    return($where[0] // "");
}

