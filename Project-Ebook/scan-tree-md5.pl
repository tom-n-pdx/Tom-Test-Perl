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
my $fast_scan = 1;


# our (%md5_old, %mtime_old, %size_old, %filename_old);
# our (%md5,        %mtime,        %size,        %filename);

my $global_updates = 0;

find(\&wanted,  @ARGV);

sub wanted {
    return unless -d $File::Find::name && md5_need_update($File::Find::name);
    return if ($File::Find::name =~ /^\./);


    my  $dir_check = $File::Find::name;
    say "Scanning: $dir_check";
    my $updates = &scan_dir_md5($fast_scan, $dir_check);
    
    $global_updates += $updates;
    say "Total Update: $global_updates";

   return;
}

exit;
