#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		         # Implies strict, warnings
use autodie;			        # Easier write open  /close code

#
# ToDo - expand ~ in dir path
#

# use Number::Bytes::Human qw(format_bytes);
# use List::Util qw(min);	# Import min()
use Data::Dumper;           # Debug print

# use Storable qw(nstore_fd);
# use Fcntl qw(:DEFAULT :flock);


# My Modules
use lib '.';
use NodeCollection;
use MooFile;

my $test_collection = NodeCollection->new;
#say Dumper($test_collection);

my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $test_file;
$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin.jpg";


#$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin-BAD.jpg";
#$test_file = $ebook_base_dir;

my $test2 = MooFile->new('filepath' => $test_file, 'update_md5' => 0);
#my $test = MooFile->new('filepath' => $test_file);
#my $test = MooFile->new('FileName' => $test_file);
# my $test = MooFile->new;

# my $size = $test->size || "undefined";
# say "File: ", $test->filepath, " size: ", $size;

# Check stats array
# if (defined $test->stats){
#     say "Stats: ", join(', ',  @{$test->stats});
# }

# Check Dump
#say "Dump:";
#$test->dump;

# say "Dump:";
#$test->dump_raw;

$test_collection->push($test2);
#say Dumper($test_collection);



#
# OK - try scanning dir & print size of files
#

my $test_dir;
$test_dir = "$ebook_base_dir/_Zeppelins_testing";
# $test_dir = "$ebook_base_dir";


# Open dir & Scan Files
opendir(my $dh, $test_dir);
my @filepaths = readdir $dh;
closedir $dh;

@filepaths = grep(!/^\./, @filepaths);	                    # remove dot files         
@filepaths = map($test_dir.'/'.$_, @filepaths);	    # make into absoule path         

my @files;

foreach (@filepaths[0..3]){

    # skip system files, directories, unreadable or not a normal file
    next if -d;
    next if !-f || !-r;

    my $obj =MooFile->new('filepath' => $_);
    $test_collection->push($obj);
}


#@files = @{$test_collection->files};

while ($_ = $test_collection->pop){
    say $_->filename;
}

my @keys = keys %{$test_collection->size_hash};
foreach (@keys){
    say "Key: $_ Length: ", 
say "keys left: ", join(", ", @keys);


foreach my $size  (sort keys %{$test_collection->size_hash}{
    my @values = @{ %{$test_collection->size_hash{$size}}};
    if ($#values > 0){
	say "Dupe files size: $size";
	foreach (@values) {
	    say "\t", $_->filename;
	}
    }
}

# $test_collection->dup_size;

#say Dumper($test_collection);
die;


#
# Loop for dupes by checking dup sizes
#
my %hash;

# # Lookup size and push onto array at that size
# foreach (@files){
#     push(@{ $hash{$_->size}}, $_);
# }

# Now  -walk hash  -find which values have a array > 0 length  -those are dupe sizes
foreach my $size  (sort keys %hash){
    my @values = @{ $hash{$size} };
    if ($#values > 0){
	say "Dupe files size: $size";
	foreach (@values) {
	    say "\t", $_->filename;
	}
    }
}


#
# Check dupe md5
#
# Lookup size and push onto array at that size
# undef(%hash);

# foreach (@files){
#     push(@{ $hash{$_->md5}}, $_);
# }

# Now  -walk hash  -find which values have a array > 0 length  -those are dupe sizes
foreach my $md5  (sort keys %hash){
    my @values = @{ $hash{$md5} };
    if ($#values > 0){
	say "Dupe files md5: $md5";
	foreach (@values) {
	    say "\t", $_->filename;
	}
    }
}



