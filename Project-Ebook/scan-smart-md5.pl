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

if (!-e "$dir/$db_tree_name"){
    die "No exiisting tree daatfile: $dir";
}

my $Tree_old    = NodeTree->load(dir => $dir, name => $db_tree_name);
my $Tree_new    = NodeTree->new;
my $Tree_trash  = NodeTree->new;

$Tree_old->summerize;

say " ";
say "Start Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);


# Need to first scan Dirs
# my @Dirs = grep({$_->isdir} $Tree_old->List);
# my @Dirs = $Tree_old->Search(dir => 1);
my @Dirs;

# First Scan amd see if ANYTHING chanegd
foreach my $Node ($Tree_old->List){

    my @changes = $Node->ischanged;
    
    # If no changes, move to new Tree
    if (scalar(@changes) < 1){

	$Tree_old->Delete($Node);
	$Tree_new->insert($Node);
	next;
    }

    # If Node has changes, we will deal with in second pass - leave in Old Tree
    say "Pass 1 Detect Changes Name: ", $Node->filename, " Changes: ", join(", ", @changes);

}

say " ";
say "After First Pass  Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);

if (! scalar($Tree_old->count)){
    say "No Changes! - Exit";
    exit;
}


$verbose = 2;

# Second Scan and see what need to fixup
# werid - changing flags changes inode value

# foreach my $Node ($Tree_old->List){
my @Nodes;


#
# Check Dirs
# - problem - did we use files, dot files, etc when ran before?
@Dirs = $Tree_old->Search(dir => 1);
foreach my $Node (@Dirs){
    my @changes = $Node->ischanged;

    # If doesn't exisit on disk leave in old Tree - likely deleted but maybe renamed
    next if (grep(/deleted/, @changes));
	
    say "Dir: ", $Node->filename, " Changes: ", join(", ", @changes);
    say "          Dir: ", $Node->path;
    
    # If only dtime changed - update dtime and move to new
    if ( grep(/dtime/, @changes) ){
	$Node->update_dtime;
	# @changes = grep(! /dtime/, @changes);
	
	# if (!@changes){
	#     $Tree_old->Delete($Node);
	#     $Tree_new->insert($Node);
	#     next;
	# }
    }

    # Update stats so don't scan again, remove, then update in case size / md5 changes, then insert
    $Tree_old->Delete($Node);
    $Node->update_stat;
    $Tree_new->insert($Node);

    # Need to deal with new dirs
    # Exists on disk & changed, so list files in dir and see what to do
    my @Nodes = $Node->List(inc_file => 1, inc_dir =>1);
    foreach my $Node (@Nodes){
	# If in new list, know unchanged, can move on
	if ($Tree_new->Search(hash => $Node)){
	    next;
	}
	# In old list, must have changed, update path?
	if (my ($old_node) = $Tree_old->Search(hash => $Node)){
	    if ($old_node->filepath ne $Node->filepath){
		say "Update filepath: ", $old_node->filename;
		$old_node->filepath($Node->filepath);
	    }
	    next;
	}

	# New file, can directlly put in new list
	say "New File in Dir: ", $Node->filename;
	$Tree_new->insert($Node);
    }
    
}
say " ";
say "After Second Dir Pass  Old: ", scalar($Tree_old->count), " New: ", scalar($Tree_new->count);


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






# say " ";
# say "Dir Unchanged: ";

# say " ";
# say "Dir Changed: ";
# foreach($Tree_changed->List){
#     say $_->filepath;
# }

# say " ";
# say "Dir Deleted: ";
# foreach($Tree_trash->List){
#     say $_->filepath;
# }
# say " ";


# Now scan files
# my @Files = $Tree_old->List;


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

# # If existing file of dupe sizes, load
# &load_dupes(dupes => \%size_count);

# #
# # Scan each arg as dir, using dir or tree scan.
# #
# foreach my $dir (@ARGV){
#     if ($tree){
# 	say "Scanning Tree: $dir" if ($verbose >= 0); 
# 	find(\&wanted,  $dir);
#     } else {
# 	say "Scanning Dir: $dir" if ($verbose >=0 ); 
# 	update_dir_md5(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
#     }
# }

# &save_dupes(dupes => \%size_count);

# exit;



# #
# # File find wanted sub. For any file that is a readable and writeable dir 
# # 
# sub wanted {
#     return unless (-d $File::Find::name);   # if not dir, skip
#     return unless (-r $File::Find::name);   # if not readable skip
#     return unless (-w $File::Find::name);   # if not writeable skip

#     # Need to check flags on OSX 
#     my @flags = FileUtility::osx_check_flags($File::Find::name);
    
#     # say "Check Flags $_ ", join(', ', @flags);

#     if (grep(/hidden/, @flags) or grep(/uchg/, @flags)){
# 	return;
#     }

#     my  $dir = $File::Find::name;
#     return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs

#     update_dir_md5(dir=>$dir, fast_scan=>$fast_scan, fast_dir=>$fast_dir);

#     return;
# }


# #
# # Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
# #
# sub update_dir_md5 {
#     my %opt = @_;
#     my $fast_scan =  delete $opt{fast_scan} // 0;
#     my $fast_dir  =  delete $opt{fast_dir}  // 0;
#     my $dir       =  delete $opt{dir} or die "Missing param to scan_dir_md5";
#     die "Unknown params:", join ", ", keys %opt if %opt;


#     ($files_new, $files_delete, $files_change, $files_md5, $files_rename) = (0, 0, 0, 0, 0);
#     say "Scanning $dir" if ($verbose >= 2);

#     my $Tree_old = NodeTree->new(name => $dir);
#     my $Dir = MooDir->new(filepath => $dir);

#     # Check if exiisting datafile
#     if (-e "$dir/$db_name"){
# 	say "\tdb_file exists " if ($verbose >= 2);
# 	my $db_mtime = (stat("$dir/$db_name"))[9];
# 	if ($fast_dir && $db_mtime >= $Dir->dtime){
# 	    say "\tQuick Dir scan enabled, No Files chaged, skip scan" if ($verbose >= 2);
# 	    return( () );
# 	}

# 	$Tree_old = NodeTree->load(dir => $dir, name => $db_name);
#     } else {
# 	# trick, need to create empty datafile at start of check, so Dir change mtime includes the new file
# 	say "\tdb_file does not exists - create empty one." if ($verbose >= 2);
# 	`touch "$dir/$db_name"`;
# 	$Dir = MooDir->new(filepath => $dir);
#     }

#     my $Tree = NodeTree->new(name => $dir);      # Store new files in Tree
    
#     # Scan through all files in dir and the Dir obj. Can process Dir just like any other object
#     # By default, Dir->List returns only normal files, not sym links, dirs, invisable or dot files
#     my @Nodes = $Dir->List;
#     push(@Nodes, $Dir);


#     foreach my $Node (@Nodes) {
# 	update_file(file => $Node, Files_old_ref => $Tree_old, fast_scan=>$fast_scan);
# 	$Tree->insert($Node);

# 	# Save every so often
# 	if ($files_md5 > 0 && $files_md5 % $md5_save_limit == 0){
# 	    $Tree -> save(dir => $dir, name => $db_name);
# 	    say "\tCheckpoint Save File Changes: New: $files_new Changed: $files_change MD5: $files_md5 Deleted: $files_delete";
# 	}
#     }


#     # Done scanning new files, check if any old values left - file must have been deleted, or moved to new dir
#     # Renamed file we would have caught becuase same inode
#     my @Files = $Tree_old->List;
#     $files_delete += scalar(@Files);
#     if (@Files >= 1 && $verbose >= 1){
# 	say "\tDeleted files:";
# 	foreach my $File (@Files){
# 	    say "\t\t", $File->filename;
# 	}
#     }

#     my $total_change = $files_new + $files_delete + $files_change + $files_md5 + $files_rename;
#     if ( $total_change > 0){
# 	$Tree -> save(name => $db_name);
# 	say "\tFile Changes: New: $files_new Changed: $files_change MD5: $files_md5 Deleted: $files_delete Rename: $files_rename";
#     }

#     # DEBUG
#     # $Tree->save_packed;

#     return ($Tree->List);
# }

# #
# # Process one file
# # * Pass in a File Object, ref to old files
# # * Retuns updated File Object
# # 
# sub update_file {
#     my %opt = @_;

#     my $File        = delete $opt{file} or die "Missing param 'File' to update_file";
#     my $Tree_old    = delete $opt{Files_old_ref} or die "Missing param 'Files_old_ref' to update_file";
#     my $fast_scan   = delete $opt{fast_scan} // 0;
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     say "\tChecking: ", $File->filename if ($verbose >= 3);

#     my $hash = $File->hash;
#     # my $File_old = ${$Tree_old->nodes}{$hash};
#     my ($File_old) = $Tree_old->Search(hash => $File);

#     if (! defined $File_old) {
# 	# If no old file with inode, must be new file (could be new file with same name, and diff inode)
# 	say "\t\tNew File: ", $File->filename if ($verbose >= 2);
# 	$files_new++;
#     } else {
# 	my @changes = $File->delta($File_old);
# 	if (@changes > 0 && $verbose >= 2){
# 	    say "\t\tDelta: ", join(", ", @changes);
# 	}
	
# 	# If old file is same size and same modified date - update any expensive values, such as md5
#         # Use mtime - don't care if name changed - care that contents changed
# 	if ( ($File->size == $File_old->size) && ($File->mtime == $File_old->mtime) ) {
# 	    say "\t\tExisitng Unchanged: ", $File->filename if ($verbose >= 3);
# 	    if ($File->can('md5') && $File_old->can('md5') && defined $File_old->md5){
# 		$File->_set_md5($File_old->md5);
# 	    }
# 	} else {
# 	    $files_change++;
# 	    say "\t\tExisitng Changed: ",$File->filename if ($verbose >= 2);
# 	    say "\t\t\tDelta: ", join(", ", @changes)if ($verbose >= 2);
# 	}
	
# 	# Need to independently check for rename - could be same size & mtime but a rename
# 	if ($File->filename ne $File_old->filename){
# 	    $files_rename++;
# 	    say "\t\tRenamed: ",$File_old->filename, 
# 		"\n\t\t     To: ", $File->filename if ($verbose >= 2);
# 	}

# 	# $Tree_old->Delete($hash);
# 	$Tree_old->Delete($File_old);
#     }
#     $size_count{$File->size}++;

#     # if obj supports md5 and it's not set and object is readable then calc md5 (only files today)
#     if ($File->can('md5') && !defined($File->md5) && $File->isreadable){
# 	my $count = $size_count{$File->size};

# 	# Skip if fast scan, unless it's a dupe size, then calc MD5
# 	if ( !$fast_scan or $count >= 2) {	    
# 	    say "\t\tCalc md5: ", $File->filename if ($verbose >= 2 or $count >= 2);
# 	    say "\t\t\tPossible Dupe # $count" if ($count >=2);

# 	    $File->update_md5;
# 	    $files_md5++;
# 	}
#     }
#     return ($File);
# }

