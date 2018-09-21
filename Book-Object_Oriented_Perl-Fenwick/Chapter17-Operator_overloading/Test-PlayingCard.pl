#
# Program to test playing cards class
#


use strict;
use warnings;
#use List::Util qw/shuffle/;

use lib '.';
use PlayingCard;

my $card1 = PlayingCard->new("Ace", "Spades");
print "Suit is: ", $card1->get_suit, "\n";
print "Card Count: ", PlayingCard->card_count, "\n";

my $card2 = PlayingCard->new("King", "Spades");
print "Suit is: ", $card2->get_suit, "\n";
print "Card Count: ", PlayingCard->card_count, "\n";


# Invoke Class method
my @deck = PlayingCard->new_deck();
 
# Shuffle...
#@deck = shuffle @deck;

 # Deal one card each...
my $my_card   = @deck[1];
my $your_card = @deck[2];

print "My Card: $my_card \n";
print "Your Card: $your_card \n";


# And compare...
if ($my_card > $your_card) {
    print "I win!\n";
} elsif ($my_card < $your_card) {
    print "I lose.\n";
} else {
    print "We draw. Isn’t that nice?\n";
}
print("First Card in Deck: ", $deck[0], "\n");

print "Card Count: ", PlayingCard->card_count, "\n";
 

