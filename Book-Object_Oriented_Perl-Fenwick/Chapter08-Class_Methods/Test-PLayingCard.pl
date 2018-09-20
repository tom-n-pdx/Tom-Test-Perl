#
# Program to test playing cards class
#


use strict;
use warnings;

use lib '.';
use PlayingCard;

my $card1 = PlayingCard->new("Ace", "Spades");
print "Suit is: ", $card->get_suit, "\n";
print "Card Count: ", PlayingCard->card_count, "\n";

my $card2 = PlayingCard->new("King", "Spades");
print "Suit is: ", $card->get_suit, "\n";
print "Card Count: ", PlayingCard->card_count, "\n";


# Invoke Class method
my @deck = PlayingCard->new_deck();
print("First Card in Deck: ", $deck[0], "\n");

print "Card Count: ", PlayingCard->card_count, "\n";
 

