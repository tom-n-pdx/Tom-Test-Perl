#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
# use List::Util qw(min max);	 # Import min()
# use Digest::MD5::File;
use autodie;
use File::Find;
# use constant MD5_BAD => "x" x 32;
# use Cwd;

use lib '.';
use ScanDirMD5;

#
# Todo
# * add options verbose, debug, calc md5

#
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old modified time
#
our $debug = 0;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
my $fast_scan = 0;

my $global_updates = 0;

foreach my $dir_check (@ARGV){
    say "Scanning: $dir_check";
    my $updates = &ScanDirMD5::scan_dir_md5($fast_scan, $dir_check);
    
    $global_updates += $updates;
    say "Total Update: $global_updates";

}
exit;
