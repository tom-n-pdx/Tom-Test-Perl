#
# Program.pl to test greetings
#

use strict;
use warnings;

# Get the contents from Greetings.pl 
require "./Greetings.pl";

print "English:    ", hello("en"), "\n"; 		# Prints "Hello"
print "Australian: ", hello("en-au"),"\n"; 		# Prints "G’day"

