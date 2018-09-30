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
#$test_file = "$ebook_base_dir/_Zeppelins_testing/[New Vanguard 101] Charles Stephenson - Zeppelins_ German Airships 1900 - 40 (2004, Osprey Publishing Ltd).pdf";
#$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin.jpg";
#$test_file = "$ebook_base_dir/_Zeppelins/The Zeppelin-BAD.jpg";
$test_file = "$ebook_base_dir/_Zeppelins_testing/Airship technology_test.gif";   # no read access
# $test_file = $ebook_base_dir;

my $test = MooFile->new(filepath => $test_file, 'opt_update_md5' => 1);
# my $test = MooFile->new($test_file); # Use short version no opts
#my $test = MooFile->new('FileName' => $test_file);
# my $test = MooFile->new;

my $size = $test->size || "undefined";
say "File: ", $test->filepath, " size: ", $size, " mtime: ", $test->mtime_str;

# Check stats array
say "Stats: ", join(', ',  @{$test->stat});

# Check Dump
# say "Dump:";
#$test->dump;

say "Dump:";
$test->dump_raw;

say "Update Stats";
$test->update_stat;
$test->dump_raw;

die;

#
# Check the iseqal & ischanged options
#
my $test_file_dupe = "$ebook_base_dir/_Zeppelins_testing/[New Vanguard 101] Charles Stephenson - Zeppelins_ German Airships (2004,Osprey Publishing Ltd) copy.pdf";
my $test_dupe = MooFile->new(filepath => $test_file_dupe);

my @changes;
my  @changes = $test->isequal($test_dupe);
print "isequal Delta File self to renamed copy of file: ", join(', ', @changes), "\n";

my  @changes = $test->ischanged($test_dupe);
print "ischanged Delta File self to renamed copy of file: ", join(', ', @changes), "\n";

@changes = $test->isdiskchanged($test);
print "isdiskchanged Delta File: ", join(', ', @changes), "\n";

# Fake change by point at differemt file  by change filename of $test
$test->_set_filepath($test_file_dupe);
@changes = $test->isdiskchanged($test);
print "isdiskchanged fake other file Delta File: ", join(', ', @changes), "\n";

# fake deleet by point at non exist file
$test->_set_filepath("$ebook_base_dir/_Zeppelins/The Zeppelin-BAD.jpg");
@changes = $test->isdiskchanged($test);
print "isdiskchanged fake other file Delta File: ", join(', ', @changes), "\n";


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

foreach (@filepaths){

    # skip system files, directories, unreadable or not a normal file
    next if -d;
    next if !-f || !-r;

    my $obj =MooFile->new(filepath => $_);;
    push(@files, $obj);
}

# foreach (@files){
#    say $_->filename;
#}


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


#
# Check dupe md5
#
# Lookup size and push onto array at that size
undef(%hash);

foreach (@files){
    push(@{ $hash{$_->md5}}, $_);
}

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



