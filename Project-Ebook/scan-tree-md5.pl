#!/usr/bin/env perl
#
# Scans tree of dirs and updates local dir dbfiles as needed
# Also builds new combined db datafile at top of tree
#

use Modern::Perl; 		         # Implies strict, warnings
# use List::Util qw(min max);	 # Import min()
# use Digest::MD5::File;
# use autodie;
use File::Find;
# use constant MD5_BAD => "x" x 32;
# use Cwd;

use lib '.';
use ScanDirMD5 qw(scan_dir_md5 new_dbtree append_dbtree close_dbtree);

#
# Todo
# * add options verbose, debug, calc md5
# * fast version
# * if dir not changed, don't scan dir

#
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old modified time
#
our $debug = 0;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
my $fast_scan = 0;

my $dir_tree = shift(@ARGV);
my $global_updates = 0;

&new_dbtree($dir_tree);

find(\&wanted,  $dir_tree);

&close_dbtree($dir_tree);

exit;


sub wanted {
    return if (!-d $File::Find::name or $File::Find::name =~ /^\./);     # skip non dirs or dot dirs 

    my  $dir_check = $File::Find::name;
    &scan_dir_md5($fast_scan, $dir_check);
    &append_dbtree($dir_check);

   return;
}

