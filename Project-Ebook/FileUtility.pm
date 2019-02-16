#
# A collection of file utiities - non-object oriented. Includes some OS X specific code.
#
# 
# ToDo

package FileUtility;
use Exporter qw(import);
our @EXPORT_OK = qw(dir_list rename_unique);


# Standard uses's
# use Data::Dumper qw(Dumper);           # Debug print
# use Storable qw(nstore_fd nstore retrieve);
# use Fcntl qw(:DEFAULT :flock);
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use Carp qw(croak carp);
use File::Basename;             # Manipulate file paths

#
# Return a list of files
# Checks paramater to make sure is valid.
# If passed a normal, returns a lst with the normal file in it.
# Default it to list only visable normal files
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
    my $inc_dir   =  delete $opt{inc_dir}  // 0;
    my $inc_file  =  delete $opt{inc_file} // 1;
    my $inc_dot   =  delete $opt{inc_dot}  // 0;
    my $inc_sym   =  delete $opt{inc_sym}  // 0;
    my $verbose   =  delete $opt{verbose}  // $main::verbose;
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;

    my @filepaths = ();

    if (!-e $dir){
	carp("Dir $dir does not exist");
	return (@filepaths);
    }

    if (!-r _){
	carp("Dir $dir is not readble");
	return (@filepaths);
    }

    
    if (! -d _) {
	# If not dir, just insert filepath into list on it's own
	@filepaths = ($dir);
    } else {
	# Get list of files in dir
	opendir(my $dh, $dir);
	@filepaths = readdir $dh;
	closedir $dh;

	@filepaths = map("$dir/$_" , @filepaths);                            # convert dir file names to full filepaths
    }


    # Now, narrow list based upon options
    @filepaths = grep(!-d, @filepaths)      if (!$inc_dir);                  # remove dirs unless $inc_dir
    @filepaths = grep(!-f, @filepaths)      if (!$inc_file);                 # remove files unless $inc_file
    @filepaths = grep(!-l, @filepaths)      if (!$inc_sym);		     # remove sym links unless $inc_sym


    my @temps = @filepaths;
    @filepaths = ();
    foreach (@temps){
	my ($name, $path, $suffix) = File::Basename::fileparse($_);	
	next if ($name eq '.' or $name eq '..');                             # remove . and .. 
	next if (!$inc_dot && $name =~ /^\./); 
	
	my @flags = FileUtility::osx_check_flags($_);
	next if (!$inc_dot && grep(/hidden/, @flags));                      # remove hidden files if unless $inc_dot

	push(@filepaths, $_);
    }


    # Debug code
    if ($verbose >= 3){
	say "List of final filenames from dir_list for dir: $dir";
	foreach my $filepath (@filepaths){
	    my ($name, $path, $suffix) = File::Basename::fileparse($filepath);	
	    say $name;
	}
    }

    return (@filepaths);
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

#
# OS X Specific utility
#

# Known Flags:
# uchg        ro user immutable /Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local/Microsoft/Windows/Burn/Burn
# schg        ro system immutable
# hidden                        /Users/tshott/Torrent/TV/Icon
# compressed                    /Users/tshott/Library/Application Scripts/com.apple.iChat/Auto Accept.applescript
# restricted  ro                /System
# sunlnk      ro System Integrity /private

# Doc & hex values https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemDetails/FileSystemDetails.html#//apple_ref/doc/uid/TP40010672-CH8-SW8

# Ugly - Older flags docs don't cover new flags and this is too many bits
# mapping
# blank      0x01   <- -
# uchg       0x01   <- uchg, schg, restricted, sunlnk
# hidden     0x02   <- hidden
# compressed 0x04   <- compressed

my %osx_flags = (uchg => 0x1, hidden => 0x2,  compressed => 0x4, schg => 0, restricted => 0, sunlnk => 0);

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
    
    return(@flags) if ($flags eq "-");

    @flags = sort(split(/,/, $flags));
 
    my @new = grep(! defined $osx_flags{$_}, @flags);
    if (@new){
	warn "Unknown flags: ".join(", ", @new);
    }

    return(@flags);
}





# End of Module
1;
