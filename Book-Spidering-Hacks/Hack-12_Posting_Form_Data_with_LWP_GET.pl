#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use URI;

#
# To query google must fake user agent
#

my $browser = LWP::UserAgent->new;
# Set default user agent
$browser->agent('Mozilla/4.76 [en] (Win98; U)');


my $url = URI->new( 'http://www.google.com/search' );

# the pairs of GET data
$url->query_form(
    'h1'    => 'en',
    'num'   => '100',
    'q'     => 'three blind mice',
);

my $response = $browser->get($url);
die "Can't get $url -- ", $response->status_line unless $response->is_success;


#
# If site uses POST form input - must search source HTML for info
# <form method="POST" action="/process">
# <input type="hidden" name="formkey1" value="value1">
# <input type="hidden" name="formkey2" value="value2">
# <input type="submit" name="go" value="Go!">
# </form>


# So need to use post method to submit URL
# $response = $browser->post( $url,
#     [
#      formkey1 => value1, 
#      formkey2 => value2, 
#      go => "Go!"
#      ...
#     ],
# );

