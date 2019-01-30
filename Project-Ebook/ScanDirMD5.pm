#
# Functions for scan md5 dirs
#
#
# ToDo
# * Sub formal paramaters?
# * Move md5, file info into a singular complex data structure instead of 4 hash's
# * write debug pring functions, count lines, etc
# * add dir info to datafile 
# * Need a update md5 for one file sub
# * need hash of array data structure
# * store full filename? inode? of dupe files

use Modern::Perl; 		         # Implies strict, warnings
use constant MD5_BAD => "x" x 32;
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;
use File::Basename;         # Manipulate file paths


my (%md5,        %mtime,        %size,        %filename);
my (%md5_old, %mtime_old, %size_old, %filename_old);

my %md5_check;
my %md5_check_HoA;
my %size_check;

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
	say "Reading dbfile" if ($main::debug >= 2);
	
	open(my $fh, "<", $dbfile);
	my @fields;
	my ($type, $md5, $mtime, $size, $inode, $filename);

	while (<$fh>){
	    chomp;
	    # Remove everything from comment to end of line
	    next if (/^#/);
	    
	    my $count = (my @fields) = split("\t");
	    next if ($count == 0);

	    # say "Count: $count-$_";

	    if ($fields[0] eq "file" && $count == 6){
		($type, $md5, $mtime, $size, $inode, $filename) = @fields;
	    } elsif ($count == 5){
		($md5, $mtime, $size, $inode, $filename) = @fields;
	    } else {
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

	    # If it's a bad md5 - don't define hash value
	    # no md5 value means either not caculated, file was not readable or error on calculation
	    $md5_old{$inode} = $md5 if ($md5 ne MD5_BAD);
	}

	close($fh);
	say "\tLoaded ", scalar %filename_old, " values from data file. $error errors" if ($main::debug >= 1 or $error > 0);
    }

    return;
}
#
# Function save md5 db database
# Paramater: full path to dir
sub save_md5_db {
    my $dir_check = shift(@_);
    my $dbfile = "$dir_check/.moo.db";
    my $tmpfile = $dbfile.'.tmp';
    my $oldfile  = $dbfile.'.old';

    # my $count = scalar(keys %filename);

    open(my $fh, ">", $tmpfile);
    print $fh "# moo.db version 1.1\n";
    foreach (sort keys %filename) {
	my $md5 = $md5{$_} // MD5_BAD;
	print $fh "file\t$md5\t$mtime{$_}\t$size{$_}\t$_\t$filename{$_}\n";
    }
    close($fh);

    if (-e $dbfile){
	rename($dbfile, $oldfile);
    }
    rename($tmpfile, $dbfile);

    say "\tSaved ", scalar %filename, " values to datafile" if ($main::debug >= 1);
    return;
}

#
# Scan a dir and calc md5 values. As part of scan will check if dir valid, and load and save a md5 db file
# Uses global data values
# Pass if fast or slow, the full path of dir to scan
#
sub scan_dir_md5 {
    my $fast_scan = shift(@_);
    my $dir_check = shift(@_);

    say "\tFAST SCAN" if $fast_scan;

    if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
	warn "Bad Dir: $dir_check";
	return 0;
    }
    say "Scanning $dir_check" if ($main::debug >= 1);

    # Clear old values
    undef %md5;
    undef %mtime; 
    undef %size; 
    undef %filename;

    &load_md5_db($dir_check);    # Modifies global old values

    # Get list of files in dir
    opendir(my $dh, $dir_check);
    my @filenames = readdir $dh;
    closedir $dh;

    @filenames = grep($_ !~ /^\./, @filenames);		                            # remove . files from last
    @filenames = grep(-f $dir_check.'/'.$_ , @filenames);		            # remove not normal files from last

    # for debug only do first N  files
    if ($main::debug >= 1){
	my $end = min(10, $#filenames);                                       
	@filenames = @filenames[0..$end];
    }
    # @filenames = (@filenames, "Bob");                            # test code

    say "Files: ", join(", ", @filenames) if ($main::debug >= 1);

    my $new_count = 0;
    my $renamed_count = 0;
    my $updated_count = 0;
    
    # Pass 1 - quickly scan for stat values
    my $i = 0;
    if ($main::debug >= 0){
	print "\t";
    }

    foreach my $filename (@filenames){
	say "Checking Phase 1: $filename" if ($main::debug >= 2);
	my $filepath = $dir_check."/".$filename;

	my $count = (my ($dev, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks)) = stat($filepath);
	# If count wrong, stat failed. file name changed, unreadable, some problem
	if ($count != 13){
	    print "\n\tERROR: Bad Stat: $filename\n\t" if ($main::debug >= 0);	    
	    print "x"; $i++;
	    next;
	}

	$mtime{$inode}       = $mtime;
	$size{$inode}           = $size;
	$filename{$inode}   = $filename;

	# Existing File
	if (defined $filename_old{$inode}){
	    say "Old Filename Exists" if ($main::debug >= 2);
	    
	    # Check if good md5 exists for file - md5 exists, mtime & size unchanged
	    if (defined $md5_old{$inode} && $mtime <= $mtime_old{$inode}){
		say "Old MD5 Exists & unchanged" if ($main::debug >= 2);
	    	$md5{$inode} = $md5_old{$inode};
		
		# $unchanged_count++;
		if ($main::debug >= 0) {
		    print "."; 
		    $i++;
		}
		delete $md5_old{$inode};
	    }

	    if ($filename ne $filename_old{$inode}){
		$renamed_count++;
		print "\n\tINFO: Rename: New: $filename Old: $filename_old{$inode}\n\t" if ($main::debug >= 2);
		if ($main::debug >= 0) {
		    print "r"; 
		    $i++;
		}
	    }

	    delete $filename_old{$inode};

	} else {
	    # New File
	    say "Old Filename Not Exists" if ($main::debug >= 2);
	    $new_count++;
	    if ($main::debug >= 0) {
		print "n"; 
		$i++;
	    }
	}
	
	print "\n\t" if ($i % $main::print_width == 0 && $i > 0 && $main::debug >= 0);
	STDOUT->flush();
    }

    # 2nd Pass - for all files with undefined $md5 value - update md5
    my @file_inodes  = keys(%filename);
    @file_inodes = grep(! defined $md5{$_}, @file_inodes);


    # say "\n\tFiles need md5: ", scalar(@file_inodes);
    # print "\t";
    if (scalar(@file_inodes) > 0 and !$fast_scan ){
    	# print "\n\tDo MD5 Scan\n\t"; $i = 0;
    	foreach my $inode (@file_inodes) {
    	    # next if defined $md5{$inode};

    	    my $filename = $filename{$inode};
    	    say "Checking 2: $filename" if ($main::debug >= 2);

    	    my $filepath = $dir_check.'/'.$filename;
	    if (!-e $filepath or !-r $filepath){
    		print "\nINFO: Unreadable: $filename \n\t" if ($main::debug >= 1);
		if ($main::debug >= 0) {
		    print "0"; 
		    $i++;
		}
		next;
	    }
    	    my $digest = Digest::MD5::File::file_md5_hex($filepath);
    	    # Odd bug  -sometimes a readable file causes an undefined md5 value
    	    if (! defined $digest) {
    		print "\nERROR: Bad MD5: $filename \n\t"; $i = 0;
    	    }
    	    $md5{$inode} = $digest // MD5_BAD;
    	    $updated_count++;
	    if ($main::debug >= 0) {
		print "+"; 
		$i++;
	    }
    	    # Every so often save file
    	    if ($updated_count % $main::md5_limit == 0 and $updated_count > 0) {
    		print "\n\tSave Data\n" if ($main::debug >= 0);
    		&save_md5_db($dir_check);
    		$i = 0;
    		print "\t" if ($main::debug >= 0);;
    	    }

    	    print "\n\t" if ($i % $main::print_width == 0 && $i > 0 && $main::debug >= 0);
    	    STDOUT->flush();
    	}
    }
    
    if ($main::debug >= 0){
	print "\n" unless ($i % $main::print_width == 0 && $i > 0);    # print CR unless just printed one
    }

    # debug code
    # BUG - a undeletedd unreadable file?
    my $deleted_count  = scalar  %filename_old; # And records left in old list must have been deleted 
    say "\tDeleted files:   ", $deleted_count  if ($deleted_count > 0);
    say "\tUpdated files:  ", $updated_count if ($updated_count > 0  && $main::debug >= 0);
    say "\tRenamed files: ", $renamed_count if ($renamed_count > 0 && $main::debug >= 0);
    say "\tNew files:         ", $new_count if ($new_count > 0 && $main::debug >= 0);

    my $changes = $deleted_count + $updated_count + $renamed_count + $new_count;
    # Write md5 values to db file in dir if anythng changed

    if ($changes > 0) {
	&save_md5_db($dir_check);
    }

    return $changes;
}


sub check_dir_dupe {
    my $dir_check = shift(@_);
    my $dupes = 0;

    if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
	warn "Bad Dir: $dir_check";
	return 0;
    }
    say "Checking $dir_check" if $main::debug >= 1;

    # Load values into old version of vars
    &load_md5_db($dir_check);    # clears & modifies global old values

    my $count = scalar keys %md5_old;
    if ($count == 0){
	say "WARN: No md5 values in db file for dir" if ($main::debug >= 1);
	return 0;
    }

    # Walk through all files, build index via md5, warn if dupe md5
    foreach my $inode (keys %md5_old){
	my $size = $size_old{$inode};
	my $md5 = $md5_old{$inode};
	my $filename = $filename{$inode};
	my $filepath = $dir_check.'/'.$filename;

	# if (defined $size_check{$size}){
	#     say "Dupe Size: $size Count:$size_check{$size}";
	# }
	$size_check{$size}++;

	if (defined $md5_check{$md5} && $main::debug >= 1){
	    say "Dupe files";
	    say "1: ",$md5_check{$md5};
	    # say "2: $filename";
	    say "2: $filepath";
	    say " ";
	    $dupes++;
	} else {
	    # $md5_check{$md5} = $filename;
	    $md5_check{$md5} = $filepath;
	}

	# Using HoA Check
	 # push @{ $md5_check_HoA{$md5} }, $filename;
	 push @{ $md5_check_HoA{$md5} }, $filepath;

    }

    return $dupes;
}

sub report_dupes {

    say "New Check";

    foreach my $md5 (keys %md5_check_HoA){
	my $length = scalar(@{ $md5_check_HoA{$md5} });
	next unless $length > 1;
	say "MD5: $md5 Dupes: $length";
	
	my $old_path = "NULL";
	foreach my $filepath (@{ $md5_check_HoA{$md5} }){
	    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);
	    say "    Dir: $path" if ($path ne $old_path);
	    $old_path = $path;;
	    say "        $name";
	}
	say " ";
    }

    return;
}
# End Module
1;
