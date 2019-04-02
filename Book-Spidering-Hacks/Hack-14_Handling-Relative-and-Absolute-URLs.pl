#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use URI;
use HTTP::Cookies;


my $browser = LWP::UserAgent->new;

my $url = 'http://www.cpan.org/RECENT.html';
my $response = $browser->get($url);

die "Can't get $url -- ", $response->status_line unless $response->is_success;

my $html = $response->content;

# Response received is in relative URL's
# while( $html =~ m/<A HREF=\"(.*?)\"/g ) { 
#     print "$1\n"; 
# }

# Use URI new_abs to get absolue URL
while( $html =~ m/<A HREF=\"(.*?)\"/g ) {
    print URI->new_abs( $1, $response->base ) ,"\n";
}
