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



#
# Todo
# * add --help option
# * move collect dupes, into seperate sub
# * merge ave tree & save dir into one sub
# * write check dupes sub
# * write update file sub


# dupes
# * problem is when first dupe in seperate dir from 2nd dupe - need to redo first dir
# * worse - dupes in seperate trees


my %Files;
my %size_count;
my %size_dir;

my ($files_new, $files_rename, $files_delete, $files_change) = (0, 0, 0, 0);


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

my $Tree = NodeTree->new();

my $Dir1;
$Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads/_ebook/_temp");
#$Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads/_ebook");
# $Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads");


my $File1  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Yoga Fitness for Men- Build Strength, Improve Performance, Increase Flexibility (ebook, Pohlman, DK, 2018, Orginal).pdf", opt_update_md5 => 0);
my $File1_Copy  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Yoga Fitness for Men- Build Strength, Improve Performance, Increase Flexibility (ebook, Pohlman, DK, 2018, Orginal).pdf");
my $File2  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/War in space- the science and technology behind our next theater of conflict (Springer-Praxis books in space exploration.) (ebook, Dawson, Springer, 2019, Orginal).pdf");
my $File3  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Yoga Fitness for Men- Build Strength, Improve Performance, Increase Flexibility (ebook, Pohlman, DK, 2018, Orginal) copy.pdf");


$Tree->insert($Dir1);
#$Tree->remove($Dir1->hash);
#say Dumper($Tree);


$Tree->insert($File1);
# $Tree->insert($File1_Copy);
$Tree->insert($File2);
$Tree->insert($File3);
say "Count: ", $Tree->count;
say Dumper($Tree);


$Tree->remove($File1->hash);
# say Dumper($Tree);
# $Tree->remove($File1->hash);
$Tree->remove($File2->hash);
$Tree->remove($File3->hash);

$Tree->remove($Dir1->hash);
say "Count: ", $Tree->count;
say Dumper($Tree);
exit;

# test find dupe size
my @files;
foreach my $key (sort keys %{$Tree->size_HoA} ){
    my $temp_ref = ${$Tree->size_HoA}{$key}; 
    # @{ $$HoA_ref{$hash} } 
    say "Size: $key Count: ", scalar(@$temp_ref);

    if (scalar(@$temp_ref) >= 2){
	foreach (@$temp_ref){
	    # my $File = ${$Tree->nodes}{$_};
	    # say "   ", $File->filename;
	    say "   ", $_->filename;
	}
    }
}

exit;

#my $Temp;
#$Temp = $Tree->remove(15);
#say "Remove Bad ", $Temp // "Undef";;

#$Temp = $Tree->remove($Dir1);
#$Temp = $Tree->remove($File2);

#say "Remove 2 ", $Temp // "undef";

#$temp = $Tree->remove($File1->hash);
 
# say "Count: ", $Tree->count;

# say Dumper($Tree);



# Use simple queue?
my @Dirs_new;
my @Files_new;
# my @Dirs_done;
my $Tree_done = NodeTree->new();







exit;

# Initially file list of unprocessed dirs with top of tree
push(@Dirs_new, $Dir1);

# Now, as long as their are dirs in @Dir_new, keep processng
while(my $Node = shift(@Dirs_new)){

    # Add Node to done list
    $Tree_done->insert($Node);

    # next if (! $Node->isdir);

    # Get list of files in dir and add to processing list
    my @Nodes = $Node->List;
    
    foreach my $Node (@Nodes){
	if ($Node->isdir){
	    push(@Dirs_new, $Node);
	} elsif ($Node->isfile){
	    $Tree_done->insert($Node);
	} else {
	    warn "Unknown file type: ".$Node->filename;
	}
    }

}

#while (my $File  = $Tree_done->pop){
    # say "Name: ", $File->filename;
#}

foreach ($Tree_done->List){
    say "Name: ", $_->filename;
}

exit;


# #$Tree->insert(($File1, $File2));
# $Tree->insert($File2);
# $Tree->insert($File3);
# $Tree->insert($File1_Copy);
# #

my $Temp;
#$Temp = $Tree->remove(15);
#say "Remove Bad ", $Temp // "Undef";;

#$Temp = $Tree->remove($Dir1);
#$Temp = $Tree->remove($File2);

#say "Remove 2 ", $Temp // "undef";

#$temp = $Tree->remove($File1->hash);
 
say "Count: ", $Tree->count;

# say Dumper($Tree);

while (my $File  = $Tree->pop){
    say "Name: ", $File->filename;
}

#$Tree->remove($Dir1);
#$Tree->insert(($File1, $File2));
#$Tree->insert($File1_Copy);
$Tree->remove($File2->hash);
#$Tree->insert($File3);



# sub wanted {
#     return if (!-d $File::Find::name);           # if not dir, skip

#     my  $dir = $File::Find::name;
#     return if ($dir =~ m!/\.!);                    # Hack, can't get prune to work

#     my %Files_new = update_dir_oop(dir=>$dir, fast_scan=>$fast_scan);

#     # Add dupe size check
#     %Files = (%Files, %Files_new);

#    return;
# }



# #
# # Scan a dir and calc md5 values. As part of scan will check if dir valid, and load and save a md5 db file
# # * BUG - updates dir - but does not save
# sub update_dir_oop {
#     my %opt = @_;
#     my $fast_scan =  delete $opt{fast_scan} // 0;
#     my $dir_check =  delete $opt{dir} or die "Missing param to scan_dir_oop_md5";
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     say "\tFAST SCAN" if ($fast_scan && $verbose >= 2);
#     my %Files;
#     ($files_new, $files_rename, $files_delete, $files_change) = (0, 0, 0, 0);

#     if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
#     	warn "Bad Dir: $dir_check";
#     	return %Files;
#     }

#     say "Scanning $dir_check" if ($verbose >= 1);
#     my $Dir = MooDir->new(filepath => $dir_check);

#     my ($Files_old_ref, $db_mtime) = load_dir_oop_db(dir => $dir_check);
#     my %Files_old = %{$Files_old_ref};


#     # if ($db_mtime >= $Dir->dtime){
#     # 	say "No Files chaged, skip update" if ($verbose >= 2);
#     # 	return(%Files_old);
#     # }


#     my @filepaths = $Dir->list_filepaths();
#     say "Files: ", join(", ", @filepaths) if ($verbose >= 3);

#     # Scan through for all files in dir
#     foreach my $filepath (@filepaths) {
# 	my $File = update_file(filepath=>$filepath, Files_old_ref=>\%Files_old, fast_scan=>$fast_scan);
# 	my $hash = $File->hash;
# 	$Files{$hash} = $File;

# 	# Save every so often
# 	if ($files_change > 0 && $files_change % 100 == 0){
# 	    save_dir_oop_db(dir => $dir_check, Files_ref => \%Files);
# 	    say "Checkpoint Save File Changes: New: $files_new Rename: $files_rename Changed: $files_change Deleted: $files_delete";
# 	}
#     }


#     # Now Check if any old values left - file was deleted
#     my @keys = keys %Files_old;
#     $files_delete += scalar(@keys);
#     if (@keys >= 1 && $verbose >= 1){
# 	say "Deleted files:";
# 	foreach my $hash (@keys){
# 	    say "\t", $Files_old{$hash}->filename;
# 	}
#     }

#     if ($files_new + $files_rename + $files_delete + $files_change > 0){
# 	save_dir_oop_db(dir => $dir_check, Files_ref => \%Files);

# 	print "Dir: $dir_check " if ($verbose <= 1);
# 	say "File Changes: New: $files_new Rename: $files_rename Changed: $files_change Deleted: $files_delete";
#     }

#     return %Files;
# }


# #
# # Debug - print list files
# # * Merge tree and dir save
# sub print_list_Files {
#     my $Files_ref = shift(@_);;

#     foreach  (keys %{$Files_ref}){
# 	my $File = $$Files_ref{$_};
# 	say "MD5: ", $File->md5 // "X" x 32, " inode: ", $File->inode, " File:", $File->filename;
#     }
# }

# #
# # Function: Load a md5 oop datafile
# # 
# # Add rename old one after store
# use Storable;

# sub save_dir_oop_db {
#     my %opt = @_;

#     my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_oop_db";
#     my $Files_ref = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_dir_oop_md5";
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $dbfile = "$dir/.moo.obj.db";

#     store($Files_ref, $dbfile);

#     return;
# }

# sub save_tree_oop_db {
#     my %opt = @_;

#     my $dir =  delete $opt{dir} or die "Missing param 'dir' to save_dir_oop_db";
#     my $Files_ref = delete $opt{Files_ref} or die "Missing param 'Files_ref' to save_tree_oop_md5";
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $dbfile = "$dir/.moo.obj.tree.db";

#     store($Files_ref, $dbfile);
#     say "Saved ", scalar(keys %{$Files_ref}), " records" if ($verbose >= 2);

#     return;
# }



# sub load_dir_oop_db {
#     my %opt = @_;

#     my $dir =  delete $opt{dir} or die "Missing param 'dir' to load_dir_oop_db";
#     die "Unknown params:", join ", ", keys %opt if %opt;
#     my $Files_ref = { };

#     my $dbfile_mtime = 0;
#     my $dbfile = "$dir/.moo.obj.db";

#     if (-e $dbfile) {
# 	$Files_ref = retrieve($dbfile);
# 	say "Loaded ", scalar(keys %{$Files_ref}), " records" if ($verbose >= 2);
# 	$dbfile_mtime = (stat(_))[9];
#     }

#     return ($Files_ref, $dbfile_mtime);
# }
 
# sub update_file {
#     my %opt = @_;

#     my $filepath =  delete $opt{filepath} or die "Missing param 'filepath' to update_file";
#     my $Files_old_ref = delete $opt{Files_old_ref} or die "Missing param 'Files_old_ref' to update_file";
#     my $fast_scan =  delete $opt{fast_scan} // 0;
#     die "Unknown params:", join ", ", keys %opt if %opt;

#     my $File = MooFile->new(filepath => $filepath, opt_update_md5=>0);
#     my $hash = $File->inode;

#     my $File_old = $$Files_old_ref{$hash};
#     if (! defined $File_old) {
# 	# Assume if no old file with inode, must be new file
# 	say "New File: ", $File->filename if ($verbose >= 1);
# 	$files_new++;
#     } else {
# 	# If old file newer or same age, transfer md5
# 	if (defined $File_old->md5 && $File->size == $File_old->size && $File->mtime <= $File_old->mtime) {
# 	    $File->_set_md5($File_old->md5);
# 	}
# 	# Check if name changed
# 	if ($File->filename ne $File_old->filename) {
# 	    say "Rename: ", $File_old->filename, " to ", $File->filename if ($verbose >= 1);
# 	    $files_rename++;
# 	}
#     }

#     delete $$Files_old_ref{$hash};

#     $size_count{$File->size}++;

#     if ( !defined($File->md5) ){
# 	my $count = $size_count{$File->size};
# 	if ( !$fast_scan or $count >= 2) {	    
#	    print "Dupe Count: $count- " if ($count >=2);
# 	    say "Calc md5: ", $File->filename if ($verbose >= 2 or $count >= 2);

# 	    if ($File->isreadable){
# 		$File->update_md5;
# 		$files_change++;
# 	    }
# 	}
#     }
#     return ($File);
# }
