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
use NodeHeap;

use lib 'MooNode';
use MooDir;
use MooFile;

# For Debug
use Data::Dumper qw(Dumper);           # Debug print
use Scalar::Util qw(blessed);
# use utf8;
use open qw(:std :utf8);

#
# Todo
# * Check packed, then regular - either
#
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
my $db_name_packed = ".moo.dbp";

my $db_tree_name =  ".moo.tree.yaml";
# my $db_tree_name_packed =  ".moo.tree.dbp";
my $data_dir = "/Users/tshott/Downloads/Lists_Disks";

my $Heap;


#
# Scan each arg as dir root of tree scan.
#
foreach my $dir (@ARGV){
    say "Scanning Tree: $dir" if ($verbose >= 0); 

    # Clear tree
    $Heap = NodeHeap->new();
    find(\&wanted,  $dir);
    
    # Save Tree
    my $count = $Heap->count;
    say "Total $count records saved" if ($verbose >= 1);
    $Heap -> save(       dir => $dir, name => $db_tree_name);

    # Save a copy into Datadir
    my $name = $dir;
    $name =~ s!^/!!;
    $name =~ s!/!_!g;
    $name = "$name$db_tree_name"; 
    # say "data dir name: $name";

    $Heap -> save(dir => $data_dir, name => $name);
    
}


exit;


sub wanted {
    return unless (-d $File::Find::name);   # if not dir, skip
    return unless (-r $File::Find::name);   # if not unreadable skip
    return unless (-w $File::Find::name);   # if not unreadable skip

    my $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs

    my $flags = FileUtility::osx_check_flags_binary($dir);
    if ($flags & ($FileUtility::osx_flags{"hidden"} | $FileUtility::osx_flags{uchg}) ){
	return;
    }

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
	 say "Loaded ", scalar(@Nodes), " from file, Dir: $dir" if ($verbose >= 2);


	 # Insert into global list
	 $Heap->insert(@Nodes);

     } else {
	 warn("May need re-scan, no db_file Dir: $dir");
     }

     return ($Tree_dir);
}

