#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;
use File::Find;
use constant MD5_BAD => "x" x 32;
use Cwd;

use lib '.';
use ScanDirMD5;

#
# Todo
# * add options verbose, debug, calc md5
# * Move md5, file info into a singular complex data structure instead of 4 hash's
# * Save md5 values for "deleted" files to "trash"?
# * if no data - don't save datafile? erase old datafile?
# * if no files in dir - skip whole thing?
# * split into module,
# * use full path for data, no CD
# * fast version

#
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old modified time
#
our $debug = 0;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
my $fast_scan = 0;


# our (%md5_old, %mtime_old, %size_old, %filename_old);
# our (%md5,        %mtime,        %size,        %filename);

my $global_updates = 0;

find(\&wanted,  @ARGV);

sub wanted {
    return unless -d $File::Find::name;
    my  $dir_check = $File::Find::name;

    say "Checking: $dir_check" if ($debug >= 0);

    # Force update of dir
    &scan_dir_md5(0, $dir_check);

    my $updates = &check_dir_dupe($dir_check);
    $global_updates += $updates;
    # say "Total Dupes: $global_updates" if ($debug >= 0);

   return;
}

say " ";
&report_dupes;

exit;
