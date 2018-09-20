#
# Program to test playing cards class
#


use strict;
use warnings;
# use Scalar::Util qw(weaken);	# Need weak ref to obj

use lib '.';
use PlayingCard;

{
    my $card1 = PlayingCard->new("Ace", "Spades");
    print "Suit is: ", $card1->get_suit, "\n";
    print "Card Count: ", PlayingCard->card_count, "\n";

    my $card2 = PlayingCard->new("King", "Spades");
    print "Suit is: ", $card2->get_suit, "\n";
    print "Card Count: ", PlayingCard->card_count, "\n";
}

# 2nd Ref keeps object alive
print "Card Count after Scope: ", PlayingCard->card_count, "\n";

#
# try weak refrences
#

print "\n\nTest Weak Refrences\n";

my $card_ref;
{
    my $card = PlayingCard->new("Ace", "Spades");
    $card_ref = \$card;
   #  weaken($card_ref);
    

    print "Card Count after allocate: ", PlayingCard->card_count, "\n";

}
print "Card Count after block end: ", PlayingCard->card_count, "\n";





# Invoke Class method
my @deck = PlayingCard->new_deck();
print("\n\nFirst Card in Deck: ", $deck[0], "\n");

print "Card Count: ", PlayingCard->card_count, "\n";
 

