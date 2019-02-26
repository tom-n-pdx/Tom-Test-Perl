#
# A collection of file utiities - non-object oriented. Includes some OS X specific code.
#
# 
# ToDo

package FileUtility;
use Exporter qw(import);
our @EXPORT_OK = qw(dir_list dir_list_iter rename_unique 
		    osx_check_flags_binary osx_flags_binary_string %osx_flags 
		    stats_delta_binary %stats_names @stats_names);


# Standard uses's
# use Data::Dumper qw(Dumper);           # Debug print
# use Storable qw(nstore_fd nstore retrieve);
# use Fcntl qw(:DEFAULT :flock);
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use Carp qw(croak carp);
use File::Basename;             # Manipulate file paths

#
# Global Module Values
#
# our %osx_flags = ('-'       => 0x00, 
# 		 uchg       => 0x01, schg => 0x1, restricted => 0x1, sunlnk => 0x1,
# 		 hidden     => 0x02,  
# 		 compressed => 0x04,
# 	         nodump     => 0x08);

# our @osx_flags = qw(uchg hidden compressed nodump);

our %osx_flags;
our @osx_flags;

#
# Return a list of files
# Checks paramater to make sure is valid.
# If passed a normal, returns a lst with the normal file in it.
# Default it to list only visable normal files
#
# Try to do only one stat per file in dir
#
#           Default
# inc_dir   0
# inc_file  1
# inc_dot   0    Include dot files, but exclude . and ... Also excludes os x hidden files
# inc_sym   0
#
# ToDO
# * add check hidden
# * make foreach loop for dot files into nicer grep
# 
sub dir_list {
    my %opt = @_;
    my $dir       =  delete $opt{dir} or croak("Missing 'dir' param");

    my $use_ref   =  delete $opt{use_ref}  // 0;

    my $inc_dir   =  delete $opt{inc_dir}  // 0;
    my $inc_file  =  delete $opt{inc_file} // 1;
    my $inc_dot   =  delete $opt{inc_dot}  // 0;
    # my $inc_sym   =  delete $opt{inc_sym}  // 0;

    my $verbose   =  delete $opt{verbose}  // $main::verbose;
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;

    my @filepaths = ();
    my @filenames = ();
    my @stats_AoA = ();
    my @flags_AoA = ();

    if (!-e $dir){
	carp("Dir $dir does not exist");
	return ($use_ref ? (\@filepaths, \@filenames, \@stats_AoA, \@flags_AoA) : @filepaths);
    }

    if (!-r _){
	carp("Dir $dir is not readble");
	return ($use_ref ? (\@filepaths, \@filenames, \@stats_AoA, \@flags_AoA) : @filepaths);
    }
    
    if (! -d _) {
	carp("Dir $dir is not a dir");
	return ($use_ref ? (\@filepaths, \@filenames, \@stats_AoA, \@flags_AoA) : @filepaths);
    }

    
    # Get list of files in dir
    opendir(my $dh, $dir);
    my @filenames_temp = readdir $dh;
    closedir $dh;

    foreach my $name (@filenames_temp){
    	my $filepath  = "$dir/$name";
    	my @stats     = lstat($filepath);

	next if ($name eq '.' or $name eq '..');                             # remove . and .. 
	next if (!$inc_dot && $name =~ /^\./);                               # remove dot files

	next if (-d _ && !$inc_dir);
	next if (-f _ && !$inc_file);

    	my $flags = FileUtility::osx_check_flags_binary($filepath);
	if ($flags & $osx_flags{hidden} && ! $inc_dot){
	    next;
	}

	push(@filepaths, $filepath);
	push(@filenames, $name);
	push(@stats_AoA, \@stats);
	push(@flags_AoA, $flags);
    }

    	

    # Debug code
    if ($verbose >= 3){
	say "List of final filenames from dir_list for dir: $dir";
	foreach my $filepath (@filepaths){
	    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);	
	    say $name;
	}
    }

    return ($use_ref ? (\@filepaths, \@filenames, \@stats_AoA, \@flags_AoA) : @filepaths);
}


sub dir_list_iter {
    my %opt   = @_;

    my $dir       = delete $opt{dir} or die("Missing 'dir' param");
    my $inc_dot   = delete $opt{inc_dot} // 0;
    my $inc_dir   = delete $opt{inc_dir} // 0;
    die "Unknown params:", join ", ", keys %opt if %opt;

    opendir(my $dh, $dir);

    return sub {
	my ($name, $filepath, $flags, @stats);

	while ($name = readdir $dh){
	    $filepath = "$dir/$name";
	    next if (! $inc_dot && $name =~ /^\./);
	    next if (! $inc_dir && -d $filepath);

	    @stats = lstat($filepath);
	    $flags = osx_check_flags_binary($filepath);

	    last;
	};

	
	return($name, $filepath, $flags, @stats);
    };
}







#
# rename (even across devices) uniquely
# If new name exists, will rename something _v10, _v11, etc
# rename(old filename, new filename)
# returns filepath of new file
use File::Copy;

sub rename_unique {
    my $filename_old = shift(@_);
    my $filename_new = shift(@_);

    say "Filename Old: $filename_old";
    say "Filename New: $filename_new";

    if (!-e $filename_old){
	croak "Starting file does not exisit: $filename_old";
    }

    my $version = 9;
    my ($name, $path, $ext) = File::Basename::fileparse($filename_new, qr/\.[^.]*/);
    while (-e $filename_new){
	$version++;
	$filename_new = "$path${name}_v$version$ext";
    }
    rename($filename_old, $filename_new) unless (-e $filename_new);
    # say "Unique Rename $filename_old -> $filename_new";

    return($filename_new);
}

our @stats_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
our %stats_names;

foreach (0..12){
     $stats_names{$stats_names[$_]} = 0b01 << $_;
}



#
# Figure out changes between two files check all except skip atime (access time)
#
sub stats_delta {
    my $old_stats_r = shift(@_);
    my $new_stats_r = shift(@_);

    my @changes;

    foreach (0..7, 9..12){
 	if ($$old_stats_r[$_] != $$new_stats_r[$_]){
      	    push(@changes, $stats_names[$_]);
      	}
    }

    return(@changes);
}

#
# Figure out changes between two files check all
# * Create binary vector for changes
# ToDO
# * rewrite using vec?
sub stats_delta_binary {
    my $old_stats_r = shift(@_);
    my $new_stats_r = shift(@_);

    my $changes = 0b000000000000;

    foreach (0..12){
	if ($$old_stats_r[$_] != $$new_stats_r[$_]){
	    $changes = $changes | (0x01 << $_);              # set bit corresponding to stat value 
	}
    }
    return($changes);
}

sub stats_delta_array {
    my $binary = shift(@_);
    my @changes;

    foreach (0..12){
	if ($binary & 0x01){
	    push(@changes, $stats_names[$_]);
	}
	$binary = $binary >> 1;
    }

    return(@changes);
}


#
# Need pretty way to check if bit set...
# Convert vec to string / array
#



#
# OS X Specific utility
#

# Known Flags:
# uchg        ro user immutable /Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local/Microsoft/Windows/Burn/Burn
# schg        ro system immutable
# hidden                        /Users/tshott/Torrent/TV/Icon?
# compressed                    /Users/tshott/Library/Application Scripts/com.apple.iChat/Auto Accept.applescript
# restricted  ro                /System
# sunlnk      ro System Integrity /private

# Doc & hex values https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemDetails/FileSystemDetails.html#//apple_ref/doc/uid/TP40010672-CH8-SW8

# Ugly - Older flags docs don't cover new flags and this is too many bits
# mapping
# blank      0x00   <- -
# uchg       0x01   <- uchg, schg, restricted, sunlnk
# hidden     0x02   <- hidden
# compressed 0x04   <- compressed


%osx_flags = ('-'         => 0x00, 
	      uchg        => 0x01, schg => 0x1, restricted => 0x1, sunlnk => 0x1,
	      hidden      => 0x02,  
	      compressed  => 0x04,
	      nodump      => 0x08);

@osx_flags = qw(uchg hidden compressed nodump);



sub osx_check_flags {
    my $filepath = shift(@_);

    # On MacOS - ls command can check for extended atributes
    # -l long -d don't diplay dir -1 make sure one colume -O show os x flags
    my $cmd = 'ls -1lOd';

    my @flags;

    my $text = $filepath;
    $text =~ s/'/'"'"'/g;              # Escape ' in filename
    my $string = `$cmd '$text' `;

    if ($? != 0){
	warn("Error executing ls on $filepath");
	return(@flags);
    }

    chomp($string);
    my $flags = (split(/\s+/, $string))[4];      # flags are 4th field in ls output
    return 
    
    @flags = sort(split(/,/, $flags));
 
    my @new = grep(! defined $osx_flags{$_}, @flags);
    if (@new){
	warn "Unknown flags: ".join(", ", @new);
    }

    return(@flags);
}

sub osx_check_flags_binary {
    my $filepath = shift(@_);

    # On MacOS - ls command can check for extended atributes
    # -l long -d don't diplay dir -1 make sure one colume -O show os x flags
    my $cmd = 'ls -1lOd';

    my @flags;
    my $flags_binary = 0x00;

    my $text = $filepath;
    $text =~ s/'/'"'"'/g;                       # Escape ' in filename
    my $string = `$cmd '$text' `;

    if ($? != 0){
	warn("Error executing ls on $filepath");
	return($flags_binary);
    }

    my $flags = (split(/\s+/, $string))[4];     # flags are 4th field in ls output
    @flags = split(/,/, $flags);                # flags feild split on space
    
    # Convert to binary
    foreach my $flag (@flags){
	if (defined $osx_flags{$flag} ){
	    $flags_binary = $flags_binary | $osx_flags{$flag};
	    # say "Flag: $flag";
	} else {
	    warn "Unknown Flag: $flag";
	}
    }

    return($flags_binary);
}

sub osx_flags_binary_string {
    my $binary = shift(@_);
    my $string = "";

    foreach (0..4){
	if ($binary & 1 << $_){
	    # say "Bit Set: $_";
	    $string = $string.' '.$osx_flags[$_];
	}
    }
    return($string);
}

# End of Module
1;
