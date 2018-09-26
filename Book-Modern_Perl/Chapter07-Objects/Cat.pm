#
# Modern Perl - Chapter 7 - Objects
#

use strict;
use warnings;

use Modern::Perl '2016'; 
use autodie;
use Moose;

package Cat { 
    use Moose;
 
    # has 'name' => ( 
    # 	is => 'ro',  
    # 	isa => 'Str',

    # 	# advanced Moose options; perldoc Moose
    # 	# init_arg => undef,                      # Debug - fails
    # 	# lazy_build => 1,
    # );

    has 'name', is => 'ro', isa => 'Str'; 
    has 'age', is => 'ro', isa => 'Int'; 
    has 'diet', is => 'rw';

    sub meow {
	my $self = shift; 
	say 'Meow!';
    }



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
		    age => 8,
		    diet => 'Sea Treats' ); 

say $fat->name, ' eats ', $fat->diet;

# automagic set method
$fat->diet( 'Low Sodium Kitty Lo Mein' ); 
say $fat->name, ' now eats ', $fat->diet;

# RO value - no set version
#$fat->age(10);


1; # End Module

