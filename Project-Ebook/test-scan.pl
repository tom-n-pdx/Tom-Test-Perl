#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

#
# ToDo - expand ~ in dir path
#

#use 5.016; # implies "use strict;" 
#use warnings;
use Number::Bytes::Human qw(format_bytes);
use List::Util qw[min];	# Import min()
use Data::Dumper;           # Debug print


# My Modules
use lib '.';
use Ebook_Files ;


sub files_scan_dir {
    my ($dir_path, @args) = @_;
    my @files;
    
    # Open dir & Scan Files
    opendir(my $dh, $dir_path);
    while (readdir $dh) {

	# Skip system files
	next if /^\./;
	my $file_path = "$dir_path/$_";

	# skip non stanard files including dirs
	# next if -d $file_path;

	if (!-f $file_path && !-d $file_path) {
	    warn "SKIP non-standard file $file_path\n";
	   next;
	}

	if (! -r $file_path){
	    warn "WARN: Can't open file $file_path\n";
	    next;
	}

	# Create File Object
	my $obj = Ebook_Files->new("filepath" => $file_path, "calc-md5"=> 1);
	push(@files, $obj);

    }
    closedir $dh;

    return @files;
}

#
# Main
#

my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins";
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_ships";
#my $test1_dir = "/Users/tshott/Downloads/_ebook";
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_bob";               # Fail
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology_test.gif";               # Fail
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology.gif";               # Fail

my @files = files_scan_dir($test1_dir);

# How many of each size found

if (0){
    my %count_md5;

    for (@files) {
	my $md5 = $_->md5;
	$count_md5{$md5}++;
    }

    my @md5_dups = grep( $count_md5{$_} > 1 , keys %count_md5);

    foreach my $md5 ( @md5_dups) {
	print "Dupe MD5: $md5\n";

	my @file_dupes = grep($_->md5() eq $md5, @files);
	#print "filedupes @file_dupes\n";
	foreach (@file_dupes) {

	    #print "\t",$_->filename(),"\n";
	    my($basename, $path, $ext) = $_->fileparse();
	    print "\t$basename$ext\n";
	}
	print "\n";
    }
}

#
# Next check file names and look for problems
#

foreach (@files){
    my($basename, $path, $ext) = $_->fileparse();

    # Skip some stuff
    next if $ext eq ".pl";	                # Code
    next if $ext eq ".jpg";	                # pic
    next if $ext eq ".gif";	                # pic
    next if $basename =~ /^_/;	# start _

    # Check if not end in )
    if ($basename !~ /\)([^\(]*)$/) {
	print "Base Name does not have closing ): $basename$ext\n";
	next;
    }

    # If has part after ), check what is
    if ($1) {
	if ($1 !~ /^_[a-zA-Z0-9]+/) {
	    print "Bad suffix: $basename$ext\t\tSuxxfix=$1\n";
	}
    }	
}


#
# Test Print Info 
#
my $end = min(9, scalar(@files));

foreach (@files[0..$end]){
    my($basename, $path, $ext) = $_->fileparse();

    # print "$basename ", $_->size, "\n";
    my $size = format_bytes($_->size);
    # print "$size\t$basename\n";
    printf "%5s %s\n", $size, $basename;
}

say "Data Dump #4";
print Dumper($files[4]);

