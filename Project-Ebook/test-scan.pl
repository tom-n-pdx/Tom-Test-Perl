#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

#
# ToDo - expand ~ in dir path
#

use Number::Bytes::Human qw(format_bytes);
use List::Util qw(min);	# Import min()
use Data::Dumper;           # Debug print

use Storable qw(nstore_fd);
use Fcntl qw(:DEFAULT :flock);


# My Modules
use lib '.';
use Ebook_Files;

sub files_scan_dir {
    my ($dir_path, @args) = @_;
    my @files;

    # Open dir & Scan Files
    opendir(my $dh, $dir_path);
    my @filepaths = readdir $dh;
    closedir $dh;

    @filepaths = grep($_ !~ /^\./, @filepaths);		    # remove . files from last
    @filepaths = map($dir_path.'/'.$_, @filepaths);	    # make into absoule path         

    # print "List files: ", join("\n", @filepaths), "\n";

    foreach (@filepaths) {
	if (!-f $_ && !-d $_) {
	    warn "SKIP non-standard file $_\n";
	    next;
	}

	if (! -r $_){
	    warn "WARN: Can't open file $_\n";
	    next;
	}

	# Create File Object
	# rewrite - so can do checks inside object and return error if problem?
	my $obj = Ebook_Files->new("filepath"=>$_, @args);
	push(@files, $obj);
    }
    
    return @files;
}

#
# Check for dupe size
#

# sub check_dupe_size {
#     my @files = pop(@_);
#     my %count_size;

#     for (@files) {
# 	my $size = $_->size;
# 	$count_size{$size}++;
#     }

#     my @size_dupes = grep( $count_size{$_} > 1 , keys %count_size);

#     foreach my $size ( @size_dupes) {
# 	print "Dupe Size: $size\n";

# 	my @file_dupes = grep($_->size == $size, @files);
# 	foreach (@file_dupes) {
# 	    my($basename, $path, $ext) = $_->fileparse();
# 	    print "\t$basename$ext\n";
# 	}
# 	print "\n";
#     }
#     return;
# }

#
# insert objects into hashtable
#
# hashtable, list of objects
#
# ToDo
# * add check legal key to use
# * insert singular or multuple?
# * pass a medthod function?
# * Move into class? But usable multuple classes...
#
sub hashtable_insert {
    my ($key, @objects) = @_;
    my %hash;

    foreach (@objects){
	next if (! exists $_->{$key});
	my $key_value = $_->{$key};
	push(@{ $hash{$key_value} }, $_);
    }

    # debug - print dupes
    # Make seperate function?
    #
    print "\nCheck Dupe $key\n";
    foreach my $string (sort keys %hash) {
	my @values = @{ $hash{$string} };

	if ($#values > 0){
	    print "$string\n";
	    foreach (@values) {
		my $filename = $_->filename;
		print "\t$filename\n";
	    }
	} 
    }
    
    return(%hash);
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

my @files = files_scan_dir($test1_dir, "calc-md5"=> 1);
#push(@files, files_scan_dir("/Users/tshott/Downloads/_ebook/_ships", "calc-md5"=> 0));
#push(@files, files_scan_dir("/Users/tshott/Downloads/_ebook", "calc-md5"=> 0));
#push(@files, files_scan_dir("/Users/tshott/Downloads/_ebook/_Studies In Big Data Series"));


# Implement locking and network order
# Store objs via storable into file in dir
my $obj_store_file = $test1_dir."/.ebook_files.dbj";
#store(\@files, $obj_store_file);

sysopen(my $df, $obj_store_file, O_RDWR|O_CREAT, 0666) or die "can't open $obj_store_file: $!";
flock($df, LOCK_EX) or die "can't lock $obj_store_file: $!";
nstore_fd(\@files, $df) or die "can't store hash\n";
truncate($df, tell($df));	# Why?
close($df);

print "Stored objs in $obj_store_file\n";


#
#
#
#&check_dupe_size(@files);

my %hashtable;
%hashtable = hashtable_insert("_size",  @files);
%hashtable = hashtable_insert("_md5", @files);
%hashtable = hashtable_insert("_ino", @files);

#say "Data Dump hashtable";
#print Dumper(%hashtable);

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

    # Check if starts with space
    if ($basename =~ /^\s/){
	print "Name starts with space $basename$ext\n";
    }
}


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

