#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
$|++;   			# Autoflush

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
my $total_size;  # total size of the URL.

# your animation and counter.
my $counter; 
my @animation = qw( \ | / - );

# loop through each URL.
foreach my $url (@urls) {
    print "Downloading URL at ", substr($url, 0, 40), "...";

   my $ua = LWP::UserAgent->new(  );
    
    # Get just header
    my $result = $ua->head($url);
    my $remote_headers = $result->headers;
    $total_size = $remote_headers->content_length;

    # now do the downloading.
    my $response = $ua->get($url, ':content_cb' => \&callback );
}

# per chunk.
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;
   print progress_bar( length($final_data), $total_size, 25, '=' );
}

# wget-style. routine by tachyon
# at http://tachyon.perlmonk.org/
sub progress_bar {
    my ( $got, $total, $width, $char ) = @_;
    $width ||= 25; $char ||= '=';
    my $num_width = length $total;
    sprintf "|%-${width}s| Got %${num_width}s bytes of %s (%.2f%%)\r", 
        $char x (($width-1)*$got/$total). '>', 
        $got, $total, 100*$got/+$total;
}





# per chunk.
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;
   # print ".";

   print "$animation[$counter++]\b";
   $counter = 0 if $counter == scalar(@animation);

}
