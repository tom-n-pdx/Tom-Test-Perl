#!/usr/bin/env perl
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
our $verbose = 2;
our $fast_scan = 0;
our $tree=0;


GetOptions (
    'debug=i'      => \$debug,
    'verbose=i'    => \$verbose,
    'fast'         => \$fast_scan,
    'tree'         => \$tree,
);

if ($debug or $verbose >= 2){
    say "Options";

    say "\tDebug: ", $debug;
    say "\tVerbose: ", $verbose;
    say "\tFast: ", $fast_scan;
    say "\tTree: ", $tree;

    say " ";
}

my $Dir1;
# $Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads/_ebook/_test_Zeppelins");
$Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads/_ebook");
# $Dir1 = MooDir->new(filepath => "/Users/tshott/Downloads");

my $dir1;
$dir1 = "/Users/tshott/Downloads/_ebook/_temp";
# $dir1 = "/Users/tshott/Downloads/_ebook";
# $dir1 = "/Users/tshott/Downloads";

my $Tree; # = NodeTree->new();

# $Tree = NodeTree->load(dir => $dir1, name => ".moo.db");
$Tree = NodeHeap->load(dir => $dir1, name => ".moo.db");

say "Standard Restore";
$Tree->summerize;

my $Heap = NodeHeap->new();

for my $Node ($Tree->List){
    $Heap->insert($Node);
}

say "Heap Summerize";
$Tree->summerize;


# $Tree = NodeTree->load_packed(dir => $dir1, name => ".moo.tree.dbp");
# say "Packed Restore";
# $Tree->summerize;

$Heap->save(dir => $dir1, name => ".moo.db");

exit;



# say $Dir1;
# say $Dir1->dump;


my $File1  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_test_Zeppelins/Airship ( technology )_test1.gif", update_md5 => 0);
my $File2  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_test_Zeppelins/Airship technology )_test2.gif");
my $File3  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/Ultimate Origami for Beginners (ebook, LaFosse, Tuttle Publishing, 2014, Orginal).pdf");


# say $File1->filename;

$Tree -> insert($Dir1);
$Tree -> insert($File1);
$Tree -> insert($File2);

say "Count in Tree after 3 insert: ", $Tree->count;

say "Files in Tree: ", join(" , ", map($_->filepath, $Tree->List));
say "Paths in Tree: ", join(" , ", map($_->path,     $Tree->List));


my @Nodes;
# @Nodes = $Tree->Search(path => "/Users/tshott/Downloads/_ebook/_test_Zeppelins");
@Nodes = $Tree->Search(path => "/Users/tshott");
# @Nodes = $Tree->Search(dir => 1, file => 1);
say "Found Match Path: ", scalar(@Nodes);

# my @Nodes;
say "Dir: ", $Dir1->filepath;
say "Files in Dir: ";
@Nodes = $Tree->Search(path => $Dir1->filepath);
say "Found Match Path: ", join(" , ", map($_->filepath, @Nodes));


# my @Nodes = $Tree->Search(hash => $Dir1->hash, verbose => 3);
# my @Nodes = $Tree->Search(dir => 1, verbose => 3);
# say "Found Dirs: ", scalar(@Nodes);

# my @Nodes = $Tree->Search(file => 1, verbose => 3);
# say "Found Files: ", scalar(@Nodes);

# Check error in search options
# my @Nodes = $Tree->Search(verbose => 3);
# say "Found Error: ", scalar(@Nodes);



# @Nodes = $Tree->Search(hash => 17, verbose => 3);
# say "Found: ", scalar(@Nodes);

# @Nodes = $Tree->Search(file => 1, verbose => 3);
# say "Found: ", scalar(@Nodes);

# @Nodes = $Tree->Delete(@Nodes);
# say "Deleted: ", scalar(@Nodes);


# # $Tree -> Delete($File1->hash);
# say "Count in Tree after delete files: ", $Tree->count;



exit;

# $Tree -> Delete(17);

# $Tree -> Delete($File2);

# say "Count in Tree after 2 delete: ", $Tree->count;

# exit;


# use Fcntl qw(:mode);

# my @ftypes;
# $ftypes[S_IFDIR] = "dir";
# $ftypes[S_IFCHR] = "c";
# $ftypes[S_IFBLK] = "b";
# $ftypes[S_IFREG] = "file";
# $ftypes[S_IFIFO] = "p";
# $ftypes[S_IFLNK] = "l";
# $ftypes[S_IFSOCK] = "s";

# say "S_IFDIR = ", S_IFDIR;
# my $filetype = S_IFMT( @{$File1->stat}[2] );
# my $ftype = $ftypes[$filetype];


# say "Filetype: $ftype ($filetype)";









# Fcntl
# $filetype = $ftypes[($mode & 0170000)>>12];
# S_IFMT     0170000   bitmask for the file type bitfields
# S_IFSOCK   0140000   socket
# S_IFLNK    0120000   symbolic link
# S_IFREG    0100000   regular file
# S_IFBLK    0060000   block device
# S_IFDIR    0040000   directory
# S_IFCHR    0020000   character device
# S_IFIFO    0010000   fifo
# printf "Permissions are %04o\n", $mode & 07777;

# say $File1->dump;





# exit;


#$Tree->insert($Dir1);
#$Tree->remove($Dir1->hash);
#say Dumper($Tree);


# $Tree->insert($File1);
# # $Tree->insert($File1_Copy);
# $Tree->insert($File2);
# $Tree->insert($File3);
# say "Count: ", $Tree->count;
# say Dumper($Tree);


# $Tree->remove($File1->hash);
# # say Dumper($Tree);
# # $Tree->remove($File1->hash);
# $Tree->remove($File2->hash);
# $Tree->remove($File3->hash);

# $Tree->remove($Dir1->hash);
# say "Count: ", $Tree->count;
# say Dumper($Tree);
exit;

# test find dupe size
# my @files;
# foreach my $key (sort keys %{$Tree->size_HoA} ){
#     my $temp_ref = ${$Tree->size_HoA}{$key}; 
#     # @{ $$HoA_ref{$hash} } 
#     say "Size: $key Count: ", scalar(@$temp_ref);

#     if (scalar(@$temp_ref) >= 2){
# 	foreach (@$temp_ref){
# 	    # my $File = ${$Tree->nodes}{$_};
# 	    # say "   ", $File->filename;
# 	    say "   ", $_->filename;
# 	}
#     }
# }

# exit;

#my $Temp;
#$Temp = $Tree->remove(15);
#say "Remove Bad ", $Temp // "Undef";;

#$Temp = $Tree->remove($Dir1);
#$Temp = $Tree->remove($File2);

#say "Remove 2 ", $Temp // "undef";

#$temp = $Tree->remove($File1->hash);
 
# say "Count: ", $Tree->count;

# say Dumper($Tree);



# # Initially file list of unprocessed dirs with top of tree
# push(@Dirs_new, $Dir1);

# # Now, as long as their are dirs in @Dir_new, keep processng
# while(my $Node = shift(@Dirs_new)){

#     # Add Node to done list
#     $Tree_done->insert($Node);

#     # next if (! $Node->isdir);

#     # Get list of files in dir and add to processing list
#     my @Nodes = $Node->List;
    
#     foreach my $Node (@Nodes){
# 	if ($Node->isdir){
# 	    push(@Dirs_new, $Node);
# 	} elsif ($Node->isfile){
# 	    $Tree_done->insert($Node);
# 	} else {
# 	    warn "Unknown file type: ".$Node->filename;
# 	}
#     }

# }

# #while (my $File  = $Tree_done->pop){
#     # say "Name: ", $File->filename;
# #}

# foreach ($Tree_done->List){
#     say "Name: ", $_->filename;
# }

exit;


# #$Tree->insert(($File1, $File2));
# $Tree->insert($File2);
# $Tree->insert($File3);
# $Tree->insert($File1_Copy);
# #

# my $Temp;
# #$Temp = $Tree->remove(15);
# #say "Remove Bad ", $Temp // "Undef";;

# #$Temp = $Tree->remove($Dir1);
# #$Temp = $Tree->remove($File2);

# #say "Remove 2 ", $Temp // "undef";

# #$temp = $Tree->remove($File1->hash);
 
# say "Count: ", $Tree->count;

# # say Dumper($Tree);

# while (my $File  = $Tree->pop){
#     say "Name: ", $File->filename;
# }

# #$Tree->remove($Dir1);
# #$Tree->insert(($File1, $File2));
# #$Tree->insert($File1_Copy);
# $Tree->remove($File2->hash);
# #$Tree->insert($File3);

