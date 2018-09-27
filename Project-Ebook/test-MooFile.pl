#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		# Implies strict, warnings
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
use MooFile;


my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $test_file;
$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin.jpg";
#$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin-BAD.jpg";
#$test_file = $ebook_base_dir;

my $test = MooFile->new('filepath' => $test_file, 'opt_update_stat'=>1);
#my $test = MooFile->new('FileName' => $test_file);
# my $test = MooFile->new;

my $size = $test->size || "undefined";
say "File: ", $test->filepath, " size: ", $size;

# Check stats array
if (defined $test->stats){
    say "Stats: ", join(', ',  @{$test->stats});
}

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

@filepaths = grep(!/^\./, @filepaths);	    # make into absoule path         
@filepaths = map($test_dir.'/'.$_, @filepaths);	    # make into absoule path         

my @files;

foreach (@filepaths){

    # skip system files, directories, unreadable or not a normal file
    next if -d;
    next if !-f || !-r;

    my $obj =MooFile->new('filepath' => $_);
    push(@files, $obj);
}

foreach (@files){
    say $_->filename;
}


#
# Loop for dupes by checking dup sizes
#
my %hash;

# Lookup size and push onto array at that size
foreach (@files){
    push(@{ $hash{$_->size}}, $_);
}

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


