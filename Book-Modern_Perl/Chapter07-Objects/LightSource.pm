#
# Modern Perl - Chapter 7 - Objects
#

use strict;
use warnings;

use Modern::Perl '2016'; 
use autodie;
#use Moose;
# use Moose::Meta::Class;

use Data::Dumper;           # Debug print


package LightSource { 
    use Moose;
    # my $meta = __PACKAGE__->meta;

    has 'candle_power', 
	is => 'ro', 
	isa => 'Int',
	default => 1;

    has 'enabled', 
	is => 'ro', 
	isa => 'Bool',
	default => 0,
	writer => '_set_enabled';

    sub light {
	my $self = shift; 
	$self->_set_enabled( 1 );
    }

    sub extinguish {
	my $self = shift; 
	$self->_set_enabled( 0 );
    }
}


package SuperCandle { 
    use Moose;

    extends 'LightSource';

    has '+candle_power', default => 100;
}



package Glowstick { 
    use Moose;
    extends 'LightSource'; 

    # Override Medthod
    sub extinguish {}
}


package LightSource::Cranky { 
    use Carp 'carp';
    use Moose;
    extends 'LightSource';

    # Extend method by doing something then calling the parent method
    override light => sub { 
	my $self = shift;
	carp "Can't light a lit LightSource!" if $self->enabled; 
	super();
    };

    override extinguish => sub {
	my $self = shift;
	carp "Can't extinguish unlit LightSource!" unless $self->enabled;
	super(); 
    };
}


package main;

my $dim = LightSource->new;
say "Light is on: ", $dim->enabled;

$dim->light;
say "Light is on: ", $dim->enabled, " at ", $dim->candle_power;


my $bright = SuperCandle->new("enabled" => 1);
say "Bright Light is on: ", $bright->enabled, " at ", $bright->candle_power;
  
# Since SuperCandle extends LightSource, isa passes
say 'Looks like a LightSource' if $bright->isa( 'LightSource' );


#
# See what moose object looks like
#
say "\n\nInside look at \$bright";
say Dumper($bright);




#
# Moose supports Meta Programming
# Can minupulate code
#

# Not working - try later
# say "SuperCandle supports attribues: ", $bright->get_all_attributes;
# See perldoc Class::MOP & perldoc Class::MOP::Class
#


#
# To write cleaner code see
# MooseX::Declare 
# Moops
#

#
# Moo is a slimmer lib
# * Consider migrate code to Moo if need prformnace
#


