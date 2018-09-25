#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

#
# ToDo - expand ~ in dir path
#

use Number::Bytes::Human qw(format_bytes);
use List::Util qw[min];	# Import min()
use Data::Dumper;           # Debug print
use Storable qw(retrieve);


# My Modules
use lib '.';
use Ebook_Files ;

#
# Main
#

my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins";
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_ships";
#my $test1_dir = "/Users/tshott/Downloads/_ebook";
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_bob";               # Fail
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology_test.gif";               # Fail
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology.gif";               # Fail

# Store objs via storable into file in dir
my @files;
my $obj_store_file = $test1_dir."/.ebook_files.dbj";
@files = @{ retrieve($obj_store_file) };

# say "Data Dump retrieved Obj";
#print Dumper(@files);

# die;

#
# Test Print Info 
#
my $end = min(9, scalar(@files));

say "\n\nDebug Print";
foreach (@files[0..$end]){

    my($basename, $path, $ext) = $_->fileparse();

    # print "$basename ", $_->size, "\n";
    my $size = format_bytes($_->size);
    # print "$size\t$basename\n";
    printf "%5s %s\n", $size, $basename;
}

say "Data Dump #4";
print Dumper($files[4]);
