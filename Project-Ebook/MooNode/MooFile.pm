#
# Supports Files object  -a File Object
#
#
# ToDo
# * add rename file method
# * change clalc md5 to update md5

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

   
sub BUILDARGS {
    my ($class, @original) = @_;

    my %args = MooNode::_args_helper(@original);
    my $filepath = $args{filepath};

    # If filepath defined - check is a file of some type
    if ($filepath && ! -e $filepath){
    	die "ERROR: constructor failed - tried to create Node of non-existent file: ".$filepath;
    }
    if ($filepath && ! -f $filepath){
    	die "ERROR: constructor failed - tried to create Node of non-file file: ".$filepath;
    }

    return \%args;
};

#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    my $args_ref = shift(@_);

    # option to not generate md5 but default is to create signature
    my $opt_update_md5 = $$args_ref{'opt_update_md5'}  // 1;
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
    my $digest;

    if (!$self->isreadable){
	warn "WARN: tried to get md6 sig from unredable file file: ".$self->filepath;
	return $digest;
    }

    $digest = Digest::MD5::File::file_md5_hex($self->filepath);
    if (!defined $digest){
	warn "ERROR md5 returned undefined value. filepath: ".$self->filepath;
    } else {
	$self->_set_md5($digest);
    }

    return $digest;
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
   # know self can md5 but other maybe node or dir
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
