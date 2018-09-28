#
# Supports Ebook_Files object  -a File Object
#
# Base file subclase for files.
# 
# ToDo
# * rename update stats to stat - make consistent
# * add buld args check? No extra args
# * print class of object in dump
# * enabled new to take a full filepath as first arg
# * string version mtime, dtime
# * consider using atribute triggers to handle storing old and new values so Collection can fix
# * rewrite buildargs as not around - or see if can use trigger or type to check values
# * consdier combine some of the code from check values out into  a sub
#


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


use File::Basename;         # Manipulate file paths
use Time::localtime;        # Printing stat values in human readable time
# use Data::Dumper qw(Dumper);           # Debug print

package MooNode;
use Moose;
use namespace::autoclean;

has 'filepath',			# full name of file including path
    is => 'ro', 
    isa => 'Str',
    writer => '_set_filepath',	# For tetsing only DEBUG - comment out
    required => 1;

 has 'stats',			# stats array - not live version, last time updated or created
    is => 'ro',
    isa => 'ArrayRef[Int]',
    writer => '_set_stats';

has 'isreadable',		# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isreadable';

has 'isdir',			# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isdir';

has 'isfile',			# not live version
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isfile';

#   
# Fix up the args to new to allow passing the filename as the only arg
# If using options, must use longer version
#
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    # if ( @_ == 1 && !ref $_[0] ) {
    #     return $class->$orig(filepath => $_[0] );
    # }
    # else {
    #     return $class->$orig(@_);
    # }
    
    my %args = @_;
    my $filepath =$args{filepath};

    if (! -e $filepath){
	die "constructor failed - tried to create Node of non-existent file: $filepath";
    }

    return $class->$orig(@_);;
};


#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my ($self)=shift( @_);
    # my $args_ref = shift(@_);

    # Always checks stats - assumes file always exists on creation.
    $self->update_stat;

    return
}

#
# Todo
# * if already exisists - return a list of what changed
# * save old values somewhere so can move in the tree?
#
 
sub update_stat {
    my ($self)=shift( @_);

    my $filepath =  $self->filepath;
    # die "File Obj Stat Update failed - file does not exist:".$self->filepath if ! $self->isexist;

    # Update the logical values
    $self->_set_isreadable(-r $filepath);
    $self->_set_isdir(-d $filepath);
    $self->_set_isfile(-f $filepath);

    # my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
    my @stats = stat(_);	# retruns stats for last file checked with a -x command
    $self->_set_stats(\@stats);
}

sub size {
    my $self = shift(@_);
    
    my @stats = @{$self->stats};
    my $size = $stats[7];
    return($size);
}

sub mtime {
    my $self = shift(@_);
    
    my @stats = @{$self->stats};
    my $mtime = $stats[9];
    return($mtime);
}

sub mtime_str {
    my $self = shift(@_);
        
    return(Time::localtime::ctime($self->mtime));
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

# Note this one doesn't use a regular expression becuase want name with extension
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


# my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
my @stat_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
    

# 
# Check that two files are the same - maybe different disks, names - but contents same
# Check: isdir, isfile, size & md5 for files
# makes no sense for dirs
#

sub isequal {
    my $self   =shift(@_);
    my $other = shift(@_);

    if (!$other->isa('MooNode')){
	die "Tried to use isequal on non node object";
    }

    # Collect a list of what attributes changed
    my @changes;

    push(@changes, "isdir") if ($self->isdir != $other->isdir);
    push(@changes, "isfile") if ($self->isfile != $other->isfile);
    push(@changes, "size") if ($self->size != $other->size);
        
    return @changes;
}

#
# is changed
# Check to see if the new version of a file on disk is same as old version
# Check: filepath, isdir, isfile, isreadable, dev, inode, size, mtime, ctime
# Calls isqual for some of the checks
#

sub ischanged {
    my $self   =shift(@_);
    my $other = shift(@_);

    my @changes = $self->isequal($other);

    push(@changes, "filepath") if ($self->filepath ne $other->filepath);
    push(@changes, "isreadable") if ($self->isreadable != $other->isreadable);

    # OK need to check stats
    my @self_stats =  @{$self->stats};
    my @other_stats = @{$other->stats};

    # Check dev, ino, mtime, ctime
    # return a string
    foreach (0..1, 9..10){
	if ($self_stats[$_] != $other_stats[$_]){
	    push(@changes, $stat_names[$_]);
	}
    }
    
    return @changes;
}

#
# Check if changed on disk - minimal check
# Check to see if the version of a file on disk is same as object
# Check: filepath, isdir, isfile, isreadable, dev, inode, size, mtime, ctime
# Might be able to optimize based on ctime / mtime match
#

sub isdiskchanged {
    my $self   =shift(@_);
    my $filepath = $self->filepath;

    my @changes;

    if (! $self->isexist){
	push(@changes, "deleted");
	return (@changes);
    }
    
    #
    # Do we need to check? If other values change  -we will need to re-stat
    # Yes - this will help determine what to do...
    #
    push(@changes, "isreadable") if ($self->isreadable != -r $filepath);
    push(@changes, "isdir") if ($self->isdir != -d $filepath);
    push(@changes, "isfile") if ($self->isfile != -f $filepath);

    # stat file - make a few quick checks
    my @self_stats =  @{$self->stats};
    my @new_stats = stat(_);

    # Check dev, inode, size, mtime, ctime
    foreach (0..1, 7, 9..10){
	if ($self_stats[$_] != $new_stats[$_]){
	    push(@changes, $stat_names[$_]);
	}
    }

    return @changes;
}


sub dump {
   my $self = shift(@_);
 
   print "File: ", $self->filename, "\n";
   print "\tSize: ", $self->size, "\n";
   print "\tExt:  ", $self->ext, "\n";
   print "\tPath: ", $self->path, "\n";
   print "\tDir:  ", true($self->isdir), "\n";
   print "\tFile: ", true($self->isfile), "\n";
   print "\tRead: ", true($self->isreadable), "\n";
   print "\tStat: ", join(', ',  @{$self->stats} ), "\n";

   print "\n";
   print "\tAtime: ", Time::localtime::ctime(@{$self->stats}[8]), "\n";
   print "\tMtime: ", Time::localtime::ctime(@{$self->stats}[9]), "\n";
   print "\tCtime: ", Time::localtime::ctime(@{$self->stats}[10]), "\n";
}
   
sub dump_raw {
   my $self = shift(@_);

    # Moose semi unfriendly - uses raw access to class variables... may break in future
    print "INFO: Dump Raw: File: ", $self->filename, "\n";

    my %atributes = (isfile => 'Bool', isdir => 'Bool', isreadable => 'Bool', stats =>'ArrayRef');

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

