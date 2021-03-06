#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
# use List::Util qw(min max);	 # Import min()
#use Digest::MD5::File;
use autodie;
# use File::Find;
# use constant MD5_BAD => "x" x 32;
# use Cwd;
# use List::MoreUtils qw(uniq);

use lib '.';
use ScanDirMD5;
# use constant MD5_BAD => "x" x 32;

our $debug = 0;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
my $fast_scan = 0;

my $global_updates = 0;

my $dir_tree = shift(@ARGV);
&ScanDirMD5::load_dbtree($dir_tree);

#
# How to sort by how close to each other
#

my @filenames;
foreach my $inode (keys %ScanDirMD5::filename){
    my $filepath = $ScanDirMD5::filename{$inode};
    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);

    push(@filenames, $name);
}

@filenames = sort @filenames;
foreach my $filename (@filenames){
     say "$filename";
}


exit;

