#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use URI;

# Maybe better use worldcat? https://www.worldcat.org/advancedsearch

# Start Building spider for classifier


# URL for classifier web site
my $url = 'http://classify.oclc.org/classify2';

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

# Test for if can find content
if ($Response->content =~ m/WebDewey/i) {
    print "The web site contains WebDewey!\n";
} else {
    print "Can't find WebDewey\n"; 
}

#
# Test submit ISBN via GET
# * Can ommit start rec
#
# Search by ISBN
# Example URL http://classify.oclc.org/classify2/ClassifyDemo?search-standnum-txt=978-1-4302-2793-9&startRec=0
#
# Search by title author
# Example URL http://classify.oclc.org/classify2/ClassifyDemo?search-title-txt=Beginning%20Perl&search-author-txt=Lee&startRec=0


my $isbn = "978-1-4302-2793-9";

# Build GET data
$url = URI->new( "http://classify.oclc.org/classify2/ClassifyDemo" );

# the pairs:
$url->query_form(
    'search-standnum-tx'  => $isbn,
#    'startRec'            => 0
);

$Response = $Browser->get($url);
die "Can't get $url -- ", $Response->status_line unless $Response->is_success;

