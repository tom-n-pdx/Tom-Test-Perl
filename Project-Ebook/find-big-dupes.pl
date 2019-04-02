#!/usr/bin/env perl -CA
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
my $interactive = 1;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";

my %size;
my $Files; 

my @names;
my %disk = (MyBook => 0, Video_6 => 0, Video_7 => 0, Video_8 => 0, Video_10 => 0, 
	    Video_11 => 0, Video_12 => 0, Video_13 => 0, NewBoot => 0, "/" => 0);
# my %disk;

# $Files = dbfile_load_md5(dir => $data_dir, name => "ebook.moo.db");
$Files = NodeTree->load(dir => $data_dir, name => "dupes.moo.db");


say "All Files Total Records Loaded: ", $Files->count;

# First Sum how many and how big non-md5 on each volume
my (%volume_size, %volume_i);


foreach my $Node ($Files->List){
    next if (defined $Node->md5 || ! $Node->isreadable);

    my $volume = $Node->volume;
    $volume_i{$volume}++;
    $volume_size{$volume} += $Node->size;
}

say "\nNo MD5 Files";
foreach my $volume (sort { $volume_i{$b} <=> $volume_i{$a} } keys %volume_i){
    say "$volume Size: ", format_bytes($volume_size{$volume}), " N: $volume_i{$volume}";
}


# my @size;
# foreach my $size (sort {$b <=> $a} keys %{$Files->size_HoA}){
#     my @Dupes = @{ %{$Files->size_HoA}{$size} }; 
#     next unless (@Dupes >= 2);
#     push(@size, $size);
# }

# say "\nFound ", scalar(@size), " dupes";

# @size = sort( {$b <=> $a} @size);
# # @size = grep( {$_ >= (50 * 1e6)} @size); # Filter bigger then 200 Meg

# my @filter;
# foreach (@size){
#     my @Dupes = @{ %{$Files->size_HoA}{$_} }; 
#     foreach my $Node (@Dupes){
# 	for my $disk (keys %disk){
# 	    $disk{$disk} += $_ if $Node->path =~ /$disk/;
# 	}

# 	if ($Node->path =~ m!/Users/tshott!i){
# 	    push(@filter, $_);
# 	}
	
#     }
# }
# # @filter = @size;


# @filter = @filter[0..min(20, $#filter)];

sub size_md5 {
    my $md5 = shift(@_);
    my @Dupes = @{ %{$Files->md5_HoA}{$md5} }; 
    my $size = $Dupes[0]->size;
}


my @md5s;
my @filter;

foreach my $md5 (keys %{$Files->md5_HoA}){
    my @Dupes = @{ %{$Files->md5_HoA}{$md5} }; 
    next unless (@Dupes >= 2);
    my $save = 0;
    
    push(@md5s, $md5);
    foreach my $Node (@Dupes){
	$disk{$Node->volume} += $Node->size;

	# if ($Node->volume eq 'Video_8') {
	# if ($Node->isexist){
	    $save = 1;
	    #    }
	    # }

	# }
	push (@filter, $md5) if ($save);
    }
}
say "\nFound ", scalar(@md5s), " md5 dupes";


@filter = sort {size_md5($b) <=> size_md5($a)} @filter;
@filter = @filter[0..min(30, $#filter)];


say "\nmd5 dupes:";
foreach (@filter){
    say " ";
    my @Dupes = @{ %{$Files->md5_HoA}{$_} }; 
    # my $size = $Dupes[0]->size;
    my $size = size_md5($_);
    my $str = format_bytes($size);
    say "Size $str";
    foreach my $Node (@Dupes){
	say "    ", $Node->filename;
	say "      ", $Node->filepath;
	say "      ", $Node->volume;
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
