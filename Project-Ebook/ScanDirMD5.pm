#
# Functions for scan md5 dirs
#
#
# ToDo
# * add save / load dupes file function
# * write debug pring functions, count lines, etc
# * Move stats for tracking if files changed into this module
# * Bug - if saved fast values, won't save full values until forced update

package ScanDirMD5;
use Exporter qw(import);
our @EXPORT = qw(load_dupes save_dupes update_file_md5 update_dir_md5);

use Modern::Perl; 		        # Implies strict, warnings
use List::Util qw(min max);	        # Import min()
use Digest::MD5::File;
use autodie;
use File::Basename;                     # Manipulate file paths
use Carp;

use lib '.';
use FileUtility qw(%stats_names stats_delta_binary dir_list);

use constant MD5_BAD => "x" x 32;



our (%md5,        %mtime,        %size,        %filename);
our (%md5_old,    %mtime_old,    %size_old,    %filename_old);

my %md5_check;
our %md5_check_HoA;
our %size_check_HoA;

#
# Access gloabl values to track file changes
# Access global lists of files
# Make size array local to md5 module, make file change stats local to md5 module

#
# Don't need access to new and old lists
#
sub update_file_md5 {
    my %opt = @_;

    my $Node        = delete $opt{Node}       // die "Missing param 'Node'";
    my $changes     = delete $opt{changes}    // die "Missing param 'changes'";
    my $stats_new_r = delete $opt{stats}      // die "Missing parm 'stats'";
    my @stats_new   = @{$stats_new_r};

    my $update_md5  = delete $opt{update_md5} // 1;
    my $verbose     = delete $opt{verbose}    // $main::verbose;
    die "Unknown params:", join ", ", keys %opt if %opt;


    if ($changes){
	$main::files_change++;
	my @changes = FileUtility::stats_delta_array($changes);
	# say "    File: ", $Node->filename if ($verbose == 2);
	say "    ", $Node->filename, " Delta: ", join(", ", @changes) if ($verbose >= 2);
	printf "          The binary representation is: %013b\n", $changes if ($verbose >= 3);

	$Node->stats(\@stats_new);        # always update stats if some changed

	# Decide what needs to be changed based upon what stats changed
	# if dev or blksize changes - is error - should not happen
	if ($changes & ( $stats_names{dev} | $stats_names{ino} | $stats_names{blksize} )) {
	    croak("Stats Delta Illegal stats change: ", join(", ", @changes));
	}

	# If ctime - maybe flags changed
	if ($changes & ( $stats_names{ctime})) {
	    $Node->update_flags
	}

	# If mtime or size changed - then clear old md5
	if ( ($changes & ( $stats_names{mtime} | $stats_names{size})) && $Node->can('md5') && defined $Node->md5){
	    $Node->md5(undef);
	}
    }

    # Even if no changs, need to maybe update md5
    $main::size_count{$Node->size}++;
    my $count = $main::size_count{$Node->size};

    if ($Node->can('md5') && ! defined $Node->md5 && $Node->isreadable) {
	if ($update_md5 or  $count >= 2){
	    say "      Update MD5" if ($verbose == 2);
	    $Node->update_md5;
	    $main::files_md5++;
	}
    }

    return;
}

#
# ToDo
# * not use global values for Tree's
# 
sub update_dir_md5 {
    my %opt = @_;

    my $Dir         = delete $opt{Dir}        // croak "Missing param 'Dir'";
    my $changes     = delete $opt{changes}    // croak "Missing param 'changes'";
    my $stats_new_r = delete $opt{stats}      // croak "Missing parm 'stats'";
    my @stats_new = @{$stats_new_r};

    my $Tree_new    = delete $opt{Tree_new}   // croak "Missing param 'Tree_new'";
    my $Tree_old    = delete $opt{Tree_old}   // croak "Missing param 'Tree_old'";

    my $update_md5  = delete $opt{update_md5} // 1;
    my $inc_dir     = delete $opt{inc_dir}    // 0;
    my $verbose     = delete $opt{verbose}    // $main::verbose;
    croak "Unknown params:", join ", ", keys %opt if %opt;

    say "       Dir Update: ", $Dir->filepath if ($verbose >= 2);

    # Loop through files in dir & process. Use extended version of dir_list so have stats & flags
    my ($filepaths_r, $names_r, $stats_AoA_r, $flags_r) = dir_list(dir => $Dir->filepath, 
								   inc_file => 1,inc_dir => $inc_dir, 
								   use_ref => 1);
    foreach ( 0..$#{$filepaths_r} ){
	my $filepath  = @{$filepaths_r}[$_];
	my $name      = @{$names_r}[$_];
	my @stats     = @{ ${$stats_AoA_r}[$_] };
	my $flags     = @{$flags_r}[$_];

	my $hash      = $stats[0].'-'.$stats[1];

	# If is already in new list, we know is unchanged, we can skip checking
	if ($Tree_new->Exist(hash => $hash)) {
	    next;
	}

	# If in old list, check if we need to update path and leave in Old list to process on next iteration
	my $old_node = $Tree_old->Exist(hash => $hash);
	if (defined $old_node) {
	    if ($old_node->filepath ne $filepath) {
		say "          Dir Update- Update filepath: ", $old_node->filename, " to ", $name;
		$old_node->filepath($filepath);
		$main::files_rename++;
	    }

	    # Now Go ahead and process as normal file
	    my $changes = stats_delta_binary($old_node->stats,  \@stats) & ~$stats_names{atime};

	    $Tree_old->Delete($old_node);
	    update_file_md5(Node => $old_node, changes => $changes, stats => \@stats, 
			    update_md5 => $update_md5);
	    $Tree_new->insert($old_node);

	    next;
	}
	    
	# New file or dir, can directlly put in new list
	say "          Dir Update- New Node in Dir: ", $name if ($verbose >= 2);
	my $Node;

	# New file or dir
	if (-r $filepath){
	    $main::files_new++;
	    $Node = MooFile->new(filepath => $filepath, 
				    stats => [ @stats ], update_stats => 0, 
				    flags => $flags,     update_flags => 0,
				    update_md5 => 0);

	
	    $main::size_count{$Node->size}++;
	    my $count = $main::size_count{$Node->size};

	    if ( $Node->can('md5') && ! defined $Node->md5 && $Node->isreadable  &&
		     ($update_md5 or ($count >= 2))){
		$Node->update_md5;
		say "          Dir Update- Calc MD5" if ($verbose >= 2);

		$main::files_md5++;
	    }
	} else {
	    # New Dir
	    $main::files_new++;
	    $Node = MooDir->new(filepath => $filepath, 
				    stats => [ @stats ], update_stats => 0, 
				    flags => $flags,     update_flags => 0,
				    update_dtime => 0);
	
	    # update_dir_md5(Node => $Node, changes => 0x00, stats => @stats, );
	    update_dir_md5(Dir => $Node, Tree_new => $Tree_new, Tree_old => $Tree_old, 
			   update_md5 => $update_md5, inc_dir => $inc_dir);

	}	    

	$Tree_new->insert($Node);
    }

}




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
    open(my $fd, ">", "$dir/$name");
    foreach my $size (sort {$a <=> $b} @dupes){
	print $fd "$size\n";
    }
    close($fd);

    # rename("$dir/$name",      "$dir/$name.old") if -e "$dir/$name";
    # rename("$dir/$name.tmp",  "$dir/$name");

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
