#
# Object Oriented Perl - Chapter 5 Example
#
package PlayingCard;

use strict;
use warnings;

# Class Variables
my $Cards_created = 0;


# The constructor function (a class method) 
sub new { 
	my ($class, $value, $suit) = @_;

	# Create an anonymous hashref and naively fill in our fields.
	my $self = { _value => $value, _suit => $suit };
	$Cards_created++;
	
	return bless($self,$class);
}

#
# Destructor
# * decrement the number of cards
sub DESTROY {
        my ($self) = @_;
	# print "Card Destroyed\n";
	$Cards_created--;
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


#
# Class Method
#

sub new_deck {
    # my ($class) = @_;		# This is the class which was invoked. 
    # Check was involked with Class Not Object
    my ($class,@args) = @_;
    ref($class) and die "Class method ’new_deck’ called on object";

    my @deck;

    # NOTE: Use $class->new - in case this is inherited method
    foreach my $suit (qw/hearts spades diamonds clubs/) { 
	foreach my $value (2..10, qw/jack queen king ace/) {
	    push @deck, $class->new( $value, $suit );
	}
    }

    return @deck;
}

sub card_count {
                  return $Cards_created;
}

1;  # Required for module

