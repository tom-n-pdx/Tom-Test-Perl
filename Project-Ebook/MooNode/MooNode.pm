#
# Supports Ebook_Files object  -a File Object
#
# Base file subclase for files.
# 
# ToDo
# * add buld args check? No extra args
# * string version mtime, dtime  -use duelvalue
# * check exit code from system call in get exttended atributes
# * convert isread, isfile to use stat values and not store seperate


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


use File::Basename;             # Manipulate file paths
use Time::localtime;            # Printing stat values in human readable time
# use Data::Dumper qw(Dumper);  # Debug print

package MooNode v0.1.2;
use Moose;
use namespace::autoclean;

use Carp;

has 'filepath',			# full name of file including path
    is => 'ro', 
    isa => 'Str',
    required => 1,
    writer => '_set_filepath';

has 'stat',			# stat array - not live version, last time updated or created
    is => 'ro',
    isa => 'ArrayRef[Int]',
    writer => '_set_stat';

has 'isreadable',		# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isreadable';

use Fcntl qw(:mode);			# Get fields to parse stat bits

has 'isdir',			# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isdir';

has 'isfile',			# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isfile';

# Extended attributes OS X

has 'flags',			# not live version
    is => 'ro',
#    isa => 'Bool',
    writer => '_set_flags';

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

    # Always checks stat - assumes file always exists live at creation.
    $self->update_stat;

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
 
    # Update the logical values
    $self->_set_isreadable( -r $filepath ? 1 : 0);
    $self->_set_isdir(-d _  ? 1 : 0);
    $self->_set_isfile(-f _ ? 1 : 0);

    # my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
    $self->_set_stat( [ stat(_) ] );            # retruns stat for last file checked with a -x command
    
    # OS X Extended Atributes
    my $flags = _check_extended($filepath);
    $self->_set_flags($flags);
    
}


sub _check_extended {
    my $filepath = shift(@_);

    # On MacOS - ls command can check for extended atributes
    # -l long -d don't diplay dir -1 make sure one colume -O show os x flags
    my $cmd = 'ls -1lOd';
    my $label = 0;
    my $flags = "";
    my $perms;

    my $string = `$cmd "$filepath"`;
    if ($? != 0){
	warn("Error executing ls on $filepath");
	return($flags, $label);
    }

    chomp($string);
    ($perms, $flags) = (split(/\s+/, $string))[0, 4];

    
    # my $extended = substr($perms, -1,  1);
    # $perms    = substr($perms,  0, -1);
    # say "Perms: $perms Extended: $extended Flags: $flags";

    # $cmd = 'mdls -name kMDItemFSLabel -raw ';

    # If has extended data - need to see what it is
    # if ($extended eq "@"){
    # 	$label = `$cmd "$filepath"`;
    # 	# $label = $label + 0;
    # 	say "Label: $label $filepath";
    # }

    return($flags);
}



#
# ToDo
# * stringify?
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

sub hash {
    my $self = shift(@_);
    
    my $hash = $self->dev.'-'.$self->inode;
    return($hash);
}

# does live check
sub isexist {
    my $self = shift(@_);

    return(-e $self->filepath);
}


#
# All the darn names of a file
# * filepath - full absolue name of file (Created by Moose)
# * path - just directory minus trailing /
# * filename - name of file including ext minus path
# * ext - file etension - NOT including the .
# * basename - minus extension - minus path
#
#

# Note this one doesn't use a regular expression for suffix becuase want name with extension
sub filename {
    my $self = shift(@_);
    my  ($name, $path, $suffix) = File::Basename::fileparse($self->filepath);
    return($name);
}

sub path {
    my $self = shift(@_);
    my  ($name, $path, $suffix) = File::Basename::fileparse($self->filepath, qr/\.[^.]*/);
    return($path);
}

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
    
    rename($self->filepath, $filepath_new);

    $self->_set_filepath($filepath_new);

    # Do I need to update stat after rename?
    # Wil this force a md5 stat?
    $self->update_stat;

}
   

#
# Pretty Print Utility
#
sub true {
    return($_[0] ? "True" : "False");
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
# Name              Y                   N                          ?
# isdir                Y                   Y                          Y
# isfile               Y                   Y                          Y
# isreadable       Y                   Y                          N
# dev-ino          Y                   Y                          N
# Size                Y                   Y                          Y
# mtime            Y                   N                          N
# md5               Y                   Y                           Y
#

# Names of stat values
# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
my @stat_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
    

# 
# Check that two file objects are the same - maybe different disks, names - but contents same
# Check: isdir, isfile, size
# makes no sense for dirs
#

sub isequal {
    my $self   =shift(@_);
    my $other = shift(@_);

    if (!$other->isa('MooNode')){
	croak "Tried to use isequal on non MooNode object";
    }

    # Collect a list of what attributes changed
    my @changes;

    push(@changes, "isdir")     if ($self->isdir  != $other->isdir);
    push(@changes, "isfile")    if ($self->isfile != $other->isfile);
    push(@changes, "size")      if ($self->size   != $other->size);
            
    return @changes;
}

# 
# Check that two file objects are the same - maybe different disks, names - but contents same
# Check: isdir, isfile, size
# makes no sense for dirs
#

sub delta {
    my $self    = shift(@_);
    my $other   = shift(@_);

    if (!$other->isa('MooNode')){
	croak "Tried to use isequal on non MooNode object";
    }

    # Collect a list of what attributes changed
    my @changes;

    # say "Delta: Self  ", $self->filepath;
    # say "Delta: Other ", $other->filepath;
    push(@changes, "filepath")   if ($self->filepath ne $other->filepath);
    
    # OK need to check stats
    my @self_stat =  @{$self->stat};
    my @other_stat = @{$other->stat};

    # Check all except atime
    foreach (0..7, 9..12){
 	if ($self_stat[$_] != $other_stat[$_]){
	    # if ( ($self->stat)[$_] != ($other->stat)[$_]){
      	    push(@changes, $stat_names[$_]);
      	}
    }

    push(@changes, "flags") if ($self->flags ne $other->flags);
    return @changes;
}


#
# is changed
# Check to see if the new version of a file on disk is same as old version
# Check: filepath, isdir, isfile, isreadable, dev, inode, size, mtime, ctime
# Calls isqual for some of the checks
#

# sub ischanged {
#     my $self   =shift(@_);
#     my $other = shift(@_);

#     # Call isequal for basic checks
#     my @changes = $self->isequal($other);

#     push(@changes, "filepath") if ($self->filepath ne $other->filepath);
#     push(@changes, "isreadable") if ($self->isreadable != $other->isreadable);

#     # OK need to check stat
#     my @self_stat =  @{$self->stat};
#     my @other_stat = @{$other->stat};

#     # Check dev, ino, mtime, ctime
#     # return a string
#     foreach (0..1, 9..10){
# 	if ($self_stat[$_] != $other_stat[$_]){
# 	    push(@changes, $stat_names[$_]);
# 	}
#     }
    
#     return @changes;
# }

#
# Check if changed on disk - minimal check
# Check to see if the version of a file on disk is same as object
# Check: isdir, isfile, isreadable, dev, inode, size, mtime, ctime
# Might be able to optimize based on ctime / mtime match
#

#
# Simpler ischanged - just if it has or not
# - Live check, no update to stats
sub ischanged {
    my $self   =shift(@_);
    my $filepath = $self->filepath;

    my @changes;

    if (! $self->isexist){
	push(@changes, "deleted");
	return (@changes);
    }
    
    #push(@changes, "isreadable") if ($self->isreadable != -r $filepath);
    #push(@changes, "isdir") if ($self->isdir != -d $filepath);
    #push(@changes, "isfile") if ($self->isfile != -f $filepath);

    # stat file - make a few quick checks
    my @old_stat =  @{$self->stat};
    my @new_stat = stat(_);	                            # Uses last stat value 

    # Check dev, inode, size, mtime, ctime
    foreach (0..1, 7, 9..10){
	if ($old_stat[$_] != $new_stat[$_]){
	    push(@changes, $stat_names[$_]);
	}
    }
    
    return @changes;
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

