#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use HTTP::Date;
















my $browser = LWP::UserAgent->new;
$browser->agent('Mozilla/4.76 [en] (Win98; U)');

#
# Cookies
#

# In memory for sesion ony
$browser->cookie_jar({});


# Cookies on disk
# $browser->cookie_jar( HTTP::Cookies->new(
#     'file' => 'cookies.lwp',              # where to read/write cookies
#     'autosave' => 1,                      # save it to disk when done
# ));




my $url = URI->new( 'http://www.google.com/search' );

# the pairs of GET data
$url->query_form(
    'h1'    => 'en',
    'num'   => '100',
    'q'     => 'three blind mice',
);

my $response = $browser->get($url);
die "Can't get $url -- ", $response->status_line unless $response->is_success;

