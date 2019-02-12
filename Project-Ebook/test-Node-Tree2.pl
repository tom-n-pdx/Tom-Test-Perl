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

# say $Dir1;
# say $Dir1->dump;

# exit;


my $File1  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Money 5,000 Years of Debt and Power (ebook, Aglietta, Verso Books, 2018, Orginal).epub", opt_update_md5 => 0);
# my $File1_Copy  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Yoga Fitness for Men- Build Strength, Improve Performance, Increase Flexibility (ebook, Pohlman, DK, 2018, Orginal).pdf");
# my $File2  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/War in space- the science and technology behind our next theater of conflict (Springer-Praxis books in space exploration.) (ebook, Dawson, Springer, 2019, Orginal).pdf");
# my $File3  =  MooFile->new(filepath => "/Users/tshott/Downloads/_ebook/_temp/Yoga Fitness for Men- Build Strength, Improve Performance, Increase Flexibility (ebook, Pohlman, DK, 2018, Orginal) copy.pdf");


say $File1->filename;

use Fcntl qw(:mode);

my @ftypes;
$ftypes[S_IFDIR] = "dir";
$ftypes[S_IFCHR] = "c";
$ftypes[S_IFBLK] = "b";
$ftypes[S_IFREG] = "file";
$ftypes[S_IFIFO] = "p";
$ftypes[S_IFLNK] = "l";
$ftypes[S_IFSOCK] = "s";

say "S_IFDIR = ", S_IFDIR;
my $filetype = S_IFMT( @{$File1->stat}[2] );
my $ftype = $ftypes[$filetype];


say "Filetype: $ftype ($filetype)";









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

say $File1->dump;





exit;


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

