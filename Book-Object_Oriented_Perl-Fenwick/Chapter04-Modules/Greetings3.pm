#
# Chapter 3 Sample Code
#
# Provides the hello() subroutine, allowing for greetings 
# in a variety of languages. English is used as a default 
# if no language is provided.
# 
# Changed to be Module

package Greetings3;

use strict;
use warnings;

# Externally Accessabl Package Variable
our $VERSION = '1.01';

# Exectued during load - before main runs
print "Finished loading Greetings* module\n";



my %greeting = ( 
	en 		=> "Hello", 
	'en-au' => "G'day", 
	fr 		=> "Bonjour", 
	jp 		=> "Konnichiwa", 
	zh 		=> "Nihao", 
);

sub hello { 
	my $language = shift || "en";
	my $greeting = $greeting{$language} or die "Don’t know how to greet in $language";
	return $greeting;
}

# Must end with true 
1;


