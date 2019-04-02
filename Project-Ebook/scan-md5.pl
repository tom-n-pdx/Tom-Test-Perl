#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;
use Carp;


use open ':encoding(UTF-8)';
use feature 'unicode_strings';
use utf8;                          # Allow utf8 in source text
binmode STDOUT, ":utf8";
use Encode qw(decode_utf8);

use lib '.';
use ScanDirMD5;
use NodeTree;
use NodeHeap;
use FileUtility qw(osx_check_flags_binary osx_flags_binary_string %osx_flags 
		   dir_list 
		   stats_delta_binary %stats_names);

use lib 'MooNode';
use MooDir;
use MooFile;


# For Debug
# use Data::Dumper qw(Dumper);           # Debug print
# use Scalar::Util qw(blessed);
#
# Todo
# * add --help option
# * Cleanup debug prints & add a write to log?
# * Add a alarm based status update write
# * Merge tree
#   How merge? If tree older then base tree - skip
#   Carry age update down 
# * Configure scan info
# * Move save file sizes to lib

# Notes Perf
# 
# Tested on ~/Downloads, no updates required. PLUGGED IN
# time ./scan-md5.pl -f -v 2 -t ~/Downloads
#
# scan-md5         9.647u 7.403s 0:24.47 69.6%	0+0k 0+9io 0pf+0w
# * 1 less stat    4.736u 3.386s 0:11.72 69.1%	0+0k 0+3io 0pf+0w
#                  4.715u 3.868s 0:11.64 73.6%	0+0k 0+3io 0pf+0w
# +hash md5        4.840u 3.690s 0:12.06 70.7%	0+0k 0+9io 0pf+0w
#                  3.951u 2.802s 0:09.76 69.1%	0+0k 0+50io 0pf+0w
# + iter dir       5.032u 3.658s 0:12.22 71.0%	0+0k 0+10io 7pf+0w
# use heap         3.925u 2.608s 0:09.51 68.5%	0+0k 0+1io 0pf+0w
#                  3.864u 3.204s 0:09.34 75.5%	0+0k 0+0io 0pf+0w  optimized incremental load
#                  3.745u 2.580s 0:09.17 68.9%	0+0k 0+3io 67pf+0w
#                  5.319u 3.941s 0:13.26 69.7%	0+0k 0+5io 0pf+0w  collect tree and save
#                  4.123u 3.039s 0:09.88 72.3%	0+0k 0+0io 37pf+0w use each in loop process nodes in dir
#                  4.104u 3.035s 0:10.00 71.3%	0+0k 0+0io 0pf+0w  optimize load on file
#                  3.554u 2.151s 0:08.36 68.1%	0+0k 253+0io 0pf+0w unoptimized file load, no tree save, no tree merge
#                  0.877u 0.265s 0:01.32 85.6%	0+0k 0+0io 0pf+0w  don't check dates of db file in dir
#
#
# time ./scan-md5.pl -f -v 2 -t ~
# 11.321u 7.841s 0:26.15 73.2%	0+0k 0+0io 37pf+0w
# 

#
# scan-md5-old     9.729u 7.648s 0:24.81 69.9%	0+0k 0+4io 0pf+0w
# scan-smart-md5   4.722u 3.266s 0:11.74 67.9%	0+0k 0+0io 0pf+0w
#                  0.483u 0.050s 0:00.54 98.1%	0+0k 0+1io 29pf+0w

our $total_changes = 0;

our $verbose    = 1;

our $calc_md5   = 1;
our $force_save = 0;

our $tree       = 0;
our $save_tree  = 0;

our $md5_save_limit = 100;


GetOptions (
    'verbose=i'   => \$verbose,
    'md5=i'       => \$calc_md5,
    'update'      => \$force_save,
    'tree'        => \$tree,
    'save'        => \$save_tree,
);

# @ARGV = map { decode_utf8($_, 1) } @ARGV;
if ($verbose >= 2){
    say "Options";

    say "\tVerbose:   ", $verbose;
    say "\tCalc MD5:  ", $calc_md5;
    say "\tUpdate:    ", $force_save;
    say "\tTree:      ", $tree;
    say "\tSave Tree: ", $save_tree; 

    say " ";
}

# If existing file of dupe sizes, load
# my %size_count;
# load_dupes(dupes => \%size_count, verbose => $verbose - 1);
load_dupes; 

my $Files_new;
my $Files_tree;

#
# Scan each arg as dir, using dir or tree scan.
#
foreach my $dir (@ARGV){
    if ($tree){

	# Clear Tree
	$Files_tree =  NodeHeap->new;
	say "Scanning Tree: $dir" if ($verbose >= 0); 

	find(\&wanted,  $dir);

	if ($save_tree){
	    dbfile_save_md5(List => $Files_tree, dir => $dir, type => "tree");
	    say "Saved Tree Records: ", $Files_tree->count if ($verbose >= 1); 
	}
	
    } else {
 	say "Scanning Dir: $dir" if ($verbose >= 0 ); 
	$Files_new = scan_dir_md5(dir=>$dir, calc_md5=> $calc_md5, force_save => $force_save);
    }
}

say "Total Changes: $total_changes (", &files_change_total_string, ")"; 

# &save_dupes(dupes => \%size_count) if ($total_changes > 0);
save_dupes if ($total_changes > 0);

exit;


#
# File find wanted sub. For any file that is a readable and writeable dir 
# 
sub wanted {
    my $filename = $_;
    my $dir      = $File::Find::dir;
    my $filepath = $File::Find::name;

    return unless (-d $filepath); # if not dir, skip
    return unless (-r _);         # if not unreadable skip
    return unless (-w _);         # if not unreadable skip


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

    if (ignore_dir_md5($filepath)){
    	$File::Find::prune = 1;
    	say "Prune based upon config Dir: $filepath" if ($verbose >= 2);
    	return;
    }


    $Files_new = scan_dir_md5(dir => $filepath, calc_md5 => $calc_md5);

    if ($save_tree){
	$Files_tree->insert($Files_new->List);
    }

    return;
}


#
#
# Scan a dir and calc md5 values. As part of scan will check if dir is valid, and load and save a md5 db file
#
#
sub scan_dir_md5 {
    my %opt = @_;
    my $dir           = delete $opt{dir} or die "Missing param to scan_dir_md5";
    my $calc_md5      = delete $opt{calc_md5}   // 0;
    my $force_save    = delete $opt{force_save} // 0;
    my $verbose       = delete $opt{verbose}    // $main::verbose;
    die "Unknown params:", join ", ", keys %opt if %opt;

    say "\tChecking $dir Unicode: ", utf8::is_utf8($dir) ? "Yes" : "No"  if ($verbose >= 2);

    my $Files_old = NodeHeap->new;
    my $Files_new = NodeHeap->new;

    # If force update, make an extra change 
    if ($force_save) {
	$files_change{change} += 1;
	say "\tForcing dbsave" if ($verbose >= 3);
    }

    my $Dir = MooDir->new(filepath
 => $dir, update_dtime => 0);
    

    # Check if existing dir db file or not
    if ( dbfile_exist_md5(dir => $dir) ){
	say "\tdb_file exists " if ($verbose >= 3);
	$Files_old = dbfile_load_md5(dir => $dir);
    } else {
	# Trick - create empty datafile and update Dir stats so on next time scan datafile older then Dir, and force a save
	dbfile_clear_md5(dir => $dir);
	$Dir->update_stats;
	$files_change{change} += 1;
    }
    
    # Check if Dir exists in datafile
    my $Dir_old = $Files_old->Exist(hash => $Dir->hash);
 
    # If Dir does not exisit in old list - maybe inode changed, maybe did not load a good datafile
    if (! $Dir_old){
    	say "\tDir does not exisit in db_file" if ($verbose >= 2);
    	$Dir->need_update(1);
    	$Files_old->insert($Dir);
    } elsif ($Dir_old->filepath ne $Dir->filepath){
    	say "\tDir rename" if ($verbose >= 1);
    	$Dir_old->need_update(1);
    	$Dir_old->filepath($Dir->filepath);
	$files_change{rename} += 1;
    }	

    # 
    # Loop thru old files and see if any changes
    #
    while (my $Node = $Files_old->Each){
	say "    ", $Node->type, " ", $Node->filename if ($verbose >= 3);

	# If doesn't exist on disk - leave in old list for now
	my @stats = stat($Node->filepath);   # If no stats, file does not exist
	next if (! @stats);

	# Check changes and mask off atime or dev changes
	my $changes = stats_delta_binary($Node->stats,  \@stats) & ~$stats_names{atime} & ~$stats_names{dev};
	my $need_update = $changes || $Node->need_update;

	# If the inode has changed, this is not the same file
	next if ($changes & $stats_names{ino});

	# Remove from Old List
	# Since some changes modify size, md5 - and they are indexed by that, we need
	# to remove from old List, update, then insert into new list. A delete of last Each Node won't cause problems
        #   with using Each itterator

	$Files_old->Delete($Node);
	update_file_md5(Node => $Node, changes => $changes, stats => \@stats, calc_md5 => $calc_md5);
	$Files_new->insert($Node);

	# If changes & dir - need to do more work. do not include subdirs
	if ( $Node->isdir && $need_update){
	    &update_dir_md5(Dir => $Node, changes => $changes, stats => \@stats, calc_md5 => $calc_md5,
			    Files_old => $Files_old, Files_new => $Files_new, 
			    inc_dir => 0);
	}	
    }
    

    # Done scanning old files, check if any objs left - file must have been deleted, or moved to new dir
    # A renamed file we would have caught becuase the inode stayed the same and we did a update dir
    my @Files_deleted = $Files_old->List;
    $files_change{delete} += scalar(@Files_deleted);

    if (@Files_deleted >= 1 && $verbose >= 1){
    	say "    Deleted files:";
    	foreach my $File (@Files_deleted){
    	    say "      ", $File->filename;
    	}
    }

    my $changes = &files_change_total;
    $total_changes = $total_changes + $changes;

    if ($changes > 0){ 
	say "    Saved Datafile Records: ", $Files_new->count if ($verbose >= 2);
	dbfile_save_md5(List => $Files_new, dir => $dir);
    }
    say "  Checking $dir" if ($verbose == 1 && $changes > 0);
    say("    Changes: $changes (", &files_change_string, ")") 
	if ($verbose >= 2 or ($changes > 0 && $verbose >= 1));
    &files_change_clear;

    return $Files_new;
}


