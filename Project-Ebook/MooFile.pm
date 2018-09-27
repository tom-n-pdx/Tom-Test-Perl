#
# Supports Ebook_Files object  -a File Object
#
#
# ToDo
# * fix combinations opt calc md5 & calc stat
# * add buld args check?
# * add md5 clac
# * changed on disk method


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use File::Basename;         # Manipulate file paths


# # use Test::More;
# use NEXT;
# use Digest::MD5;
# # use Digest::MD5::File qw( file_md5_hex );
 
# use File::Spec;
# use File::Basename;
# use Scalar::Util qw(looks_like_number);


package MooFile;
use Moose;
use Data::Dumper qw(Dumper);           # Debug print

has 'filepath',
    is => 'ro', 
    isa => 'Str',
    required => 1;

has 'size',
    is => 'ro',
    isa => 'Int',
    writer => '_set_size';

 has 'stats',
    is => 'ro',
    isa => 'ArrayRef[Int]',
    writer => '_set_stats';

 has 'md5',
    is => 'ro',
    isa => 'Str]',
    writer => '_set_md5';

    
#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my ($self)=shift( @_);
    my $args_ref = shift(@_);

    my $opt_update_stat = defined $$args_ref{'opt_update_stat'} ? $$args_ref{'opt_update_stat'} : 1;
    if ($opt_update_stat){
	$self->update_stat;

	my $opt_update_md5 = defined $$args_ref{'opt_update_md5'} ? $$args_ref{'opt_update_md5'} : 1;
	$self->update_md5;
      }
    
    return
}

sub update_stat {
    my ($self)=shift( @_);

    my $filepath =  $self->filepath;
    die "File Obj Construction failed - file does not exist:".$self->FileName if !-e $filepath;
    die "File Obj Construction failed - file is a not readable: ".$self->FileName if !-r $filepath;
    die "File Obj Construction failed - file is a dir: ".$self->FileName if -d $filepath;
    die "File Obj Construction failed - file is a standard file: ".$self->FileName if !-f $filepath;

    # my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
    my @stats = stat(_);	# retruns stats for last file checked with a -x command
    $self->_set_stats(\@stats);

    # Size most used, duplicate value
    $self->_set_size($stats[7]);
}

sub update_md5 {
    my ($self)=shift( @_);
}

#
# All the darn names of a file
# * filepath - full absolue name of file (Created by Moose)
# * path - just directory minus trailing /
# * filename - name of file including ext minus path
# * ext - file etension - NOT including the .
# * basename - minus extension - minus path
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




#     # Add Create Time
#     # mdls system command?
#     # stat -f %SB
#     # stat -f "Access (atime): %Sa%nModify (mtime): %Sm%nChange (ctime): %Sc%nBirth  (Btime): %SB" 
#     # GetFileInfo
#     # 

# sub update_md5 {
#     my ($self) = pop(@_);

#     my $filepath = $self->{_filepath};
  

#     if (-d $filepath){
# 	warn "tried to md5 dir file:$filepath";
#     } else {
# 	open (my $fh, '<', $filepath) || die "Can't open file $! file: $filepath";
# 	binmode($fh);
# 	my $ctx = Digest::MD5->new;
# 	$ctx->addfile($fh);
# 	my $md5 = $ctx->hexdigest;
# 	close($fh);

# 	$self->{_md5}   = $md5;
#     }

#     # Return the updated object. 
#     return $self;
# }

# sub is_equal {
#     my $self   = pop(@_);
#     my $other = pop(@_);

#     # if (class($other) ne "Ebook_files"){
#     # 	warn "ERROR: tried to check class ", class($other), " against Ebook_files";
#     # 	return;
#     # }

#     my @changes;
#     my @check_atribues = ("_dev", "_ino", "_size", "_mtime", "_ctime"); # all numeric

#     foreach (@check_atribues){
# 	push(@changes, $_) if (defined $self->{$_} && $other->{$_} && $self->{$_} != $other->{$_});
#     }
 
#     @check_atribues = ("_filepath", "_md5"); # all strinf
#     foreach (@check_atribues){
# 	push(@changes, "_md5") if (defined $self->{"_md5"} && $other->{"_md5"} && $self->{"_md5"} ne $other->{"_md5"});
#     }

#    return @changes;
# }


1;

