#
# Object Oriented Perl - Extended for overloading
#
package PlayingCard;

use strict;
use warnings;

use overload (
    q{""}     => "as_string",
    "<=>"  => "compare"
);

sub compare {
    my ($this, $that, $reversed) = @_;

    unless (UNIVERSAL::isa($that, "PlayingCard")){
	die("Attempt to compare card to non-card");
    }

    ($this, $that) = ($that, $this) if $reversed; 

    # May not work face cards
    return ($this->{_value} <=> $that->{_value});
}

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

sub as_string {
    my $self = shift;
    my $string = "$self->{_value} of $self->{_suit} "; 
    return $string;
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

