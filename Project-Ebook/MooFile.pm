#
# Supports Files object  -a File Object
#
#
# ToDo
# * rename file

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use Digest::MD5::File;
 # use Scalar::Util qw(looks_like_number);
# use Data::Dumper qw(Dumper);           # Debug print

package MooFile;
use Moose;
use namespace::autoclean;

extends 'MooNode';

has 'md5',
    is => 'ro',
    isa => 'Str',
    writer => '_set_md5';

   
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = @_;
    my $filepath =$args{filepath};

    if (! -f $filepath){
	die "constructor failed - tried to create File of non standard file file: $filepath";
    }

    # if (! -r $filepath){
    # 	die "constructor failed - tried to create File of nonnon-readable file: $filepath";
    # }

    return $class->$orig(@_);;
};





#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    my $args_ref = shift(@_);

    # my $filepath =  $self->filepath;
   
    # die "File Obj Construction failed - file is a not readable: ".$self->filename if !$self->isreadable;
    # die "File Obj Construction failed - file is not a standard file: ".$self->filename if !$self->isfile;
    # If not a standard file - know it's not a dir
    # die "File Obj Construction failed - file is a dir: ".$self->filename if $self->isdir;

    # option to not generate md5 but default is to create signature
    my $opt_update_md5 = defined $$args_ref{'opt_update_md5'} ? $$args_ref{'opt_update_md5'} : 1;
    if ($opt_update_md5){
	$self->update_md5;
    }
    return
}

#
# BUG: ocassional undefined MD5 value returned
# * if file is unreadable - will not fail - but produce warning
#
sub update_md5 {
    my ($self)=shift(@_);

    if (!$self->isreadable){
	warn "WARN: tried to get md6 sig from unredable file file: ".$self->filepath;
	return;
    }

    my $digest = Digest::MD5::File::file_md5_hex($self->filepath);
    if (! $digest){
	$digest = "";		# set to false, but not undef
	warn "ERROR md5 returned undefined value. filepath: ".$self->filepath;
    }
    $self->_set_md5($digest);

    return;
}

#
# Extend isequal to include check for md5 if present
#
# Can not use Moose after - we need to extend the return values
#
sub isequal {
   my $self = shift(@_);
   my $other = shift(@_);
 
   # First call parents iseqal
   my @changes = $self->SUPER::isequal($other);

   # Now check the md5 value if present
   if ($self->md5 && $other->can('md5') && $other->md5){
       push(@changes, "md5") if ($self->md5 ne $other->md5);
   }
   
   return @changes;
}



#
# Need to extend node dumper to include MD5 if present
#
sub dump {
   my $self = shift(@_);
 
   # First call parents dump
   $self->SUPER::dump();

   # Now print the md5 value
   my $string = $self->md5 || "undef";
   print "\n\tMD5: ", $string, "\n";

   return;
}

__PACKAGE__->meta->make_immutable;
1;

