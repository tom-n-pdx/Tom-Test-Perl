#
# Functions for scan md5 dirs
#
#
# ToDo
# * Sub formal paramaters?
# * Move md5, file info into a singular complex data structure instead of 4 hash's
# * write debug pring functions, count lines, etc
# * add dir info to datafile 
# * light weight find dupe - only calc MD5 if size matches
# * Save dev? For tree - dir - all on one dev - no... but might need for dir later....
# * How save dir stats in datafile...
# * pass debug as function option var
# * write find dupe code off of reading tree datafile
# * Export key functsions
# * make db tree seperate module
# * handle long filenames, dir names
# * Check for .unwanted
#
# * Bug - if saved fast values, won't save full values until forced update

package ScanDirMD5;
use Exporter qw(import);
our @EXPORT_OK = qw(scan_dir_md5 new_dbtree append_dbtree close_dbtree);


use Modern::Perl; 		         # Implies strict, warnings
use List::Util qw(min max);	 # Import min()
use Digest::MD5::File;
use autodie;
use File::Basename;                  # Manipulate file paths

use constant MD5_BAD => "x" x 32;


our (%md5,        %mtime,        %size,        %filename);
our (%md5_old, %mtime_old, %size_old, %filename_old);

# my %md5_check;
our %md5_check_HoA;
our %size_check_HoA;

# my $dbfile;



#
# Function: Load a md5 datafile
# Modifies global module hash values
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

    my @filenames = list_dir_files($dir_check);
    if (@filenames < 1){
	&save_md5_db($dir_check);
	return(1);
    }

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

    my $num_files = scalar keys %filename;

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

# sub check_dir_dupe {
#     my $dir_check = shift(@_);
#     my $dupes = 0;

#     if (!-e $dir_check or !-d $dir_check or !-r $dir_check){
# 	warn "Bad Dir: $dir_check";
# 	return 0;
#     }
#     say "Checking $dir_check" if $main::debug >= 1;

#     # Load values into old version of vars
#     &load_md5_db($dir_check);    # clears & modifies global old values

#     my $count = scalar keys %md5_old;
#     if ($count == 0){
# 	say "WARN: No md5 values in db file for dir" if ($main::debug >= 1);
# 	return 0;
#     }

#     # Walk through all files, build index via md5, warn if dupe md5
#     foreach my $inode (keys %md5_old){
# 	my $size = $size_old{$inode};
# 	my $md5 = $md5_old{$inode};
# 	my $filename = $filename{$inode};
# 	my $filepath = $dir_check.'/'.$filename;

# 	# if (defined $size_check{$size}){
# 	#     say "Dupe Size: $size Count:$size_check{$size}";
# 	# }
# 	#$size_check{$size}++;

# 	if (defined $md5_check{$md5} && $main::debug >= 1){
# 	    say "Dupe files";
# 	    say "1: ",$md5_check{$md5};
# 	    # say "2: $filename";
# 	    say "2: $filepath";
# 	    say " ";
# 	    $dupes++;
# 	} else {
# 	    # $md5_check{$md5} = $filename;
# 	    $md5_check{$md5} = $filepath;
# 	}

# 	# Using HoA Check
# 	 # push @{ $md5_check_HoA{$md5} }, $filename;
# 	 push @{ $md5_check_HoA{$md5} }, $filepath;

#     }

#     return $dupes;
# }

# sub report_dupes {

#     say "New Check";

#     foreach my $md5 (keys %md5_check_HoA){
# 	my $length = scalar(@{ $md5_check_HoA{$md5} });
# 	next unless $length > 1;
# 	say "MD5: $md5 Dupes: $length";
	
# 	my $old_path = "NULL";
# 	foreach my $filepath (@{ $md5_check_HoA{$md5} }){
# 	    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);
# 	    say "    Dir: $path" if ($path ne $old_path);
# 	    $old_path = $path;;
# 	    say "        $name";
# 	}
# 	say " ";
#     }

#     return;
# }

#
# Calc md5 for one file in dir
# Uses global data values
# Always recalculates md5 value for requested file
#
sub scan_file_md5 {
    my $filepath = shift(@_);

    if (!-e $filepath or !-f $filepath or !-r $filepath){
	warn "Bad File: $filepath";
	return 0;
    }
    
    say "Scanning File $filepath" if ($main::debug >= 1);

    # Clear old values
    undef %md5;
    undef %mtime; 
    undef %size; 
    undef %filename;

    my ($filename, $dir_check, $suffix) = File::Basename::fileparse($filepath);

    # Load data for dir
    say "Load db file: $dir_check";
    &load_md5_db($dir_check);      # Modifies global old values

    # Need to copy old values over to new values
    foreach my $inode (keys %filename_old){
	$filename{$inode} = $filename_old{$inode};
	$size{$inode}         = $size_old{$inode};
	$mtime{$inode}     = $mtime_old{$inode};    
	$md5{$inode}        = $md5_old{$inode} if defined $md5_old{$inode};
    }

    my $count = (my ($dev, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks)) = stat($filepath);
    # If count wrong, stat failed. file name changed, unreadable, some type of problem
    if ($count != 13){
	warn "ERROR: Bad Stat: $filepath";	    
	return 0;
    }

    # Save file values
    $mtime{$inode}       = $mtime;
    $size{$inode}           = $size;
    $filename{$inode}   = $filename;

    # Calc new md5 value
    my $digest = Digest::MD5::File::file_md5_hex($filepath);
    # Odd bug  -sometimes a readable file causes an undefined md5 value
    if (! defined $digest) {
	warn "ERROR: Bad MD5: $filename";
	return 0;
    }
    $md5{$inode}        = $digest;

    # save data for dir
    say "Save db file: $dir_check";
    &save_md5_db($dir_check);

    return 1;
}

#
# Return list normal, non -dot files in dir
# returns list filenames, not full filepaths
# Paramater: dir
#
# sub list_dir_files {
#     my $dir = shift(@_);

#     if (!-d $dir or !-r $dir){
# 	die "Bad dir $dir";
#     }
    
#     # Get list of files in dir
#     opendir(my $dh, $dir);
#     my @filenames = readdir $dh;
#     closedir $dh;

#     @filenames = grep($_ !~ /^\./, @filenames);		                    # remove . files from last
#     @filenames = grep( -f "$dir/$_" , @filenames);		            # remove not normal files from last

#     return (@filenames);
# }

#
# Scan a list of files / dirs and return max mtime
# Paramater: list readable files & dirs
#
sub max_mtime {
    my $dir = shift(@_);
    my @filenames = @_;

    my @mtimes =  map( (stat("$dir/$_"))[9] // 0, @filenames);
    my $max_mtime = max(@mtimes, 0);

    return($max_mtime);
}

#
# Given a dir, see if the dbfile needs updating
# Param: dir
#
sub md5_need_update {
    my $dir = shift(@_);
    my $dbfile = "$dir/.moo.db";
    my @filenames;

    # If no db file, we need a update
    return(1) if (!-e $dbfile);
    my $db_mtime = (stat(_))[9] // 0;

    # If dir mtime > database mtime, need update
    my $dir_mtime = (stat($dir))[9] // 0;
    return(1) if ($dir_mtime > $db_mtime);

    $dir_mtime =  max_mtime($dir, list_dir_files($dir));
    return($dir_mtime > $db_mtime);
}

#
# Tree Datafile Code
# * Move to sepearte flle?
# * Add dev code?
# * wrte dir info?

# every size one larger then needed so leave human readable spalce
# data type 4 chars
# MD5 32 chars
# 3 x Long Unsigned Ints 10 characters - mtime, size, inode
# Filename - up to 256 - using 200

my $dbtree_template1 = "A5 A33 A11 A11 A11 A441";    # length 512
# my $dbtree_template2 = "A5                              A266"; # length 271

my $dbtreefile;   
my $tmptreefile;
my $oldtreefile; 

my $fhtree;

sub new_dbtree {
    my $dir_tree = shift(@_);

    $dbtreefile   = "$dir_tree/.moo.tree.db";
    $tmptreefile = $dbtreefile.'.tmp';
    $oldtreefile  = $dbtreefile.'.old';

    open($fhtree, ">", $tmptreefile);
    print $fhtree "# moo.tree.db version 1.1\n";

    close $fhtree;
}


sub append_dbtree {
    my $dir_check = shift(@_);

    # Now need to append data to tree datafile
    open($fhtree, ">>", $tmptreefile);

    # Write dir info
    my ($dev, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($dir_check);
    my $filename = $dir_check;
    my $length = length($filename);
    
    # For dirs - MD5 field contains dev
    my $str = pack($dbtree_template1, "dir", $dev,  $mtime,  $size,  $inode,  $dir_check);
    print $fhtree "$str\n";

    warn "INFO Dir too long $length $filename" if ($length > 441);
    

    # For dirs - MD5 field contains dev
    $str = pack($dbtree_template1, "dir", $dev,  $mtime,  $size,  $inode,  $dir_check);
    print $fhtree "$str\n";

    foreach my $inode (keys %filename) {
    	my $md5 = $md5{$inode} // MD5_BAD;
	my $filename = $filename{$inode};

	my $str = pack($dbtree_template1, "file", $md5,  $mtime{$inode},  $size{$inode},  $inode,  $filename{$inode});
    	print $fhtree "$str\n";
	
	$length = length($filename);
        warn "INFO File name too long $length $filename{$_}" if ($length > 441);
    }

    close $fhtree;
}

sub close_dbtree {
    my $dir_check = shift(@_);

    if (-e $dbtreefile){
	rename($dbtreefile, $oldtreefile);
    }
    rename($tmptreefile, $dbtreefile);
}

sub load_dbtree {
    my $dir_tree = shift(@_);
    my $file_n = 0;
    my $dir_n = 0;

    $dbtreefile   = "$dir_tree/.moo.tree.db";

    open(my $fhtree, "<", $dbtreefile);

    my $version = <$fhtree>;
    say "DB Tree Version: $version";

    my ($dir, $dev);
    while(<$fhtree>){
	my ($cmd, $md5, $mtime, $size, $inode, $filename) = unpack($dbtree_template1);
	if ($cmd eq "file"){
	    $file_n++;

	    my $filepath = "$dir/$filename";
	    $filename{$inode} = $filepath;
	    $size{$inode}         = $size;
	    $mtime{$inode}     = $mtime;
	    $md5{$inode}        = $md5;

	    push @{ $size_check_HoA{$size} }, $inode;
	    push @{ $md5_check_HoA{$md5} }, $inode;

	} else {
	    $dir_n++;

	    $dir = $filename;
	    $dev = $md5;
	}
    }
    close $fhtree;

    say "Read N File: $file_n Dir: $dir_n";
    
    return;
}



sub report_dupes {

    # sort by $nd5 then $filename
    sub sort1 {
	if ( $md5{$a} eq $md5{$b} ){
	    return( $filename{$a} cmp $filename{$b} );
	}
	$md5{$a} cmp $md5{$b};
    }
    
    say " ";
    say "Dupe Sizes";

    foreach my $size (sort( {$b <=> $a} keys %size_check_HoA)) {
	my @inodes = @{$size_check_HoA{$size}};
	next if (@inodes <= 1);

	say "Size: $size Dupes: ", scalar(@inodes);    
    
	my $md5_old = "";
	my $path_old = "";
    
	@inodes = sort( sort1  @inodes);    
	foreach my $inode (@inodes) {
	    my $filepath = $filename{$inode};
	    my $md5      = $md5{$inode};

	    my $dupe = scalar( @{$md5_check_HoA{$md5}});
	    next if ($md5 ne MD5_BAD && $dupe <= 1);

	    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);

	    if ($md5 eq $md5_old){
		print " " x 32;
	    } else {
		print $md5;
	    }
	    $md5_old = $md5;
	    

	    if ($path ne $path_old) {
		say " $path";
		say " " x 32, "    $name";
	    } else {
		say "    $name";
	    }
	    $path_old = $path;	    
	}
	
	say " ";
    }
    
}



#
# HoA subs
#

sub HoA_push {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my $value = shift(@_);

    if (  !defined( $$HoA_ref{$hash}) || !grep( {$_ eq $value} @{ $$HoA_ref{$hash} }) ){
	push( @{ $$HoA_ref{$hash} }, $value);
    }

    return( scalar( @{ $$HoA_ref{$hash} }));
}


sub HoA_list {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my @list;

    @list = @{ $$HoA_ref{$hash} } if (defined$$HoA_ref{$hash});

    return( @list );
}


sub HoA_pop {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my $value;

    if (defined$$HoA_ref{$hash}){
	$value = pop(@{ $$HoA_ref{$hash} });
	delete $$HoA_ref{$hash} if ( scalar( @{ $$HoA_ref{$hash} } ) <= 0 );
    }
    
    return($value);
}




# End Module
1;
