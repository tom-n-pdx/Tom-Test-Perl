#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;

# Get my current user agent string
# http://getright.com/useragent.html
# Firefox Mozilla/5.0 (Macintosh; Intel Mac OS X 10.12; rv:56.0) Gecko/20100101 Firefox/56.0
# Chrome Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.86 Safari/537.36

# Just an example: the URL for the most recent /Fresh Air/ show 
my $url = 'http://freshair.npr.org/dayFA.cfm?todayDate=current';
# my $url = 'http://www.npr.org/programs/fresh-air-TEST';
# my $url = 'http://luckylab.com';
#


# Netscape Headers!
my @ns_headers = (
    'User-Agent'      => 'Mozilla/4.76 [en] (Win98; U)',
    'Accept'          => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png,  */*',
    'Accept-Charset'  => 'iso-8859-1,*',
    'Accept-Language' => 'en-US',
);

my @ns_headers_french = (
    'User-Agent'      => 'Mozilla/4.76 [en] (Win98; U)',
    'Accept'          => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png,  */*',
    'Accept-Charset'  => 'iso-8859-1,*',
    'Accept-Language' => 'fr',
);



# One Browser obj needed per program
my $Browser = LWP::UserAgent->new;

# Set default user agent
$Browser->agent('Mozilla/4.76 [en] (Win98; U)');

# need new response for each request
my $Response = $Browser->get( $url );
# my $Response = $Browser->get( $url , @ns_headers);
# my $Response = $Browser->get( $url , @ns_headers_french);
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

# Some sites require to know where you came from
$Response = $Browser->get($url, 'Referer' => 'http://cnn.com/url.html');
die "Can't get $url -- ", $Response->status_line unless $Response->is_success;
