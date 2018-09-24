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



package Ebook_Files;

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless($self, $class);

    $self->_init(@args);

    return $self;
}

sub _init {
    my ($self, %args) = @_;

    # Call all parents using NEXT module - even in diamond calls easy parent oncly once
    $self->NEXT::DISTINCT::_init(%args);

    # Class-specific initialisation. 
    my $filepath = $args{filepath};
    $self->{_filepath} = $filepath;

   # Fill in all basic file info
   $self-> update_stat;
 
    # calc md5 option
    my $calc_md5 = defined $args{"calc-md5"} ? $args{"calc-md5"} : 1; 
    $self->{_calcmd5} = $calc_md5;
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

    my $md5;

    if (-d $filepath){
	warn "tried to md5 dir";
	$md5 = 0;
    } else {
	open (my $fh, '<', $filepath) || die "Can't open file $! file: $filepath";
	binmode($fh);

	my $ctx = Digest::MD5->new;
	$ctx->addfile($fh);
	$md5 = $ctx->hexdigest;

	close($fh);
    }

    $self->{_md5}   = $md5;

    # Return the initialised object. 
    return $self;
}

1;

