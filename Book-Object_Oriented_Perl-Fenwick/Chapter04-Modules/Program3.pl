#
# Program.pl to test greetings
# Rewritten to use package import


use strict;
use warnings;

use lib '.';

# Get the contents from Greetings.pl - can't use use
# require "./Greetings2.pl";
use Greetings3;


print "Greetings3 version: ", $Greetings3::VERSION, "\n\n";

print "English:    ", Greetings3::hello("en"), "\n"; 		# Prints "Hello"
print "Australian: ", Greetings3::hello("en-au"),"\n"; 		# Prints "G’day"

# This calls the hello() subroutine in our main package 
# (below), printing "Greetings Earthling". 
print hello(),"\n";


# Another version hello in main
sub hello { 
	return "Greetings Earthling"; 
}
