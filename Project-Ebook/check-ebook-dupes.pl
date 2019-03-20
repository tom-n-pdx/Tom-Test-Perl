#!/usr/bin/env perl
#
# ToDo
# * Read dir to check
# * offer options to fix
# * include general fix?


use Modern::Perl; 		         # Implies strict, warnings
use autodie;
# use Getopt::Long;

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
use MooNode;

our $verbose = 2;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";

my %size;
# my $Ebook = NodeHeap->new;
my $Files; # = NodeTree->new;

my @names;


# $Files = dbfile_load_md5(dir => $data_dir, name => "ebook.moo.db");
$Files = NodeTree->load(dir => $data_dir, name => "ebook.moo.db");


say "Total Records Loaded: ", $Files->count;


# Load books to check into new tree
my $book_dir;
$book_dir = "/Users/tshott/Downloads/_ebook/_temp";

@names = dir_list(dir => $book_dir);

# @names = @names[0..5];

foreach (@names){
    next if -d;
    say "Check: $_" if ($verbose >= 3);

    my $Node = MooFile->new(filepath => "$book_dir/$_", update_md5 => 0);

    # Search by size
    my @Dupes = $Files->Search(size => $Node->size);
    @Dupes = grep( {$_->filepath ne $Node->filepath} @Dupes);

    next if (! @Dupes);

    say "File: $_";
    foreach my $Dupe (@Dupes){
	say "    Dupe Size: ", $Dupe->filename;
	say "               ", $Dupe->path;
	
    }
    say " ";

}
