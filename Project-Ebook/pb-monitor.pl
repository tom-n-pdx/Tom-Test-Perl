#!/usr/bin/env perl
#
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

# Run pbpaste repeatedly and output string when command changes 

my $cmd = "pbpaste -Perfer txt";
my $wait = 2;
my $last_string = "";

my %links;

while (1){
    my $string = `$cmd`;

    if ($string ne $last_string){
	$last_string = $string;
	if ($links{$last_string}){
	    say "Dupe: $string";
	} else {
	    say $last_string;
	    $links{$last_string} = 1;
	}
    }

    sleep($wait);
}
