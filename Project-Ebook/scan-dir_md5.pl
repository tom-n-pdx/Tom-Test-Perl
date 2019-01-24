#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;

use IO::Handle;

#
# Todo
# * Add sav inode, check inode


#
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old modified time
#
my $debug = 0;
my $dir_check = shift(@ARGV);

if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
    die "Bad Dir: $dir_check";
}
say "Scanning $dir_check";

# If db file in dir read in contents
my (%md5_old, %mtime_old, %size_old, %filename_old);
my $fh;

my $dbfile = "$dir_check/.moo.db";
if (-e $dbfile){
    say "Reading dbfile";
    open($fh, "<", $dbfile);

    while (<$fh>){
	chomp;
	my ($md5, $mtime, $size, $inode, $filename) = split("\t");
    
	$md5_old{$inode}     = $md5;
	$mtime_old {$inode} = $mtime;
	$size_old{$inode}      = $size;
	# $inode_old {$inode}  = $inode;
	$filename_old {$inode}  = $filename;
    }

    close($fh);

}
    
# Get list of files in dir
chdir($dir_check);
opendir(my $dh, ".");
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(-f $_ , @filenames);		            # remove not normal files from last

# for debug only do first N  files
if ($debug >= 1){
    my $end = min(10, $#filenames);                                       
    @filenames = @filenames[0..$end];
}

say "Files: ", join(", ", @filenames) if ($debug >= 2);

my (%md5, %mtime, %size, %filename);

my $i = 1;
my $md5_count = 0;

# Work through files.
foreach my $filename (@filenames){
    my  $digest = "x" x 32;

    # say "Checking: $filename" if ($debug >= 2);;
    my $filepath = "$dir_check/$filename";

    my ($dev,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($filepath);

    $mtime{$inode} = $mtime;
    $size{$inode}     = $size;
    # $inode{$inode}  = $inode;
    $filename{$inode}  =  $filename;

    if (-r $filepath){
	if ($mtime_old{$inode} and $mtime_old{$inode} >= $mtime and defined $md5_old{$inode}) {
	    $digest = $md5_old{$inode};
	    print ".";
	} else {
	    $digest = Digest::MD5::File::file_md5_hex($filepath);
	    $md5_count++;
	    print "+";
	}
    } else {
	print "0";
    }

    $md5{$inode} = $digest;
    STDOUT->flush();
    print "\n" if $i++ % 40 == 0;
}
print "\n" unless $i % 40 == 0;
say "MD5 Count: $md5_count";


# Write md5 values to file
open($fh, ">", $dbfile);

foreach (sort keys %md5) {
    print $fh "$md5{$_}\t$mtime{$_}\t$size{$_}\t$_\t$filename{$_}\n";
}

close($fh);
