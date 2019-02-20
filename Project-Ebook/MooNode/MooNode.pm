#
# Supports Ebook_Files object  -a File Object
#
# Base file subclase for files.
# 
# ToDo
# * add buld args check? No extra args
# * string version mtime, dtime  -use duelvalue
# * read labels / set
# * add a save packed method
# * use vec for decode perms
# * cleanup the stats delta code
#

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


use File::Basename;             # Manipulate file paths
use Time::localtime;            # Printing stat values in human readable time
use FileUtility;


# use Data::Dumper qw(Dumper);  # Debug print

package MooNode v0.1.2;
use Moose;
use namespace::autoclean;
use Fcntl qw(:mode);		# Get fields to parse stat bits

use Carp;

has 'filepath',			# full name of file including path
    is => 'rw', 
    isa => 'Str',
    required => 1;

has 'stat',			# stat array - not live version, last time updated or created
    is => 'rw',
    isa => 'ArrayRef[Int]';



# Extended attributes OS X

# has 'flags',			# not live version
#     is => 'ro',
#     isa => 'Str',
#     writer => '_set_flags';

has 'flags',			# not live version
    is => 'rw',
    isa => 'Maybe[Int]',
    default => 0;


#
# generic function to convert a call to new with one operand to a ref oriented paramater set with a filepath
#

sub _args_helper {
    my @original = @_;
    my %args;

    # If ONLY one arg - then assume it's a filepath
    if (@original == 1 && !ref $original[0]){
	my $filepath = pop(@original);
	%args = @original;
	$args{filepath} = $filepath;
    } else {
	%args = @original;
    }
    
    return %args;
}

sub BUILDARGS {
    my ($class, @original) = @_;

    my %args = _args_helper(@original);
    my $filepath = $args{filepath};

    # If filepath defined - check is a file of some type
    if ($filepath && ! -e $filepath){
	croak "ERROR: constructor failed - tried to create Node of non-existent file: ".$filepath;
    }


    return \%args;
};


#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my ($self)=shift( @_);
    my $args_ref = shift(@_);
    my $update_stat   = $$args_ref{'update_stat'}   // 1; # default is do stat on file on creation
    my $update_flags  = $$args_ref{'update_flags'}  // 1; # default is expensive get flags on creation


    # Check if the build not set
    if (! defined $self->stat && $update_stat){
	$self->update_stat;
    }

    if (! defined $self->flags){
	if ($update_flags){
	    $self->update_flags;
	} else {
	    $self->flags(0x00);
	}
    }
    return
}

#
# Todo
# * if already exisists - return a list of what changed?
# * save old values somewhere so can move in the tree?
#

sub update_stat {
    my ($self)=shift( @_);
    my $filepath =  $self->filepath;
 
    # Do NOT follow sym link
    $self->stat( [ lstat($filepath) ] );

}

    
sub update_flags {
    my ($self)=shift( @_);
    my $filepath =  $self->filepath;
 
    # Get OS X Extended Atributes before check premissions since premessions depend upon flags
    # my @flags = FileUtility::osx_check_flags($filepath);
    my $flags = FileUtility::osx_check_flags_binary($filepath);
    $self->flags($flags);
}

    
#
# Values derived from stat values
#
sub size {
    my $self = shift(@_);
    
    my $size = ${$self->stat}[7];
    return($size);
}

sub mtime {
    my $self = shift(@_);
    
    my $mtime =  ${$self->stat}[9];
    return($mtime);
}


sub mtime_str {
    my $self = shift(@_);
        
    return(Time::localtime::ctime($self->mtime));
}

sub ctime {
    my $self = shift(@_);
    
    my $mtime =  ${$self->stat}[10];
    return($mtime);
}

sub dev {
    my $self = shift(@_);
    
    my $dev =  ${$self->stat}[0];
    return($dev);
}

sub inode {
    my $self = shift(@_);
    
    my $inode =  ${$self->stat}[1];
    return($inode);
}

# from Stat Mode bits
# Mask definations from Fcntl module:
# Orginal examples modified from stat perldoc
sub isdir {
    my $self = shift(@_);
    my $mode = ${$self->stat}[2];
    
    return(S_ISDIR($mode));
}

sub isfile {
    my $self = shift(@_);
    my $mode = ${$self->stat}[2];
    
    return(S_ISREG($mode));
}

sub isreadable {
    my $self = shift(@_);
    my $mode = ${$self->stat}[2];
    
    my $perms = ($mode & S_IRUSR) >> 8;
    return($perms);
}

sub iswriteable {
    my $self = shift(@_);
    my $mode = ${$self->stat}[2];
    
    my $perms =  ($mode & S_IWUSR) >> 7;
    return($perms);
}


#
# Derived unique value for hashing file
# inode unique to filesystem, but need value unique across file systems so use dev & inode
#
sub hash {
    my $self = shift(@_);
    
    my $hash = $self->dev.'-'.$self->inode;
    return($hash);
}

#
# Live checks - given object exists & filsystem mounted - check if things about file have changed
#

sub isexist {
    my $self = shift(@_);

    return(-e $self->filepath);
}


#
# All the darn names of a file.
# 
# NOTE: None of these are writeable
#
# * filepath    - full absolue name of file (Created by Moose)
# * path        - just directory minus trailing /
# * filename    - name of file including ext minus path
# * ext         - file etension - NOT including the .
# * basename    - minus extension - minus path
#
#

# Note this one doesn't use a regular expression for suffix becuase want name with extension
# If path, does not include trailing /
sub filename {
    my $self = shift(@_);
    my  ($name, $path, $suffix) = File::Basename::fileparse($self->filepath);
    return($name);
}

# CHanged to remove trailing /
sub path {
    my $self = shift(@_);
    my  ($name, $path, $suffix) = File::Basename::fileparse($self->filepath, qr/\.[^.]*/);
    $path =~ s!/$!!;
    return($path);
}

# Includes leading .
sub ext {
    my $self = shift(@_);
    my  ($name, $path, $suffix) = File::Basename::fileparse($self->filepath, qr/\.[^.]*/);
    return($suffix);
}

sub basename {
    my $self = shift(@_);
    my  ($name, $path, $ext) = File::Basename::fileparse($self->filepath, qr/\.[^.]*/);
    return($name);
}

#
# File Rename Method
# * not move to new volume, just rename on current volume
# * if new file exists, it fails
# * Pass the fullpath of new file name
#
# 1. Check exiisting file writable
# 2. Check new name does not exist
# 3. Rename file
# 4. Update object filepath
# 5. Restat?
#
sub rename {
    my $self = shift(@_);
    my $filepath_new = shift(@_);

    # Check current file writable
    if (! -w $self->filepath){
	croak "Tried to rename unwritable file: $self->filepath";
    }
    
    # Check new file not exist 
    if (-e $filepath_new){
	croak "Tried to rename but new file exists: $filepath_new";
    }
    
    rename($self->filepath , $filepath_new);

    $self->_set_filepath($filepath_new);

    # Do I need to update stat after rename?
    # Wil this force a md5 stat?
    $self->update_stat;

}
   

#
# Check if two objects are equal
#
# 1. second object must be same class (subclsses will test true for member base class)
# 2. check some of the stat values
# 3. does NOT check md5 sig  -can't use for dir or unreadable mode
#
# Should it check inode, dev? Amd I check if these files are the same? Or if the file has changed?
# Check             Same             Rename                Equal
# Path                Y                   Y                          N
# Name                Y                   N                          ?
# perms               Y
# size                Y                   Y                          Y
# mtime               Y                   N                          N
# ctime
# md5                 Y                   Y                           Y
#

# Names of stat values
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
my @stat_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
    

# 
# Check differences between objects - maybe different disks, names - but contents same
#  ToDo - make work on stats or object

sub delta {
    my $self    = shift(@_);
    my $other   = shift(@_);

    if (!$other->isa('MooNode')){
	croak "Tried to use isequal on non MooNode object";
    }

    # Collect a list of what attributes changed
    my @changes;

    push(@changes, "filepath")   if ($self->filepath ne $other->filepath);
    
    # OK need to check stats
    my @self_stat =  @{$self->stat};
    my @other_stat = @{$other->stat};

    # Check all except atime
    foreach (0..7, 9..12){
 	if ($self_stat[$_] != $other_stat[$_]){
      	    push(@changes, $stat_names[$_]);
      	}
    }

    push(@changes, "flags") if ($self->flags ne $other->flags);

    # If Can both do md5 and have value, check
    # Maybe impossble for two object for one to do md5 and other not to be equal
    # If one has md5 and one does not - it passes...
    if ($self->can('md5')   && defined $self->md5 && 
        $other->can('md5')  && defined $other->md5){
	push(@changes, "md5") if ($self->md5 ne $other->md5);
    }

    return @changes;
}


#
# Check if changed on disk - minimal check
# Check to see if the version of a file on disk is same as object
# Check: isdir, isfile, isreadable, dev, inode, size, mtime, ctime
# Might be able to optimize based on ctime / mtime match
#
# Need to check flags

#
# Simpler ischanged - just if it has or not
# even simpler live check - use delta function to make compare
sub ischanged {
    my $self = shift(@_);

    my $filepath = $self->filepath;

    my @changes;

    if (! $self->isexist){
    	push(@changes, "deleted");
    	return (@changes);
    }
    
    my $Temp = MooNode->new($filepath);
    @changes = $self->delta($Temp);
    
    return (@changes);
}


#
# Pretty Print Utility
#
sub true {
    return($_[0] ? "True" : "False");
}

sub dump {
    my $self = shift(@_);
 
    print "File: ", $self->filename, "\n";
    print "\tPath:  ", $self->path, "\n";
    print "\tExt:   ", $self->ext, "\n";
    print "\tDir:   ", $self->isdir, "\n";
    print "\tFile:  ", $self->isfile, "\n";
    print "\tRead:  ", $self->isreadable, "\n";
    print "\tSize:  ", $self->size, "\n";
    print "\tInode: ", $self->inode, "\n";
    print "\tFlags: ", $self->flags, "\n";
    print "\tStat:  ", join(', ',  @{$self->stat} ), "\n";

    print "\n";
    print "\tAtime: ", Time::localtime::ctime(@{$self->stat}[8]), "\n";
    print "\tMtime: ", Time::localtime::ctime(@{$self->stat}[9]), "\n";
    print "\tCtime: ", Time::localtime::ctime(@{$self->stat}[10]), "\n";
}
   
sub dump_raw {
   my $self = shift(@_);
   my $class = blessed( $self );
   # Moose semi unfriendly - uses raw access to class variables... may break in future
   print "INFO: Dump Raw: File: ", $self->filename, " Class: $class\n";

   my %atributes = (isfile => 'Bool', isdir => 'Bool', isreadable => 'Bool', stat =>'ArrayRef');

   my @keys = sort keys(%$self);
   foreach (@keys){
       my $type = $atributes{$_} || "String";
       my $string = $$self{$_};
       $string = true($string) if ($type eq "Bool");
       $string = join(', ',  @{$string}) if ($type eq "ArrayRef");
       
       printf  "\t%-10s %s\n", $_, $string;
   }
}

__PACKAGE__->meta->make_immutable;
1;

