#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;
use File::Find;
use constant MD5_BAD => "x" x 32;
use Cwd;

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
# $md5_limit = 10;

my (%md5_old, %mtime_old, %size_old, %filename_old);
my (%md5,        %mtime,        %size,        %filename);

my $global_updates = 0;
# my $start_time = time;

find(\&wanted,  @ARGV);

sub wanted {
    return unless -d $File::Find::name;

    my  $dir_check = $File::Find::name;
    say "Scanning: $dir_check";
    my $updates = &scan_dir_md5($dir_check);
    
    $global_updates += $updates;
    say "Total Update: $global_updates";

   return;
}

exit;


# # Run through each arg and scn listed dir
# foreach my $dir_check (@ARGV){
#     say "Scanning: $dir_check";
#     my $updates = &scan_dir_md5($dir_check);
    
#     $global_updates += $updates;
#     say "Total Update: $global_updates";
#     say " ";
# }

exit;

#
# Function: Load a md5 datafile
# Modifies global hash values
# Hash vars must be defined in main
# 
sub load_md5_db {
    my $dir_check = shift(@_);
    my $dbfile = "$dir_check/.moo.db";
    my $error = 0;

    # Clear old values
    undef %md5_old;
    undef %mtime_old; 
    undef %size_old; 
    undef %filename_old;

    if (-e -r $dbfile){
	# say "Reading dbfile";
	
	open(my $fh, "<", $dbfile);

	while (<$fh>){
	    chomp;
	    my $count = (my ($md5, $mtime, $size, $inode, $filename)) = split("\t");
	    if ($count != 5){
		$error++;
		next;
	    }

	    $mtime_old {$inode} = $mtime;
	    $size_old{$inode}      = $size;
	    $filename_old {$inode}  = $filename;

	    # temp fix for bug in saved files
	    if (length($md5) != 32){
		$md5 = MD5_BAD;
		$error++;
	    }

	    # If it's a bad md5 - leave value empty
	    $md5_old{$inode}     = $md5 if ($md5 ne MD5_BAD);
	}

	close($fh);
	say "\tLoaded ", scalar %filename_old, " values from data file. $error errors"
    }

    return;
}
#
# Function save md5 db database
#
sub save_md5_db {
    my $dir_check = shift(@_);
    my $dbfile = "$dir_check/.moo.db";
    my $tmpfile = $dbfile.'.tmp';
    my $count = scalar(keys %filename);

    if ($count == 0){
	unlink($dbfile) if -e $dbfile;
	say "\tDeleted datafile";
	return;
    }

    open(my $fh, ">", $tmpfile);
	 
    foreach (sort keys %filename) {
	my $md5 = $md5{$_} // MD5_BAD;
	print $fh "$md5\t$mtime{$_}\t$size{$_}\t$_\t$filename{$_}\n";
    }
    rename($tmpfile, $dbfile);

    say "\tSaved ", scalar %filename, " values to datafile";
    close($fh);
    return;
}

#
# Scan a dir and calc md5 values. As part of scan will check if dir valid, and load and save a md5 db file
# Uses global data values
#
sub scan_dir_md5 {
    my $dir_check = shift(@_);

    if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
	warn "Bad Dir: $dir_check";
	return 0;
    }
    say "Scanning $dir_check" if $debug >= 1;

    # Clear old values
    undef %md5;
    undef %mtime; 
    undef %size; 
    undef %filename;

    &load_md5_db($dir_check);    # Modifies global old values

    # Get list of files in dir
    
    my $old_dir = getcwd();
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
    # @filenames = (@filenames, "Bob");                            # test code

    say "Files: ", join(", ", @filenames) if ($debug >= 2);

    my $new_count = 0;
    my $renamed_count = 0;
    my $updated_count = 0;
    my $unchanged_count = 0;
    

    # Pass 1 - quickly scan for stat values and save
    my $i = 0;
    print "\t";

    foreach my $filename (@filenames){
	say "Checking 1: $filename" if ($debug >= 2);

	my $count = (my ($dev, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks)) = stat($filename);
	# If count wrong, stat failed. file name changed, unreadable, some problem
	if ($count != 13){
	    print "x";
	    $i++;
	    next;
	}

	$mtime{$inode}       = $mtime;
	$size{$inode}           = $size;
	$filename{$inode}   =  $filename;

	if ($md5_old{$inode}){
	    # old md5 exists, time same -> unchanged file, use old md5
	    if ($mtime ==  $mtime_old{$inode}) {
		$md5{$inode} = $md5_old{$inode};

		if ($filename eq $filename_old{$inode}){
		    $unchanged_count++;
		    print ".";
		    $i++;
		} else {
		    $renamed_count++;
		    print "r";
		    $i++;
		}

	    } else {
		# old md5 does not exists -> new
		$new_count++;
	    }
	}
	
	# While have Stat value - check for unreadable file, save a bad md5 so skip doing md5 later
	if (!-r _){
	    print "0";
	    # say "Unreadable: $filename";
	    $i++;
	    $md5{$inode} = MD5_BAD;
	    $updated_count++ if ( $md5_old{$inode} && $md5_old{$inode} ne MD5_BAD);
	}	    
	delete $md5_old{$inode};
	    
	print "\n\t" if ($i % $print_width == 0 && $i !=0);
	STDOUT->flush();
    }

    # 2nd Pass - for all files with undefined $md5 value - update md5
    foreach my $inode (keys %filename){
	next if defined $md5{$inode};

	my $filename = $filename{$inode};
	say "Checking 2: $filename" if ($debug >= 2);
	
	my $digest = Digest::MD5::File::file_md5_hex($filename);

	# Odd bug  -sometimes a readable file causes an undefined md5 value
	if (! defined $digest) {
	    say "\nFile: $filename Undefined md5";
	}
	$md5{$inode} = $digest // MD5_BAD;
	$updated_count++;
	print "+";
	$i++;
	

	# Every so often save file
	if ($updated_count % $md5_limit == 0 and $updated_count > 0){
	    print "\n";
	     &save_md5_db($dir_check);
	    $i = 0;
	    print "\t";
	 }

	print "\n\t" if $i % $print_width == 0;
	STDOUT->flush();
    }
    print "\n" unless ($i % $print_width == 0);    # print CR unless just printed one

    # debug code
    my $deleted_count  = scalar  %md5_old;
    say "\tDeleted files:   ", $deleted_count  if ($deleted_count > 0);
    say "\tUpdated files:  ", $updated_count if ($updated_count > 0);
    say "\tRenamed files: ", $renamed_count if ($renamed_count > 0);
    say "\tNew files:         ", $new_count if ($new_count > 0);

    my $changes = $deleted_count + $updated_count + $renamed_count + $new_count;
    # Write md5 values to db file in dir if anythng changed
    if ($changes > 0){
	&save_md5_db($dir_check);
    }

    chdir($old_dir);		# set dir back to strting dir

    return $changes;
}


