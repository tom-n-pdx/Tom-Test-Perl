#
# Program to test playing cards class
#


use strict;
use warnings;

use lib '.';
use PlayingCard;

my $card = PlayingCard->new("Ace", "Spades");

print "Suit is: ", $card->get_suit, "\n";
 

