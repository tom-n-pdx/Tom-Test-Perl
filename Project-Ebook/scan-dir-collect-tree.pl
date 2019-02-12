#!/usr/bin/env perl
#
# Scan tree and merge all dir data files into one tree datafile.
# No check for if dir files are up to date
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
# * Storable fails on very deep dir (Video13) - too deep
#   + paramater to increase depth?
#   + Can disable warning https://www.perlmonks.org/?node_id=324564
#   + Try makng code refs into hash valus

# * Skip system directories



our $debug = 0;
our $verbose = 1;

GetOptions (
    'debug=i'     => \$debug,
    'verbose=i'   => \$verbose,
);

if ($debug or $verbose >= 2){
    say "Options";

    say "\tDebug: ", $debug;
    say "\tVerbose: ", $verbose;
    say " ";
}

my $Tree;


#
# Scan each arg as dir root of tree scan.
#
foreach my $dir (@ARGV){
    say "Scanning Tree: $dir" if ($verbose >= 0); 

    # Clear tree
    $Tree = NodeTree->new();
    find(\&wanted,  $dir);
    
    # Save Tree
    my $count = $Tree->count;
    say "Total $count records loaded";
    save_tree_db(dir => $dir, Files_ref => $Tree);
    
}


exit;



#
# ToDo
# 
#
sub wanted {
    return unless $_ eq ".moo.db";

    my $dir = $File::Find::dir;

    say "Loaded data from $dir" if ($verbose >= 2);
    my ($Tree_new, $db_mtime) = load_dir_db(dir => $dir);
    $Tree->insert($Tree_new->List);
    
    return;
}




#
# Function: Load a md5 oop datafile
# 
# Add rename old one after store
#
use Storable;

#
# Move into module - share with scan dirs
#
sub save_tree_db {
    my %opt = @_;

    my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_db";
    my $Tree = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_dir_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $dbfile      = "$dir/.moo.tree.db";
    my $dbfile_temp = "$dbfile.tmp";

    # Save into remp and rotate files
    store($Tree, $dbfile_temp);
    rename($dbfile, "$dbfile.old") if -e $dbfile;
    rename($dbfile_temp, $dbfile);

    my $count = $Tree->count;
    say "Saved $count records" if ($verbose >= 2);

    return;
}

#
# Common - move into module
#
sub load_dir_db {
    my %opt = @_;

    my $dir =  delete $opt{dir} or die "Missing param 'dir' to load_dir_db";
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $Tree = NodeTree->new();

    my $dbfile_mtime = 0;
    my $dbfile = "$dir/.moo.db";

    if (-e $dbfile) {
	# Need to test for exceptions if have old incompatable file
	eval { $Tree = retrieve($dbfile)} ;
	# $Tree = retrieve($dbfile) ;
	if (blessed($Tree) && $Tree->count >= 1){ 
	    my $count = $Tree->count;
	    say "Loaded $count records" if ($verbose >= 2);
	} else {
	    # clear data if not load blessed object
	    warn "Tree not blessed $dir";
	    $Tree = NodeTree->new();
	}
	$dbfile_mtime = (stat(_))[9];
    } else {
	warn "No dbfile";
    }
    return ($Tree, $dbfile_mtime);
}
