#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;

use IO::Handle;

#
# Todo
#
my $debug = 0;

#
# Scan dir passed as arg, store md5 of all non dot files in  datafle in dir.
# If the modified time has not changed, re-use old modified time
#
my $dir_check = shift(@ARGV);

if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
    die "Bad Dir: $dir_check";
}
say "Scanning $dir_check";

# If db file in dir read in contents
my $dbfile = "$dir_check/.moo.db";
my (%md5_old, %mtime_old, %size_old);
my $fh;

if (-e $dbfile){
    say "Reading dbfile";
    open($fh, "<", $dbfile);

    while (<$fh>){
	chomp;
	my ($md5, $mtime, $size, $filename) = split("\t");
    
	$md5_old{$filename}     = $md5;
	$size_old{$filename}      = $size;
	$mtime_old {$filename} = $mtime;
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

my (%md5, %mtime, %size);

my $i = 1;

# Work through files.
foreach my $filename (@filenames){
    my  $digest = "x" x 32;

    # say "Checking: $filename" if ($debug >= 2);;
    my $filepath = "$dir_check/$filename";

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($filepath);

    $mtime{$filename} = $mtime;
    $size{$filename}     = $size;

    if (-r $filepath){
	if ($mtime_old{$filename} and $mtime_old{$filename} >= $mtime and defined $md5_old{$filename}) {
	    $digest = $md5_old{$filename};
	    print ".";
	} else {
	    $digest = Digest::MD5::File::file_md5_hex($filepath);
	    print "+";
	}
    }

    $md5{$filename} = $digest;
    STDOUT->flush();
    print "\n" if $i++ % 40 == 0;
}
print "\n" unless $i % 40 == 0;

# Write md5 values to file
open($fh, ">", $dbfile);

foreach (sort keys %md5) {
    print $fh "$md5{$_}\t$mtime{$_}\t$size{$_}\t$_\n";
}

close($fh);
