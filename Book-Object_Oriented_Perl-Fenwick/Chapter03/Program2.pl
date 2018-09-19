#
# Program.pl to test greetings
# Rewritten to use package import


use strict;
use warnings;

# Get the contents from Greetings.pl - can't use use
require "./Greetings2.pl";

print "Greetings2 version: ", $Greetings2::VERSION, "\n\n";

print "English:    ", Greetings2::hello("en"), "\n"; 		# Prints "Hello"
print "Australian: ", Greetings2::hello("en-au"),"\n"; 		# Prints "G’day"

# This calls the hello() subroutine in our main package 
# (below), printing "Greetings Earthling". 
print hello(),"\n";


# Another version hello in main
sub hello { 
	return "Greetings Earthling"; 
}
