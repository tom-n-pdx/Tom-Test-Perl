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

my $Tree_old    = NodeTree->load(dir => $dir, name => $db_tree_name);
my $Tree_new    = NodeTree->new;
my $Tree_trash  = NodeTree->new;

$Tree_old->summerize;

say " ";
say "Start Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";


my @Dirs;

# First Scan amd see if ANYTHING chanegd. Process Dirs, then Files

# First Pass Process Dir & File
my @Nodes = ($Tree_old->Search(dir => 1), $Tree_old->Search(file => 1));
foreach my $Node (@Nodes){

    my @changes = $Node->ischanged;
    
    # If no changes, move to new Tree
    if (scalar(@changes) < 1){
	$Tree_old->Delete($Node);
	$Tree_new->insert($Node);
	next;
    }
    
    # If Node has changes, we will deal with in second pass - leave in Old Tree
    say "Pass 1 Detect Changes in ", $Node->isdir ? "Dir " : "File ", $Node->filename, " Changes: ", join(", ", @changes);
}

say " ";
say "After First Pass: Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";

if (! scalar($Tree_old->count)){
    say "No Changes! - Exit with no save";
    exit;
}

$verbose = 2;

# Second Scan and see what need to fixup
# werid - changing flags changes inode value

# foreach my $Node ($Tree_old->List){
# my @Nodes;


#
# Check Dirs
# - problem - did we use files, dot files, etc when ran before?
# - may insert more dirs so have to double loop


#while (@Dirs = $Tree_old->Search(dir => 1) ){
foreach my $Node (@Dirs){
    my @changes = $Node->ischanged;

	# If doesn't exisit on disk leave in old Tree - likely deleted but maybe renamed
    next if (grep(/deleted/, @changes));
	
    say "Dir: ", $Node->filename, " Changes: ", join(", ", @changes);
    say "          Dir: ", $Node->path;
    
    # If dtime changed - update dtime
    if ( grep(/dtime/, @changes) ) {
	$Node->update_dtime;
    }


    # Update stats so don't scan again, remove, then update in case size / md5 changes, then insert
    $Tree_old->Delete($Node);
    $Node->update_stat;
    $Tree_new->insert($Node);

    # Need to deal with new dirs
    # Exists on disk & changed, so list files in dir and see what to do
    my @Nodes = $Node->List(inc_file => 1, inc_dir =>1);
    foreach my $Node (@Nodes) {
	# If in new list, know unchanged, can move on
	if ($Tree_new->Search(hash => $Node)) {
	    next;
	}

	# In old list, must have moved, update path
	if (my ($old_node) = $Tree_old->Search(hash => $Node)) {
	    if ($old_node->filepath ne $Node->filepath) {
		say "Update filepath: ", $old_node->filename;
		$old_node->filepath($Node->filepath);
	    }
	    next;
	}
	    
	# New file, can directlly put in new list
	say "New File in Dir: ", $Node->filename;
	#if ($Node->isdir){
	$Tree_old->insert($Node);
	#} else {
	$Tree_new->insert($Node);
	#}
    }
}


say " ";
say "After Second Dir Pass  Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);
say " ";


#
# Check Files
#
foreach my $Node ($Tree_old->Search(file => 1)){
    my @changes = $Node->ischanged;

    say "File: ", $Node->filename, " Changes: ", join(", ", @changes);
    say "          Dir: ", $Node->path;
    
    # If doesn't exisit on disk leave in old queue - likely deleted but maybe renamed
    next if (grep(/deleted/, @changes));

    $Tree_old->Delete($Node);
    $Node->update_stat;
    $Node->update_md5;
    $Tree_new->insert($Node);
}


#
# OK - any files left in Old List must have been deleted
#

@Nodes = $Tree_old->Search(file => 1);
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

if (! $Tree_old->count){
    say "Saved File";
    $Tree_new -> save(dir => $dir, name => $db_tree_name);
}

exit;


foreach my $Node (@Dirs){
    $Tree_old->Delete($Node);
    

    # say "Checking: ", $Node->filename;
    my @changes = $Node->ischanged; 
    
    if (! @changes){
	# Unchanged. Move from old list to new.
	$Tree_new->insert($Node);
	next;
    }

    # If Dir has been deleted - put back in old list - may have been renamed
    if ($changes[0] eq "deleted"){
	$Tree_old->insert($Node);
	next;
    }

    say "Changed Dir: ", $Node->filepath, " Delta: ", join(", ", @changes);
    $Node->update_stat;
    $Tree_new->insert($Node);


    # Need to list Dirs in dir & figure out what to do
    my @Files = $Node->List(inc_dir => 1, inc_file => 1);

    foreach (@Files){
	# If already in new Tree - know nothing has changed, we are done with this dir
	if ( defined ${$Tree_new->nodes}{$_->hash} ){
	    next;
	}
	if ( defined ${$Tree_old->nodes}{$_->hash} ){
	    my $old_dir = ${$Tree_old->nodes}{$_->hash};

	    my @changes = $_->delta( $old_dir);
	    next if (! @changes);
	    say "Changes: ", join(', ', @changes);
	    $old_dir->_set_filepath($_->filepath);
	    say "Updated path for ", $old_dir->filename;
	    next;
	}
	say "    New Node: ", $_->filename;	

    }
} # Done with dirs


@Dirs = grep({$_->isdir} $Tree_old->List);

if (@Dirs){
    say " ";
    say "Done Processing dirs and these dirs left: "; 

    foreach(@Dirs){
     say $_->filepath;
 }
}
say " ";

exit;

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

