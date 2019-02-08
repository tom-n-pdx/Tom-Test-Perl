#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use lib 'MooNode';
use MooDir;
use MooFile;

#
# Todo
# * add --help option
# * Add status update if doing lots of md5 on dir
# * move collect dupes, into seperate sub
# * merge ave tree & save dir into one sub
# * check dupes when scan unchanged dir
# * bug - if no dir change - won't update missing md5 if fast scan earrlier

# dupes
# * problem is when first dupe in seperate dir from 2nd dupe - need to redo first dir
# * worse - dupes in seperate trees


my %Files;
my %size_count;
my %size_dir;

our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $tree=0;


GetOptions (
    'debug=i'       => \$debug,
    'verbose=i'    => \$verbose,
    'fast'          => \$fast_scan,
    'tree'              => \$tree,
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
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old data
#
foreach my $dir (@ARGV){
    if ($tree){
	say "Scanning Tree: $dir" if ($verbose >= 0); 
	find(\&wanted,  $dir);
		
	say "Collected ", scalar(keys %Files), " records" if ($verbose >= 0);
	save_tree_oop_db(dir => $dir, Files_ref => \%Files);
	undef %Files;
    } else {
	say "Scanning Dir: $dir" if ($verbose >=0 ); 
	update_dir_oop(dir=>$dir, fast_scan=>$fast_scan);
    }
}

exit;



#
# ToDo
#
sub wanted {
    return if (!-d $File::Find::name);           # if not dir, skip

    my  $dir = $File::Find::name;
    return if ($dir =~ m!/\.!);                    # Hack, can't get prune to work

    my %Files_new = update_dir_oop(dir=>$dir, fast_scan=>$fast_scan);

    # Add dupe size check
    %Files = (%Files, %Files_new);

   return;
}


#
# Scan a dir and calc md5 values. As part of scan will check if dir valid, and load and save a md5 db file
#
sub update_dir_oop {
    my %opt = @_;
    my $fast_scan =  delete $opt{fast_scan} // 0;
    my $dir_check =  delete $opt{dir} or die "Missing param to scan_dir_oop_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    say "\tFAST SCAN" if ($fast_scan && $verbose >= 2);
    my %Files;

    if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
    	warn "Bad Dir: $dir_check";
    	return %Files;
    }

    my ($files_new, $files_rename, $files_delete, $files_change) = (0, 0, 0, 0);

    say "Scanning $dir_check" if ($verbose >= 1);
    my $Dir = MooDir->new(filepath => $dir_check);

    my ($Files_old_ref, $db_mtime) = load_dir_oop_db(dir => $dir_check);
    my %Files_old = %{$Files_old_ref};

    if ($db_mtime >= $Dir->dtime){
	say "No Files chaged, skip update" if ($verbose >= 2);
	return(%Files_old);
    }

    my @filepaths = $Dir->list_filepaths();
    say "Files: ", join(", ", @filepaths) if ($verbose >= 3);

    # Scan through for all files in dir
    foreach my $filepath (@filepaths) {
	my $File = MooFile->new(filepath => $filepath, opt_update_md5=>0);
	my $hash = $File->inode;

	my $File_old = $Files_old{$hash};
	if (! defined $File_old) {
	    # Assume if no old file with inode, must be new file
	    say "New File: ", $File->filename if ($verbose >= 1);
	    $files_new++;
	} else {
	    # If old file newer or same age, transfer md5
	    if (defined $File_old->md5 && $File->size == $File_old->size && $File->mtime <= $File_old->mtime) {
		$File->_set_md5($File_old->md5);
	    }
	    # Check if name changed
	    if ($File->filename ne $File_old->filename) {
		say "Rename: ", $File_old->filename, " to ", $File->filename if ($verbose >= 1);
		$files_rename++;
	    }
	}
	delete $Files_old{$hash};


	$size_count{$File->size}++;
	my $count = $size_count{$File->size} // 0;
	# say "Count: $count" if ($count >= 2);
	if ( !defined($File->md5) && ( !$fast_scan or $count >= 2)) {
	    say "Calc md5: ", $File->filename if ($verbose >= 2 or $count >= 2);
	    if ($File->isreadable){
		$File->update_md5;
		$files_change++;
	    }
	}
	$Files{$hash} = $File;

	if ($files_change > 1 && $files_change % 100 == 0) {
	    save_dir_oop_db(dir => $dir_check, Files_ref => \%Files);
	    print "Dir: $dir_check " if ($verbose <= 1);
	    say "File Changes: New: $files_new Rename: $files_rename Changed: $files_change Deleted: $files_delete";
	}
    }

    # Now Check if any old values left
    my @keys = keys %Files_old;
    $files_delete += scalar(@keys);
    if (@keys >= 1 && $verbose >= 1){
	say "Deleted files:";
	foreach my $hash (@keys){
	    say "\t", $Files_old{$hash}->filename;
	}
    }

    if ($files_new + $files_rename + $files_delete + $files_change > 0){
	save_dir_oop_db(dir => $dir_check, Files_ref => \%Files);

	print "Dir: $dir_check " if ($verbose <= 1);
	say "File Changes: New: $files_new Rename: $files_rename Changed: $files_change Deleted: $files_delete";
    }

    return %Files;
}


#
# Debug - print list files
# 
sub print_list_Files {
    my $Files_ref = shift(@_);;

    foreach  (keys %{$Files_ref}){
	my $File = $$Files_ref{$_};
	say "MD5: ", $File->md5 // "X" x 32, " inode: ", $File->inode, " File:", $File->filename;
    }
}

#
# Function: Load a md5 oop datafile
# 
# Add rename old one after store
use Storable;

sub save_dir_oop_db {
    my %opt = @_;

    my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_oop_db";
    my $Files_ref = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_dir_oop_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $dbfile = "$dir/.moo.obj.db";

    store($Files_ref, $dbfile);

    return;
}

sub save_tree_oop_db {
    my %opt = @_;

    my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_oop_db";
    my $Files_ref = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_tree_oop_md5";
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $dbfile = "$dir/.moo.obj.tree.db";

    store($Files_ref, $dbfile);

    return;
}



sub load_dir_oop_db {
    my %opt = @_;

    my $dir =  delete $opt{dir} or die "Missing param 'dir' to load_dir_oop_db";
    die "Unknown params:", join ", ", keys %opt if %opt;
    my $Files_ref = { };

    my $dbfile_mtime = 0;
    my $dbfile = "$dir/.moo.obj.db";

    if (-e $dbfile) {
	$Files_ref = retrieve($dbfile);
	say "Loaded ", scalar(keys %{$Files_ref}), " records" if ($verbose >= 2);
	$dbfile_mtime = (stat(_))[9];
    }

    return ($Files_ref, $dbfile_mtime);
}
