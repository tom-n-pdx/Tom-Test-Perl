#
# Object Oriented Perl - Chapter 17 Overloading
#
use strict;
use warnings;

package Pet;

# Overload stringification and ! 
use overload (
    q("")   => "as_string",
#    q(++) => \&praise_pet,         # Subroutine reference! - BAD  -subclass will use parent version
    q(++) => "praise_pet",         # Subroutine reference!
);

#  Simplistic constructor
sub new {
    return bless {name=> $_[1]}, shift;
}


# Used for stringification (default method) 
sub as_string {
    my $self = shift;

    my $string = "$self->{name} is my pet. "; 

    if ($self->{praise}) {
	$string .= "I have praised $self->{name} $self->{praise} ". "times today.";
    }

    return $string;
}

# Used for ++ (always used!)
sub praise_pet {
    my $self = shift;
    $self->{praise}++;
    return;
}

#
# Special case of pets, a dog class 
#
package Pet::Dog;
our @ISA = qw(Pet); # We inherit from Pet.


# Define our own stringify method 
sub as_string {
    my $self = shift;
    my $string = "$self->{name} is my dog! "; 
    if ($self->{praise}) {
	$string .= "I have praised my dog $self->{name} ". "$self->{praise} times today!";
    }
    return $string;
}

# Dogs earn double praise!
sub praise_pet {
        my $self = shift;
        $self->{praise} += 2;
        return;
    }

#
# Our main program. Uses both the above classes. package main;
# Define a generic pet, Sally
#
my $sally = Pet->new("Sally");
print "$sally\n";
# Sally is my pet.

$sally++;
print "$sally\n";
# Sally is my pet. I have praised Sally 1 times today.

$sally++;
print "$sally\n";

# Define a dog, Fido.
my $dog = Pet::Dog->new("Fido");

print "$dog\n";
# prints  Fido is my dog!

$dog++;
print "$dog\n";
# Fido is my dog! I have praised my dog Fido 1 times today!


1;

