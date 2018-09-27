#
# Example from Moose Manual - Intro
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


#
# Package Person
#
package Person;
use Moose;
 
has 'first_name' => (
    is  => 'rw',
    isa => 'Str',
);
 
has 'last_name' => (
    is  => 'rw',
    isa => 'Str',
);
 
no Moose;
__PACKAGE__->meta->make_immutable;

package User;
 
use DateTime;
use Moose;
 
extends 'Person';
 
has 'password' => (is  => 'rw', isa => 'Str');
 
has 'last_login' => (is      => 'rw', isa     => 'DateTime', handles => { 'date_of_last_login' => 'date' });
 
sub login {
    my $self = shift;
    my $pw   = shift;
 
    return 0 if $pw ne $self->password;
 
    $self->last_login( DateTime->now() );
 
    return 1;
}
 
no Moose;
__PACKAGE__->meta->make_immutable;

package main;
 
my $person = Person->new(first_name => 'Example', last_name  => 'User');
say "His name is ", $person->last_name;

use User;
 
my $user = User->new(
  first_name => 'Example',
  last_name  => 'User',
  password   => 'letmein',
);
 
$user->login('letmein');
 say $user->date_of_last_login;

#
# Test Meta
#
my $meta = User->meta();

say "\nAttributes";
for my $attribute ( $meta->get_all_attributes ) {
    print $attribute->name(), "\n";
 
    if ( $attribute->has_type_constraint ) {
        print "  type: ", $attribute->type_constraint->name, "\n";
    }
}
 
say "\nMethods";
for my $method ( $meta->get_all_methods ) {
    print $method->name, "\n";
}

