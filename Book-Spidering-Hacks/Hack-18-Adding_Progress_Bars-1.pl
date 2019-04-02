#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
$|++;

use LWP;
use HTTP::Date;
# use Time::localtime;            # Printing stat values in human readable time

my $url       = 'http://disobey.com/';
# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://libgen.io/search.php?mode=last';
# my $url       = 'http://classify.oclc.org/classify2/';
# my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire
# my $url         = 'https://www.google.com/';

my @urls = ('http://disobey.com/', 
	 'http://disobey.com/amphetadesk/',
	 'http://libgen.io/search.php?mode=last');

	 
# our downloaded data
my $final_data = undef;

# loop through each URL.
foreach my $url (@urls) {
   print "Downloading URL at ", substr($url, 0, 40), "...";

   # create a new useragent and download the actual URL.
   # all the data gets thrown into $final_data, which
   # the callback subroutine appends to.
   my $ua = LWP::UserAgent->new(  );
   $ua->agent('Mozilla/4.76 [en] (Win98; U)'); # Required cloudfire

   my $response = $ua->get($url, ':content_cb' => \&callback, );

   print "\n"; # after the final dot from downloading.
}

# per chunk.
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;
   print ".";
}
