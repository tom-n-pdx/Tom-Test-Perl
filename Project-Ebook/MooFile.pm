#
# Supports Ebook_Files object  -a File Object
#
#
# ToDo
# * add md5 clac
# * changed on disk method - is equal?
# * exists on disk method
# * is equal to another object?


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


# use Digest::MD5;
use Digest::MD5::File;
 # use Scalar::Util qw(looks_like_number);
use Data::Dumper qw(Dumper);           # Debug print

package MooFile;
use Moose;
extends 'MooNode';

has 'md5',
    is => 'ro',
    isa => 'Str',
    writer => '_set_md5';

   
#
# Initilization gets called after obj created - do sanity checks
# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my ($self)=shift( @_);
    my $args_ref = shift(@_);

    my $filepath =  $self->filepath;
   
    die "File Obj Construction failed - file is a not readable: ".$self->filename if !$self->isreadable;
    die "File Obj Construction failed - file is not a standard file: ".$self->filename if !$self->isfile;
    # If not a standard file - know it's not a dir
    # die "File Obj Construction failed - file is a dir: ".$self->filename if $self->isdir;

    my $opt_update_md5 = defined $$args_ref{'opt_update_md5'} ? $$args_ref{'opt_update_md5'} : 1;
    if ($opt_update_md5){
	$self->update_md5;
    }
    return
}


sub update_md5 {
    my ($self)=shift( @_);

    my $digest = Digest::MD5::File::file_md5_hex($self->filepath);
    $self->_set_md5($digest);

    return;
}

#
# Need to extend node dumper to include MD5 if present
#
sub dump {
   my $self = shift(@_);
 
   # First call my parents dump
   $self->SUPER::dump();

   # Now print the md5 value
   my $string = $self->md5 ? $self->md5 : "";
   print "\n\tMD5: ", $string, "\n";

}


1;

