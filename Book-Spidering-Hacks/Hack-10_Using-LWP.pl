#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;

# Just an example: the URL for the most recent /Fresh Air/ show 
my $url = 'http://freshair.npr.org/dayFA.cfm?todayDate=current';
# my $url = 'http://www.npr.org/programs/fresh-air-TEST';
# my $url = 'http://luckylab.com';
#

# One Browser obj needed per program
my $Browser = LWP::UserAgent->new;

# need new response for each request
my $Response = $Browser->get( $url );
die "Can't get $url -- ", $Response->status_line unless $Response->is_success;

# Check content type
die "Hey, I was expecting HTML, not ", $Response->content_type unless $Response->content_type eq 'text/html';

say "Response Code: ", $Response->is_success;
say "HTTP Status:   ", $Response->status_line;
say "MIME Type:     ", $Response->content_type;

# Process the content somehow:
say " ";
if ($Response->content =~ m/jazz/i) {
    print "They're talking about jazz today on Fresh Air!\n";
} else {
    print "Fresh Air is apparently jazzless today.\n"; 
}
