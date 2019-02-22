#
# Functions for scan md5 dirs
#
#
# ToDo
# * add save / load dupes file function
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
our @EXPORT = qw(scan_dir_md5 load_dupes save_dupes);

use Modern::Perl; 		        # Implies strict, warnings
use List::Util qw(min max);	        # Import min()
use Digest::MD5::File;
use autodie;
use File::Basename;                     # Manipulate file paths

use constant MD5_BAD => "x" x 32;


our (%md5,        %mtime,        %size,        %filename);
our (%md5_old,    %mtime_old,    %size_old,    %filename_old);

my %md5_check;
our %md5_check_HoA;
our %size_check_HoA;

# my $dbfile;




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

# sub load_dbtree {
#     my $dir_tree = shift(@_);
#     my $file_n = 0;
#     my $dir_n = 0;

#     $dbtreefile   = "$dir_tree/.moo.tree.db";

#     open(my $fhtree, "<", $dbtreefile);

#     my $version = <$fhtree>;
#     say "DB Tree Version: $version";

#     my ($dir, $dev);
#     while(<$fhtree>){
# 	my ($cmd, $md5, $mtime, $size, $inode, $filename) = unpack($dbtree_template1);
# 	if ($cmd eq "file"){
# 	    $file_n++;

# 	    my $filepath = "$dir/$filename";
# 	    $filename{$inode} = $filepath;
# 	    $size{$inode}         = $size;
# 	    $mtime{$inode}     = $mtime;
# 	    $md5{$inode}        = $md5;

# 	    push @{ $size_check_HoA{$size} }, $inode;
# 	    push @{ $md5_check_HoA{$md5} }, $inode;

# 	} else {
# 	    $dir_n++;

# 	    $dir = $filename;
# 	    $dev = $md5;
# 	}
#     }
#     close $fhtree;

#     say "Read N File: $file_n Dir: $dir_n";
    
#     return;
# }



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
#
# Functions to save & load a dupes file
#
#

#
# Save dupes file
# Save a list of all sizes with more then one file already
# 
sub save_dupes {
    my %opt = @_;
    my $dupes_ref =  delete $opt{dupes} or die "Required paramater 'dupes' missing";
    my $dir       =  delete $opt{dir} // "/Users/tshott/Downloads/Lists_Disks";
    my $name      =  delete $opt{fast_scan} // "dupes.db";
    my $verbose   =  delete $opt{verbose} // $main::verbose;
    die "Unknown params:", join ", ", keys %opt if %opt;
    
    my @dupes = keys %{$dupes_ref};
    @dupes = grep ( {$$dupes_ref{$_} >= 2} @dupes);

    if ($verbose >= 3){
	say " ";
	say "Saving Dupe Szes:";
	foreach my $size (sort {$a <=> $b} @dupes){
	    # next if $$dupes_ref{$size} <= 1;
	    say "\t$size $$dupes_ref{$size}"
	}
    }

    # save to temp file and rotate files
    open(my $fd, ">", "$dir/$name.tmp");
    foreach my $size (sort {$a <=> $b} @dupes){
	print $fd "$size\n";
    }
    close($fd);
    rename("$dir/$name",      "$dir/$name.old") if -e "$dir/$name";
    rename("$dir/$name.tmp",  "$dir/$name");

    return;
}

#
# Load dupes file
# If dupe file exists, loads and sets up hash 
# 
sub load_dupes {
    my %opt = @_;
    my $dupes_ref =  delete $opt{dupes} or die "Required paramater 'dupes' missing";
    my $dir       =  delete $opt{dir} // "/Users/tshott/Downloads/Lists_Disks";
    my $name      =  delete $opt{fast_scan} // "dupes.db";
    my $verbose   =  delete $opt{verbose} // $main::verbose;
    die "Unknown params:", join ", ", keys %opt if %opt;
    
    if (!-e "$dir/$name"){
	warn "Dupes data file not found: $dir/$name";
	return;
    }

    open(my $fd, "<", "$dir/$name");
    while(my $value = <$fd>){
	chomp($value);
	$value = $value + 0;
	$$dupes_ref{$value} = 100;
    }
    close($fd);


    say " ";
    say "Loaded Dupe Values: ", scalar(keys %{$dupes_ref}) if ($verbose >= 2);

    if ($verbose >= 3){
	say "Values:";
	foreach my $size (keys %{$dupes_ref} ){
	    say "\t$size $$dupes_ref{$size}";
	}
    }


    return;
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
