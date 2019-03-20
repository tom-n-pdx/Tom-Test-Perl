#!/usr/bin/env perl
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
use Number::Bytes::Human qw(format_bytes);
use List::Util qw(min max);	        # Import min()


our $verbose = 2;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";

my %size;
my $Files; 

my @names;
my %disk = (Video_4 => 0, Video_6 => 0, Video_7 => 0, Video_8 => 0, Video_10 => 0, 
	    Video_11 => 0, Video_12 => 0, Video_13 => 0, NewBoot => 0, "/Users/tshott" => 0);

# $Files = dbfile_load_md5(dir => $data_dir, name => "ebook.moo.db");
$Files = NodeTree->load(dir => $data_dir, name => "files.moo.db");


say "All Files Total Records Loaded: ", $Files->count;


# Load books to check into new tree

my @size;
foreach my $size (sort {$b <=> $a} keys %{$Files->size_HoA}){
    my @Dupes = @{ %{$Files->size_HoA}{$size} }; 
    next unless (@Dupes >= 2);
    push(@size, $size);
}

say "Found ", scalar(@size), " dupes";

@size = sort( {$b <=> $a} @size);
@size = grep( {$_ >= (100 * 1e6)} @size); # Filter bigger then 200 Meg

my @filter;
foreach (@size){
    my @Dupes = @{ %{$Files->size_HoA}{$_} }; 
    foreach my $Node (@Dupes){
	for my $disk (keys %disk){
	    $disk{$disk} += $_ if $Node->path =~ /$disk/;
	}

	if ($Node->path =~ /Video_13/i){
	    push(@filter, $_);
	}
	
    }
}
# @filter = @size;


@filter = @filter[0..min(20, $#filter)];

foreach (@filter){
    say " ";
    my $str = format_bytes($_);
    say "Size $str";
    my @Dupes = @{ %{$Files->size_HoA}{$_} }; 
    foreach my $Node (@Dupes){
	say "    ", $Node->filename;
	say "      ", $Node->path;
	say "      ", $Node->size;
	say "      ", $Node->md5 // " ";
    }
}

say "Totals: ";
foreach (sort {$disk{$b} <=> $disk{$a} } keys %disk){
    say "    $_ ", format_bytes($disk{$_}); 
}

# foreach (@names){
#     next if -d;
#     say "Check: $_" if ($verbose >= 3);

#     my $Node = MooFile->new(filepath => "$book_dir/$_", update_md5 => 0);

#     # Search by size
#     my @Dupes = $Files->Search(size => $Node->size);
#     @Dupes = grep( {$_->filepath ne $Node->filepath} @Dupes);

#     next if (! @Dupes);

#     say "File: $_";
#     foreach my $Dupe (@Dupes){
# 	say "    Dupe Size: ", $Dupe->filename;
# 	say "               ", $Dupe->path;
	
#     }
#     say " ";

# }
