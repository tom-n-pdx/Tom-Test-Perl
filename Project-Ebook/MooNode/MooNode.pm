#
# Supports Ebook_Files object  -a File Object
#
# Base file subclase for files.
# 
# ToDo
# * add a volume method
# * add buld args check? No extra args. Use std args check across code
# * string version mtime, dtime  -use duelvalue
# * read labels / set
# * add a save packed method
# * use vec for decode perms
# * cleanup the stats delta code
# * move flag encodng into this file?
#

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


use File::Basename;             # Manipulate file paths
use Time::localtime;            # Printing stat values in human readable time

# use Data::Dumper qw(Dumper);  # Debug print

package MooNode v0.1.2;
use Moose;
use namespace::autoclean;
use MooseX::Storage;
with Storage('format' => 'JSON', 'io' => 'File');

use FileUtility qw(osx_check_flags_binary osx_flags_binary_string %osx_flags 
		   @stats_names
	           volume_name);
use Fcntl qw(:mode);		# Get fields to parse stat bits
use Scalar::Util qw(dualvar);
use Carp;
use constant MD5_BAD => "x" x 32;

# sub TO_JSON { return { %{ shift() } }; }


has 'filepath',			# full name of file including path
    is => 'rw', 
    isa => 'Str',
    required => 1;

has 'stats',			# stat array - not live version, last time updated or created. 
    is => 'rw',                 # maybe undefined value.
    isa => 'ArrayRef[Int]';


has 'need_update',              # Flag if thi node needs to be updated
    traits => [ 'DoNotSerialize' ],
    is => 'rw',
    isa => 'Int',
    default => 0;


# Extended attributes OS X

has 'flags',			# not a live version. Maybe undef so has a Maybe[Int].
    is => 'rw',                 # binary 8 bit vector. See file utility for bit encoding.
    isa => 'Maybe[Int]',        # No standard bsd nor osx encoding.
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

    # # Normally check that file exists. But - if we skip checking stats - signal not to check if real file
    # if ($filepath && ! -e $filepath){
    # 	croak "ERROR: constructor failed - tried to create Node of non-existent file: ".$filepath;
    # }

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
    my $update_stats  = $$args_ref{'update_stats'}  // 1; # default is do stat on file on creation
    my $update_flags  = $$args_ref{'update_flags'}  // 1; # default is expensive get flags on creation


    # Now - check if really a file. Unless we are not filling in stats, then we assume user maybe not creating live Node

    # make sure a file & fillin stats
    if (! defined $self->stats && $update_stats){
	if (!-e $self->filepath){
	    croak "ERROR: constructor failed - tried to create Node of non-existent file: ".$self->filepath;
	}
    	$self->update_stats;
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

sub update_stats {
    my ($self)=shift( @_);
    my $filepath =  $self->filepath;
 
    # Do NOT follow sym link
    $self->stats( [ stat($filepath) ] );

}

    
sub update_flags {
    my ($self)=shift( @_);
    my $filepath =  $self->filepath;
 
    # Get OS X Extended Atributes before check premissions since premessions depend upon flags
    my $flags = osx_check_flags_binary($filepath);
    $self->flags($flags);
}

    
#
# Values derived from stats values
#
sub size {
    my $self = shift(@_);
    
    my $size = ${$self->stats}[7];
    return($size);
}


sub atime {
    my $self = shift(@_);
    
    my $atime =  ${$self->stats}[8];
    my $str   =  Time::localtime::ctime($atime);
			   
    return( dualvar($atime, $str) );
}


sub mtime {
    my $self = shift(@_);
    
    my $mtime =  ${$self->stats}[9];
    my $str   =  Time::localtime::ctime($mtime);
			   
    return( dualvar($mtime, $str) );
}


sub ctime {
    my $self = shift(@_);
    
    my $ctime =  ${$self->stats}[10];
    my $str   =  Time::localtime::ctime($ctime);
			   
    return( dualvar($ctime, $str) );
}


sub dev {
    my $self = shift(@_);
    
    my $dev =  ${$self->stats}[0];
    return($dev);
}


sub inode {
    my $self = shift(@_);
    
    my $inode =  ${$self->stats}[1];
    return($inode);
}

#
# Derived unique value for hashing file
# inode unique to filesystem, but need value unique across file systems so use dev & inode
#
sub hash {
    my $self = shift(@_);
    
    # my $hash = $self->dev.'-'.$self->inode;
    my $hash = $self->volume_id.'-'.$self->inode;

    return($hash);
}


# From Stat Mode bits
# Mask definations from Fcntl module:
# Orginal examples modified from stat perldoc
sub isdir {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    
    return(S_ISDIR($mode));
}

sub isfile {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    
    return(S_ISREG($mode));
}

sub issym {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    
    return(S_ISLNK($mode));
}

sub type {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    my $type = "Othr";

    $type = "Dir " if (S_ISDIR($mode)); # -d
    $type = "File" if (S_ISREG($mode)); # -f
    $type = "Sym " if (S_ISLNK($mode)); # -l

    return($type);
}


sub isreadable {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    
    my $perms = ($mode & S_IRUSR) >> 8;
    return($perms);
}


sub iswriteable {
    my $self = shift(@_);
    my $mode = ${$self->stats}[2];
    
    my $perms =  ($mode & S_IWUSR) >> 7;
    $perms = $perms && ! ($osx_flags{uchg} & $self->flags);
    return($perms);
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

sub volume {
    my $self = shift(@_);
    my $filepath = $self->filepath;
    my $volume = "/";

    #if ( $filepath =~ m!/Volumes/([^/]*)! ){
    #	$volume = $1;
    #}

    $volume = volume_name($filepath);

    return($volume);
}

sub volume_id {
    my $self = shift(@_);
    my $filepath = $self->filepath;
    my $volume_id = 0x00;


    $volume_id = FileUtility::volume_id($filepath);

    return($volume_id);
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

    # Do I need to update stats after rename?
    # Wil this force a md5 stat?
    $self->update_stats;

}



# every size one larger then needed so leave human readable spalce
# 4    data type 4 chars
# 2    extended  1 chars
# 33   MD5 32 chars
# 143  13 x Long Unsigned Ints 10 characters - stats
# ===
# 183
# 
# 329  Filename - 329
# ===
# 512
# Filename - up to 256 - using 200
my $dbtree_template1 = "A4 A2 A33 A9 (A11)13 A441";         # length 512


#
# Generate packed str for write to file
#  
sub packed_str {
    my $self = shift(@_);

    my $type    = "Node";
    my $extend  = " ";
    my $md5     = MD5_BAD;
    my $flags   = $self->flags;
    my @stats   = @{$self->stats};

    my $name    = $self->filename;
    warn("Name > space 329 $name") if (length($name) > 329);

    my $str = pack($dbtree_template1, $type, $extend, $md5, $flags, @stats, $name);

    return($str);
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

# get from FileUtility?
# Names of stat values
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
# my @stat_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
    

# 
# Check differences between objects - maybe different disks, names - but contents same
# ToDo - make work on stats or object
#
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
    my @self_stats =  @{$self->stats};
    my @other_stats = @{$other->stats};

    # Check all except atime
    foreach (0..7, 9..12){
 	if ($self_stats[$_] != $other_stats[$_]){
      	    push(@changes, $stats_names[$_]);
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

use Number::Bytes::Human qw(format_bytes parse_bytes);

# ToDo
# * print human readable size
# * print human decode flags

sub dump {
    my $self = shift(@_);
    my $str;
 
    print "File: ", $self->filename, "\n";
    print "\tPath:   ", $self->path, "\n";
    print "\tExt:    ", $self->ext, "\n";

    print "\tisDir:  ", true($self->isdir), "\n";
    print "\tisFile: ", true($self->isfile), "\n";
    print "\tType:   ", $self->type, "\n";

    print "\tRead:   ", true($self->isreadable), "\n";
    print "\tWrite:  ", true($self->iswriteable), "\n";

    $str = format_bytes($self->size);
    print "\tSize:   ", $self->size, "  $str\n";
    print "\tInode:  ", $self->inode, "\n";

    $str = osx_flags_binary_string($self->flags);
    print "\tFlags:  ", $self->flags, " $str\n";
    print "\tStats:  ", join(', ',  @{$self->stats} ), "\n";

    print "\n";
    #print "\tAtime:  ", Time::localtime::ctime(@{$self->stats}[8]), "\n";
    print "\tAtime:  ", $self->atime, "\n";
    print "\tMtime:  ", $self->mtime, "\n";
    print "\tCtime:  ", $self->ctime, "\n";
}
   
sub dump_raw {
   my $self = shift(@_);
   my $class = blessed( $self );
   # Moose semi unfriendly - uses raw access to class variables... may break in future
   print "INFO: Dump Raw: File: ", $self->filename, " Class: $class\n";

   my %atributes = (stats =>'ArrayRef');

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

