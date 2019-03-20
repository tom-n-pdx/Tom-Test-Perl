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
# use open qw(:std :utf8);
use FileUtility qw(osx_flags_binary_string osx_check_flags_binary %osx_flags);

#
# Todo
# * Storable fails on very deep dir (Video13) - too deep
#   + paramater to increase depth?
#   + Can disable warning https://www.perlmonks.org/?node_id=324564
#   + Try makng code refs into hash valus
# * check tree date, skip records oldr then tree db?
# * have assed update - load old tree, update it?
# Perf - download tree - started using heap
#               3.875u 2.796s 0:09.51 70.0%	0+0k 0+1io 0pf+0w


our $debug = 0;
our $verbose = 1;
our $errors = 0;

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

# my $db_name =  ".moo.db";
# my $db_tree_name =  ".moo.tree.db";
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

}


exit;


sub wanted {
    my $filename = $_;
    my $dir      = $File::Find::dir;
    my $filepath = $File::Find::name;

    return unless (-d $filepath); # if not dir, skip
    return unless (-r _);         # if not unreadable skip
    return unless (-w _);         # if not writable skip


    # Prune Dot file dirs
    if ($filepath =~ m!/\.!){  
    	$File::Find::prune = 1;
    	say "Prune . Name: $filename Dir:$dir" if ($verbose >= 2);
    	return;
    }

    # Prune dirs with hidden or write protected flags set
    my $flags = osx_check_flags_binary($filepath);

    if ($flags & ($osx_flags{hidden} | $osx_flags{uchg}) ){
	$File::Find::prune = 1;
	my $str   = osx_flags_binary_string($flags);
	say "Prune flagged $str Dir: $filepath" if ($verbose >= 2);
	return;
    }


    # Prunce dirs with SKIP in filename
    if ($filename =~ /SKIP/){
    	$File::Find::prune = 1;
    	say "Prune SKIP Dir: $filepath" if ($verbose >= 2);
    	return;
    }


    dir_collect_md5($filepath);

    return;
}

sub dir_collect_md5 {
     my $dir  = shift(@_);
     my $Files_dir;

     say "Collect $dir" if ($verbose >= 3);

     # Check if exiisting datafile
     if ( my $db_mtime = dbfile_exist_md5(dir => $dir) ){
	say "\tdb_file exists " if ($verbose >= 3);
	my $Dir = MooDir->new(filepath => $dir, update_dtime => 1);	

	# Do rescan
	if ($db_mtime < $Dir->dtime){
	    warn "May need re-scan, db_file older then dir changes Dir: $dir";
	}

	$Files_dir = dbfile_load_md5(dir => $dir);
	my @Nodes = $Files_dir->List;

	# Error check
	warn "WARN: ", scalar(@Nodes), " loaded from file, Dir: $dir" if (@Nodes < 1);
	say "Loaded ", scalar(@Nodes), " from file, Dir: $dir" if ($verbose >= 2);

	# Insert into global list
	foreach my $Node (@Nodes){

	    # Debug code to figure out the duplicate insert problem
	    if (my $Node_old = $Files_tree->Exist(hash => $Node->hash)){
		if ( @{$Node->stats}[3] <= 1){
		    say "Inserting Dupe Node";
		    say "\t", $Node->filepath, " Nlinks: ", @{$Node->stats}[3];
		    say "\t", $Node_old->filepath, " Nlinks: ", @{$Node_old->stats}[3];
		}
	    } else {
		$Files_tree->insert($Node);
	    }
	}
    } else {
	warn("May need re-scan, no db_file Dir: $dir");
    }

     return ($Files_dir);
}

