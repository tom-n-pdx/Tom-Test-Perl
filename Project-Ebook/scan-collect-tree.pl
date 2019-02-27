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
# * Storable fails on very deep dir (Video13) - too deep
#   + paramater to increase depth?
#   + Can disable warning https://www.perlmonks.org/?node_id=324564
#   + Try makng code refs into hash valus

# Perf - download tree - started using heap
#               3.875u 2.796s 0:09.51 70.0%	0+0k 0+1io 0pf+0w


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

my $Files_tree;


#
# Scan each arg as dir root of tree scan.
#
foreach my $dir (@ARGV){
    say "Scanning Tree: $dir" if ($verbose >= 0); 

    # Clear tree
    $Files_tree = NodeHeap->new();
    find(\&wanted,  $dir);
    
    my $count = $Files_tree->count;
    say "Total $count records saved" if ($verbose >= 1);

    # Save Tree
    # $Files_tree->save(dir => $dir, name => $db_tree_name);
    dbfile_save_md5(List => $Files_tree, dir => $dir, type => "tree");

    # Save a copy into Datadir
    my $name = $dir;
    $name =~ s!^/!!;
    $name =~ s!/!_!g;
    $name = "$name$db_tree_name"; 

    dbfile_save_md5(List => $Files_tree, dir => $data_dir, type => 'tree');

}


exit;


sub wanted {
    return unless (-d $File::Find::name);   # if not dir, skip
    return unless (-r $File::Find::name);   # if not unreadable skip
    return unless (-w $File::Find::name);   # if not unreadable skip

    my $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);             # Hack, can't get prune to work - do not check dot file dirs


    # Skip dirs that are hidden or protected
    my $flags = FileUtility::osx_check_flags_binary($dir);
    if ($flags & ($FileUtility::osx_flags{"hidden"} | $FileUtility::osx_flags{uchg}) ){
	return;
    }

    dir_collect_md5($dir);

    return;
}

sub dir_collect_md5 {
     my $dir  = shift(@_);
     my $Files_dir;

     # Check if exiisting datafile
     if ( my $db_mtime = dbfile_exist_md5(dir => $dir) ){
	say "\tdb_file exists " if ($verbose >= 3);
	my $Dir = MooDir->new(filepath => $dir, update_dtime => 1);	

	if ($db_mtime < $Dir->dtime){
	    warn "May need re-scan, db_file older then dir changes Dir: $dir";
	}

	$Files_dir = dbfile_load_md5(dir => $dir);
	my @Nodes = $Files_dir->List;

	# Error check
	 warn "WARN: ", scalar(@Nodes), " loaded from file, Dir: $dir" if (@Nodes < 1);
	 say "Loaded ", scalar(@Nodes), " from file, Dir: $dir" if ($verbose >= 2);


	 # Insert into global list
	 $Files_tree->insert(@Nodes);

     } else {
	 warn("May need re-scan, no db_file Dir: $dir");
     }

     return ($Files_dir);
}

