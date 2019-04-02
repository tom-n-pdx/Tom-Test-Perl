#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;
use HTTP::Date;
use Time::localtime;            # Printing stat values in human readable time
use Compress::Zlib;


# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://disobey.com/';
# my $url       = 'http://libgen.io/search.php?mode=last';
# my $url       = 'http://classify.oclc.org/classify2/';
my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire


my $browser   = LWP::UserAgent->new;
$browser->agent('Mozilla/4.76 [en] (Win98; U)'); # Required cloudfire

my $response  = $browser->get( $url );

say "Test URL: $url";

print "Status: ", $response->status_line, "\n";

say "Content Type: ", $response->content_type // "Undefined";

# say "Last Modified(Epoch): ", $response->last_modified // "Undefined", "  ", Time::localtime::ctime($response->last_modified);
say "Last Modified(Epoch): ", $response->last_modified // "Undefined", "  ", time2str($response->last_modified);
say "Expires: ", $response->expires // "Undefined", "  ", time2str($response->expires);
say "Etag: ", $response->header("ETag") // "Undefined";

say "Title: ", $response->title;

# Cloudfire returns
# Access denied | dlfeb.com used Cloudflare to restrict access

if (defined $response->last_modified) {

    # my $date = "Thu, 31 Oct 2002 01:05:16 GMT"; # IN GMT?
    my $date = time2str($response->last_modified); 
    my %headers = ( 'If-Modified-Since' => $date );

    $response = $browser->get( $url, %headers );
    say "Status: ", $response->status_line;

}


# 
# Check if can generat compressed data
#
$url = 'http://www.disobey.com/';
say "\nTest Compressed UTL: $url";

my %headers = ( 'Accept-Encoding' => 'gzip; deflate' );
$response = $browser->get( $url, %headers );
print "Status: ", $response->status_line, "\n";


my $data = $response->content;
my $enc = $response->content_encoding;

if ($enc eq "gzip" or $enc eq "deflate") {
    print "Server supports $enc, woo!\n";
}

if ( my $enc = $response->content_encoding) {
    $data = Compress::Zlib::memGunzip($data) if $enc =~ /gzip/i;
    $data = Compress::Zlib::uncompress($data) if $enc =~ /deflate/i;
}
