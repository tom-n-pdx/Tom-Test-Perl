#!/usr/bin/env perl
#

#
# Update Dupes and other standard datfiles
#

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

# Store as Heap - but later will load into Tree
# my $Files = NodeHeap->new;
# my $Ebook = NodeHeap->new;

my $Files = NodeTree->new;
my $Ebook = NodeTree->new;

my @names = dir_list(dir => $data_dir);

my %ebook_ext = (".pdf" => 1, ".chm" => 1, ".epub" => 1, ".mobi" => 1, ".djvu" => 1, ".azw3" => 1);
my $count_total = 0;

foreach (@names){
    next unless /\.tree\.moo\.db$/;

    say " ";

    my $Tree = dbfile_load_md5(dir => $data_dir, name => $_);

    my $count = $Tree->count;
    $count_total += $count;
    say "Datafile: $_ Loaded $count records";

    foreach my $Node ($Tree->List){
	next unless $Node->isfile;
	$size{$Node->size}++;

	if (! $Files->Exist(hash => $Node->hash)){
	    $Files->insert($Node);

	    # Add to book list
	    if ($Node->basename =~ /\(ebook/i || $ebook_ext{lc($Node->ext)} // 0){ # || $Node->path =~ /ebook/i ){
		$Ebook->insert($Node);
	    }
	}
    }
}

say " ";
say "Total Records: $count_total";

&save_dupes(dupes => \%size); 

# Save Ebooks
say "Saving ", $Ebook->count, " Ebook Records";
dbfile_save_md5(List => $Ebook, dir => $data_dir, name => "ebook.moo.db");

# Save Files
say "Saving ", $Files->count, " All Files Records";
dbfile_save_md5(List => $Files, dir => $data_dir, name => "files.moo.db");
