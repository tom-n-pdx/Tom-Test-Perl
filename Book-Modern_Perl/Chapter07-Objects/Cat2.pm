#
# Modern Perl - Chapter 7 - Objects
#

use strict;
use warnings;

use Modern::Perl '2016'; 
use autodie;
use Moose;

# Can define a role
# 
package LivingBeing { 
    use Moose::Role;
    requires qw( name age diet ); # Required classes for anything that is a LivingBeing Role
}


# Can Put Code into a role
package CalculateAge::From::BirthYear { 
    use Moose::Role;
    has 'birth_year',
	is => 'ro',
	isa => 'Int',
	default => sub { (localtime)[5] + 1900 };

    sub age {
	my $self = shift;
	my $year = (localtime)[5] + 1900;
	return $year - $self->birth_year; 
    }
}



package Cat { 
    use Moose;
 
    has 'name', is => 'ro', isa => 'Str'; 
    has 'diet', is => 'rw';

    # has 'birth_year', 
    # 	is => 'ro', 
    # 	isa => 'Int',
    # 	default => sub { (localtime)[5] + 1900 };
    
    # MUST be after the attribue decleration
    with 'LivingBeing', 'CalculateAge::From::BirthYear';

    sub meow {
	my $self = shift; 
	say 'Meow!';
    }

    # Cat could override role method
    # sub age {
    # 	my $self = shift;
    # 	my $year = (localtime)[5] + 1900;
    # 	return $year - $self->birth_year;     # Use accessor - not direct
    # }
 

}

package main;

my $brad = Cat->new;

my $fuzzy_alarm = Cat->new; 
$fuzzy_alarm->meow for 1 .. 3;


for my $name (qw( Tuxie Petunia Daisy )) { 
    my $cat = Cat->new( name => $name ); 
    say "Created a cat for ", $cat->name;
}

my $fat = Cat->new( name => 'Fatty', 
		    'birth_year' => 2000,
		    diet => 'Sea Treats' ); 

say $fat->name, ' is ', $fat->age, ' & eats ', $fat->diet;

# automagic set method
$fat->diet( 'Low Sodium Kitty Lo Mein' ); 
say $fat->name, ' now eats ', $fat->diet;

# Check object has a Role
say 'Fluffy is Alive!' if $fat->DOES( 'LivingBeing' );


# RO value - no set version
#$fat->age(10);


1; # End Module

