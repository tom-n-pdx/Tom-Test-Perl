#!/usr/bin/env perl
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

# For Debug
use Data::Dumper qw(Dumper);           # Debug print
use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * Load dupes on start - make a Nodetree item?
# * Fix hash function, record dev to mount name somewhere.
# * return number of changes for dir update - total changes
# * detect hidden, invisable, dot files and skip in tree scan
#   ls -ldO@ /private
#   set hidden - sudo chflags hidden /private
#                flags: hidden
# * BUG - not loading and recgnaizing old files

my %size_count;

my ($files_new, $files_rename, $files_delete, $files_change, $files_md5) = (0, 0, 0, 0, 0);


our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree=0;


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
    say "\tTree: ", $tree;

    say " ";
}


#
# Scan each arg as dir, using dir or tree scan.
#
foreach my $dir (@ARGV){
    if ($tree){
	say "Scanning Tree: $dir" if ($verbose >= 0); 
	find(\&wanted,  $dir);
    } else {
	say "Scanning Dir: $dir" if ($verbose >=0 ); 
	update_dir(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
    }
}

# Debug code - report on sizes with more then one
if ($verbose >=2){
    say "Dupe Szes:";
    foreach my $size (sort {$a <=> $b} keys %size_count){
	next if $size_count{$size} <= 1;
	say "\t$size $size_count{$size}";
    }
}

exit;



#
# ToDo
#
# File find wanted sub. For any file that is a readable dir 
# 
sub wanted {
    return unless (-d $File::Find::name);   # if not readable dir, skip
    return unless (-r $File::Find::name);   # skip unreadable dirs

    my  $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - skip dot files

    update_dir(dir=>$dir, fast_scan=>$fast_scan, fast_dir=>$fast_dir);

    return;
}


#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
sub update_dir {
    my %opt = @_;
    my $fast_scan =  delete $opt{fast_scan} // 0;
    my $fast_dir  =  delete $opt{fast_dir}  // 0;
    my $dir       =  delete $opt{dir} or die "Missing param to scan_dir_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;


    say "\tFAST SCAN" if ($fast_scan && $verbose >= 2);
    ($files_new, $files_rename, $files_delete, $files_change) = (0, 0, 0, 0); # Global vars to record changes

    say "Scanning $dir" if ($verbose >= 2);

    my $Dir = MooDir->new(filepath => $dir);
    my ($Tree_old, $db_mtime) = NodeTree->load(dir => $dir);

    if ($fast_dir && $db_mtime >= $Dir->dtime){
      	say "\tNo Files chaged, skip update" if ($verbose >= 2);
      	return( () );
    }

    my $Tree = NodeTree->new();	             # Store new files in Tree
    
    # Scan through for all files in dir and the Dir obj
    my @Nodes = $Dir->List;
    push(@Nodes, $Dir);

    foreach my $Node (@Nodes) {
	update_file(file => $Node, Files_old_ref => $Tree_old, fast_scan=>$fast_scan);
	$Tree->insert($Node);

	# Save every so often
	if ($files_md5 > 0 && $files_md5 % 100 == 0){
	    # save_dir_db(dir => $dir, Files_ref => $Tree);
	    $Tree -> save(dir => $dir);

	    say "\tCheckpoint Save File Changes: New: $files_new Rename: $files_rename Changed: $files_change MD5: $files_md5 Deleted: $files_delete";
	}
    }


    # Now Check if any old values left - file must have been deleted, or moved to new dir
    my @Files = $Tree_old->List;
    $files_delete += scalar(@Files);
    if (@Files >= 1 && $verbose >= 1){
	say "\tDeleted files:";
	foreach my $File (@Files){
	    say "\t\t", $File->filename;
	}
    }

    my $total_change = $files_new + $files_rename + $files_delete + $files_change + $files_md5;
    if ( $total_change > 0){
	# save_dir_db(dir => $dir, Files_ref => $Tree);
	$Tree -> save(dir => $dir);

	print "Dir: $dir " if ($verbose <= 1);
	say "\tFile Changes: New: $files_new Rename: $files_rename Changed: $files_change MD5: $files_md5 Deleted: $files_delete";
    }

    return ($Tree->List);
}

#
# Process one file
# * Pass in a File Object, list of old files
# * Retuns updated $File - update ref?
#
 
sub update_file {
    my %opt = @_;

    my $File        = delete $opt{file} or die "Missing param 'filepath' to update_file";
    my $Tree_old    = delete $opt{Files_old_ref} or die "Missing param 'Files_old_ref' to update_file";
    my $fast_scan   = delete $opt{fast_scan} // 0;
    die "Unknown params:", join ", ", keys %opt if %opt;

    say "\tChecking: ", $File->filename if ($verbose >= 3);

    my $hash = $File->hash;
    my $File_old = ${$Tree_old->nodes}{$hash};

    if (! defined $File_old) {
	# If no old file with inode, must be new file (could be new file with same name, and diff inode)
	say "\t\tNew File: ", $File->filename if ($verbose >= 2);
	$files_new++;
    } else {

	# If old file is same size and same modified date
	if ( ($File->size == $File_old->size) && ($File->ctime == $File_old->ctime) ) {
	    say "\t\tExisitng Unchanged: ", $File->filename if ($verbose >= 3);
	    if ($File->can('md5') && defined $File_old->md5){
		$File->_set_md5($File_old->md5);
	    }
	} else {
	    $files_change++;
	    say "\t\tExisitng Changed: ",$File->filename if ($verbose >= 2);
	    my @changes = $File->delta($File_old);
	    say "\t\t\tDelta: ", join(", ", @changes)if ($verbose >= 2);
	}

	# Check if name changed
	# if ($File->filename ne $File_old->filename) {
	#     say "\t\tRename: ", $File_old->filename, " to ", $File->filename if ($verbose >= 1);
	#     $files_rename++;
	# }
	
	$Tree_old->remove($hash);
    }
    $size_count{$File->size}++;

    # obj supports md5 and it's not set and object readable calc md5
    if ($File->can('md5') && !defined($File->md5) && $File->isreadable){
	my $count = $size_count{$File->size};
	if ( !$fast_scan or $count >= 2) {	    
	    say "\t\tCalc md5: ", $File->filename if ($verbose >= 2 or $count >= 2);
	    say "\t\t\tPossible Dupe # $count" if ($count >=2);

	    $File->update_md5;
	    $files_md5++;

	}
    }
    return ($File);
}


