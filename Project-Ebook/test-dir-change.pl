#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
# use List::Util qw(min max);	 # Import min()
# use Digest::MD5::File;
use autodie;
use File::Find;
# use constant MD5_BAD => "x" x 32;
# use Cwd;
use List::Util qw(min max);	 # Import min()

use lib '.';
use ScanDirMD5;

my $test_dir = "/Users/tshott/Downloads/_ebook/_temp";

if (!-d $test_dir or !-r $test_dir){
    die "Bad dir $test_dir";
}

my $count = (my ($dev, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks)) = stat($test_dir);
# If count wrong, stat failed. file name changed, unreadable, some problem
if ($count != 13){
    die "Bad Stat: $test_dir";
}

my $mtime_str = scalar localtime $mtime;
say "Dir Localtime: $mtime_str";

my @filenames = list_dir_files($test_dir);

#say "Files: ", join(", ", @filenames);
$mtime = max_mtime($test_dir, @filenames);
$mtime_str = scalar localtime $mtime;
say "Dir Files Localtime: $mtime_str";

my $update = md5_need_update($test_dir);
say "Need Update: $update";

# Rename file changes
# New file / file deleted changes mtime
# Changing a file does not modify

