#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use HTTP::Date;
# use Time::localtime;            # Printing stat values in human readable time
# use Compress::Zlib;
use LWP::RobotUA;

# my $url       = 'http://disobey.com/';
# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://libgen.io/search.php?mode=last';
# my $url       = 'http://classify.oclc.org/classify2/';
# my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire
my $url         = 'https://www.google.com/';

# Classifier data different if using robot agent, allowed, but different
# libgen.io forbids robots value
# dlfeb.com still just dies, with user agent & robots no content, with normal agent & user agent ok
# Google works with robot - but retruns crap

my $browser   = LWP::UserAgent->new;

# Robot Version user agent
# my $browser = LWP::RobotUA->new('SuperBot/1.34', 'tom.n.pdx@gmail.com');
# $browser->delay(7/60); # Requests every 7 seconds

$browser->agent('Mozilla/4.76 [en] (Win98; U)'); # Required cloudfire

say "Test URL: $url";
my $response  = $browser->get( $url );


print "Status: ", $response->status_line, "\n";

say "Content Type: ", $response->content_type // "Undefined";

say "Last Modified(Epoch): ", $response->last_modified // "Undefined", "  ", time2str($response->last_modified);

say "Title: ", $response->title;

