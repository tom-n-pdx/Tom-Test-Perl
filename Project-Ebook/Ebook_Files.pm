#
# Supports Ebook_Files object  -a File Object
#

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

# use Test::More;
use NEXT;
use Digest::MD5;
# use Digest::MD5::File qw( file_md5_hex );
 
use File::Spec;
use File::Basename;
use Scalar::Util qw(looks_like_number);


package Ebook_Files;

sub new {
    my ($class, %args) = @_;
    my $self = {};
    bless($self, $class);

    $self->_init(%args);

    return $self;
}

sub _init {
    my ($self, %args) = @_;

    # Call all parents using NEXT module - even in diamond calls easy parent oncly once
    $self->NEXT::DISTINCT::_init(%args);

    # Check Options
    my $calc_md5 = defined $args{"calc-md5"} ? $args{"calc-md5"} : 1; # default is yes
    # print "Calc-md5: $calc_md5\n";
    $self->{_calcmd5} = $calc_md5;



    # Class-specific initialisation. 
    my $filepath = $args{filepath};
    $self->{_filepath} = $filepath;

   # Fill in all basic file info
   $self-> update_stat;
 
    if ($calc_md5){
	$self->update_md5;
    }
}


# Standard Methods
sub size {
    my ($self) = pop(@_);
    return $self->{_size};
}

# Standard Methods
sub md5 {
    my ($self) = pop(@_);
    return $self->{_md5};
}

sub filepath {
    my ($self) = pop(@_);
    return($self->{_filepath});
}

sub filename {
    my ($self) = pop(@_);
    my  ($name,$path,$suffix) = File::Basename::fileparse($self->{_filepath});
    return($name);
}

sub fileparse {
    my ($self) = pop(@_);
    return(File::Basename::fileparse($self->{_filepath}, qr/\.[^.]*/));
}

sub update_stat {
    my ($self) = pop(@_);

    # Add Create Time
    # mdls system command?
    # stat -f %SB
    # stat -f "Access (atime): %Sa%nModify (mtime): %Sm%nChange (ctime): %Sc%nBirth  (Btime): %SB" 
    # GetFileInfo
    # 
    my $filepath = $self->{_filepath};
    $self->{_isdir}  = -d $filepath;

    # access, modify, change
    # my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat(_);
    my @stats = stat(_);	# retruns stats for last file checked with a -x command
    
    ($self->{_dev}, $self->{_ino}) = @stats[0..1];
    ($self->{_size}, $self->{_atime}, $self->{_mtime}, $self->{_ctime})  = @stats[7..10];

    return $self;
}

sub update_md5 {
    my ($self) = pop(@_);

    my $filepath = $self->{_filepath};
  

    if (-d $filepath){
	warn "tried to md5 dir file:$filepath";
    } else {
	open (my $fh, '<', $filepath) || die "Can't open file $! file: $filepath";
	binmode($fh);
	my $ctx = Digest::MD5->new;
	$ctx->addfile($fh);
	my $md5 = $ctx->hexdigest;
	close($fh);

	$self->{_md5}   = $md5;
    }

    # Return the updated object. 
    return $self;
}

sub is_equal {
    my $self   = pop(@_);
    my $other = pop(@_);

    # if (class($other) ne "Ebook_files"){
    # 	warn "ERROR: tried to check class ", class($other), " against Ebook_files";
    # 	return;
    # }

    my @changes;
    my @check_atribues = ("_dev", "_ino", "_size", "_mtime", "_ctime"); # all numeric

    foreach (@check_atribues){
	push(@changes, $_) if (defined $self->{$_} && $other->{$_} && $self->{$_} != $other->{$_});
    }
 
    @check_atribues = ("_filepath", "_md5"); # all strinf
    foreach (@check_atribues){
	push(@changes, "_md5") if (defined $self->{"_md5"} && $other->{"_md5"} && $self->{"_md5"} ne $other->{"_md5"});
    }

   return @changes;
}
1;

