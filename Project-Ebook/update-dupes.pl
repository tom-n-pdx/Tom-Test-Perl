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


#
# Performace
# 
# 23.687u 1.543s 0:25.95 97.1%	0+0k 0+322io 1pf+0w     start, dumb load, dumb insert
# 19.159u 1.398s 0:21.03 97.6%	0+0k 0+693io 0pf+0w     merge both all and ebook
# 20.939u 1.233s 0:22.65 97.8%	0+0k 0+490io 0pf+0w     use each to process nodes


our $verbose = 0;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";

my %size;

# Store as Heap - but later will load into Tree
# my $Files = NodeHeap->new;
# my $Ebook = NodeHeap->new;

my $Files = NodeHeap->new;
my $Ebook = NodeHeap->new;

my @names = dir_list(dir => $data_dir);

my %ebook_ext = (".pdf" => 1, ".chm" => 1, ".epub" => 1, ".mobi" => 1, ".djvu" => 1, ".azw3" => 1);
my $count_total = 0;

foreach (@names){
    next unless /\.tree\.moo\.db$/;

    my $Tree = dbfile_load_md5(dir => $data_dir, name => $_);

    my $count = $Tree->count;
    $count_total += $count;
    say "Datafile: $_ Loaded $count records";

    while (my $Node = $Tree->Each){
	next unless $Node->isfile;

	$size{$Node->size}++;
	$Files->merge($Node);

	# Add to book list
	if ($Node->basename =~ /\(ebook/i || $ebook_ext{lc($Node->ext)} // 0){ # || $Node->path =~ /ebook/i ){
	    $Ebook->merge($Node);
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
