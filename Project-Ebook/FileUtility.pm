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
# inc_dot   0    Include dot files, but exclude . and ..
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


    my @temps = @filepaths;
    @filepaths = ();
    foreach (@temps){
	my ($name, $path, $suffix) = File::Basename::fileparse($_);	
	next if ($name eq '.' or $name eq '..');                             # remove . and .. 
	next if (!$inc_dot && $name =~ /^\./); 
	push(@filepaths, $_);
    }


    # Debug code
    if ($verbose >= 2){
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






# End of Module
1;
