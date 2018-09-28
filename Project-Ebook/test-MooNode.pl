#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

#
# ToDo - expand ~ in dir path
# * prerry print info - 1 line, multuple lines
#

# use Number::Bytes::Human qw(format_bytes);
# use List::Util qw(min);	# Import min()
use Data::Dumper;           # Debug print

# use Storable qw(nstore_fd);
# use Fcntl qw(:DEFAULT :flock);


# My Modules
use lib '.';
use MooNode;
use MooFile;


my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $test_file;
#$test_file = "$ebook_base_dir/_Zeppelins_testing/[New Vanguard 101] Charles Stephenson - Zeppelins_ German Airships 1900 - 40 (2004, Osprey Publishing Ltd).pdf";
$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin-BAD.jpg";
# $test_file = $ebook_base_dir;

my $test = MooNode->new(filepath => $test_file);

my $size = $test->size;
say "File: ", $test->filepath, " size: ", $size;
say "Stats: ", join(', ',  @{$test->stats});

# $test->dump_raw;

# say Dumper($test);


my $test_file_dupe = "$ebook_base_dir/_Zeppelins_testing/[New Vanguard 101] Charles Stephenson - Zeppelins_ German Airships (2004,Osprey Publishing Ltd) copy.pdf";
my $test_dupe = MooNode->new(filepath => $test_file_dupe);

my @changes;

@changes = $test->isequal($test_dupe);
print "isequal Delta File self to renamed copy of file: ", join(', ', @changes), "\n";

@changes = $test->isdiskchanged($test);
print "isdiskchanged Delta File: ", join(', ', @changes), "\n";

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

@filepaths = map($test_dir.'/'.$_, @filepaths);	    # make into absoule paths         

my @files;
foreach (@filepaths){
    my $obj =MooNode->new(filepath => $_);
    push(@files, $obj);
}

foreach (@files){
    my $dir = $_->isdir ? "Dir" : "No ";
    say $_->size, " - $dir - ", $_->filename;
}


#
# Loop for dupes by checking dup sizes
#
my %hash;

# Lookup size and push onto array at that size
foreach (@files){
    push(@{ $hash{$_->size}}, $_);
}

# Now  -walk hash  -find which values have a array > 0 length - those are dupe sizes
foreach my $size  (sort keys %hash){
    my @values = @{ $hash{$size} };
    if ($#values > 0){
	say "\nDupe files size: $size";
	foreach (@values) {
	    say "\t", $_->filename;
	}
    }
}


