#!/usr/bin/env perl
#

#
# WARNING: Assumes md5 db file up to date in dir
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

#
#
our $debug = -1;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
# $md5_limit = 10;
my $fast_scan = 0;

my $global_updates = 0;

foreach my $dir_check (@ARGV){
    say "Checking: $dir_check";
    # Force update of dir
    &scan_dir_md5(0, $dir_check);
    my $updates = &check_dir_dupe($dir_check);
    $global_updates += $updates;
    say "Total Dupes: $global_updates";

}
exit;
