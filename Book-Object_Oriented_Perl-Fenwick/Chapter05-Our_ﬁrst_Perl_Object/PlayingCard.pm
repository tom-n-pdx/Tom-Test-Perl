#
# Object Oriented Perl - Chapter 5 Example
#
package PlayingCard;

use strict;
use warnings;

# The constructor function (a class method) 
sub new { 
	my ($class, $value, $suit) = @_;

	# Create an anonymous hashref and naively fill in our fields.
	my $self = { _value => $value, _suit => $suit };
	
	return bless($self,$class);
}

# An object method returning the value of this card’s suit 
sub get_suit { 
	my ($self) = @_;
	return $self->{_suit};
}

# An object method returning the face value of this card 
sub get_value { 
	my ($self) = @_;
	return $self->{_value};
}


1;  # Required for module

