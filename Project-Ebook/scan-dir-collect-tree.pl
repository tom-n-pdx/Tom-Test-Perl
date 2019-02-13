#!/usr/bin/env perl
#
# Scan tree and merge all dir data files into one tree datafile.
# In any dir, checks for a db_file and merges it into tree.
#
# Good idea to make data files dor files, not rotate. When update the dir dtime does not change.
# 
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

my $db_name =  ".moo.db";
my $db_tree_name =  ".moo.tree.db";
my $data_dir = "/Users/tshott/Downloads/Lists_Disks";

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

    $Tree -> save(dir => $dir, name => $db_tree_name);

    # Save a copy into Datadir
    my $name = $dir;
    $name =~ s!^/!!;
    $name =~ s!/!_!g;
    $name = "$name$db_tree_name"; 
    # say "data dir name: $name";

    $Tree -> save(dir => $data_dir, name => $name);
}


exit;



#
# ToDo
# 
#
# sub wanted {
#     return unless ($_ eq $db_name);

#     my $dir = $File::Find::dir;
#     dir_collect_md5($dir);

#     return;
# }

sub wanted {
    return unless (-d $File::Find::name);   # if not dir, skip
    return unless (-r $File::Find::name);   # if not unreadable skip

    my $dir = $File::Find::name;
    dir_collect_md5($dir);

    return;
}


sub dir_collect_md5 {

     my $dir  = shift(@_);
     my $Tree_dir = NodeTree->new;

     # Check if exiisting datafile
     if (-e "$dir/$db_name"){

	 # Check if db_file outdated
	 my $Dir      = MooDir->new(filepath => $dir);
	 my $db_mtime = (stat("$dir/$db_name"))[9];
	 if ($db_mtime < $Dir->dtime){
	     warn "May need re-scan, db_file older then dir changes Dir: $dir";
	 }


	 $Tree_dir = NodeTree->load(dir => $dir, name => $db_name);

	 my @Nodes = $Tree_dir->List;

	 # Error check
	 warn "WARN: ", scalar(@Nodes), " loaded from file, Dir: $dir" if (@Nodes < 1);

	 # Insert into global list
	 $Tree->insert(@Nodes);

     } else {
	 warn("May need re-scan, no db_file Dir: $dir");
     }

     return ($Tree_dir);
}






# #
# # Function: Load a md5 oop datafile
# # 
# # Add rename old one after store
# #
# use Storable;

# #
# # Move into module - share with scan dirs
# #
# sub save_tree_db {
#     my %opt = @_;

#     my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_db";
#     my $Tree = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_dir_md5";
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $dbfile      = "$dir/.moo.tree.db";
#     my $dbfile_temp = "$dbfile.tmp";

#     # Save into remp and rotate files
#     store($Tree, $dbfile_temp);
#     rename($dbfile, "$dbfile.old") if -e $dbfile;
#     rename($dbfile_temp, $dbfile);

#     my $count = $Tree->count;
#     say "Saved $count records" if ($verbose >= 2);

#     return;
# }

# #
# # Common - move into module
# #
# sub load_dir_db {
#     my %opt = @_;

#     my $dir =  delete $opt{dir} or die "Missing param 'dir' to load_dir_db";
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $Tree = NodeTree->new();

#     my $dbfile_mtime = 0;
#     my $dbfile = "$dir/.moo.db";

#     if (-e $dbfile) {
# 	# Need to test for exceptions if have old incompatable file
# 	eval { $Tree = retrieve($dbfile)} ;
# 	# $Tree = retrieve($dbfile) ;
# 	if (blessed($Tree) && $Tree->count >= 1){ 
# 	    my $count = $Tree->count;
# 	    say "Loaded $count records" if ($verbose >= 2);
# 	} else {
# 	    # clear data if not load blessed object
# 	    warn "Tree not blessed $dir";
# 	    $Tree = NodeTree->new();
# 	}
# 	$dbfile_mtime = (stat(_))[9];
#     } else {
# 	warn "No dbfile";
#     }
#     return ($Tree, $dbfile_mtime);
# }
