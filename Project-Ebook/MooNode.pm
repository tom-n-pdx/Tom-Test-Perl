#
# Supports Ebook_Files object  -a File Object
#
# Base file subclase for files.
# 
# ToDo
# * exists on disk method
# * mtime string and numeric function
# * add buld args check?
# * print class of object in dump

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code
use File::Basename;         # Manipulate file paths
use Time::localtime;

package MooNode;
use Moose;
use Data::Dumper qw(Dumper);           # Debug print

has 'filepath',
    is => 'ro', 
    isa => 'Str',
    required => 1;

 has 'stats',
    is => 'ro',
    isa => 'ArrayRef[Int]',
    writer => '_set_stats';

has 'isreadable',
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isreadable';

has 'isdir',
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isdir';

has 'isfile',
    is => 'ro',
    isa => 'Bool',
    writer => '_set_isfile';

   
#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my ($self)=shift( @_);
    my $args_ref = shift(@_);

    # Always checks stats - assumes file exists always
    $self->update_stat;

    return
}


sub update_stat {
    my ($self)=shift( @_);

    my $filepath =  $self->filepath;
    die "File Obj Stat Update failed - file does not exist:".$self->filename if !-e $filepath;

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
# 1. second object must be same class
# 2. check everything but atime - access time not realevent
# 3. does NOT check md5 sig  -can't use for dir or unreadable mode
#
sub isequal {
    my $self   = pop(@_);
    my $other = pop(@_);

    if (!$other->isa('MooNode')){
	die "Tried to use isequal on non node object";
    }

    # Collect a list of what attributes changed
    my @changes;

    if ($self->filepath ne $other->filepath){
	push(@changes, "filepath");
    }

    if ($self->isdir != $other->isdir){
	push(@changes, "isdir");
    }
    
    if ($self->isfile != $other->isfile){
	push(@changes, "isfile");
    }
    
    if ($self->isreadable != $other->isreadable){
	push(@changes, "isreadable");
    }
    
    # OK need to check stats
    my @self_stats =  @{$self->stats};
    my @other_stats = @{$other->stats};

    # my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
    my @stat_names = qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks);
    
    # Check dev, ino, size, mtime, ctime
    # return a string
    foreach (0..1, 7, 9..10){
	if ($self_stats[$_] != $other_stats[$_]){
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
   print "\tStat: ", join(', ',  @{$self->stats}), "\n";

   print "\n";
   print "\tAtime: ", Time::localtime::ctime(@{$self->stats}[8]), "\n";
   print "\tMtime: ", Time::localtime::ctime(@{$self->stats}[9]), "\n";
   print "\tCtime: ", Time::localtime::ctime(@{$self->stats}[10]), "\n";
}
   
sub dump_raw {
   my $self = shift(@_);

    # Moose semi unfriendly
    print "INFO: Dump Raw: File: ", $self->filename, "\n";

    my %atributes = ('isfile' => 'Bool', 'isdir' => 'Bool', 'isreadable' => 'Bool', 'stats'=>'ArrayRef');

    my @keys = sort keys(%$self);
    foreach (@keys){
	my $type = $atributes{$_} || "String";
	my $string = $$self{$_};
	$string = true($string) if ($type eq "Bool");
	$string = join(', ',  @{$string}) if ($type eq "ArrayRef");
       
	printf  "\t%-10s %s\n", $_, $string;
    }
}


1;

