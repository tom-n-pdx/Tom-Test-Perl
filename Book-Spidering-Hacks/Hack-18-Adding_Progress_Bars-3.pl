#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
$|++;   			# Autoflush

use LWP;
use HTTP::Date;
# use Time::localtime;            # Printing stat values in human readable time
use Term::ProgressBar;

my $url       = 'http://disobey.com/';
# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://libgen.io/search.php?mode=last';
# my $url       = 'http://classify.oclc.org/classify2/';
# my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire
# my $url         = 'https://www.google.com/';

my @urls = ( #'http://disobey.com/', 
    # 'http://disobey.com/amphetadesk/',
    # 'http://libgen.io/search.php?mode=last',
    'http://classify.oclc.org/classify2/',
    # 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'
);


# Many URL's don't provide content length

	 
# our downloaded data
my $final_data = 0;  # our downloaded data.
my $total_size;      # total size of the URL.
my $progress;        # progress bar object.
my $next_update = 0; # reduce ProgressBar use.

# loop through each URL.
foreach my $url (@urls) {
    print "Downloading URL at ", substr($url, 0, 40), "...\n";

    my $ua = LWP::UserAgent->new(  );
    
    # Get just header
    my $result         = $ua->head($url);
    my $remote_headers = $result->headers;
    $total_size = $remote_headers->content_length;
    # say "Total Size: ", $total_size // "undefined";

    # initialize our progress bar.
    $progress = Term::ProgressBar->new(
	{count => $total_size,
	 ETA   => 'linear'}
    );

    $progress->minor(0);           # turns off the floating asterisks.
    $progress->max_update_rate(1); # only relevant when ETA is used.


    # now do the downloading.
    my $response = $ua->get($url, ':content_cb' => \&callback );

    # top off the progress bar.
    $progress->update($total_size);
    # say "\n";
}

exit;

# per chunk.
sub callback {
   my ($data, $response, $protocol) = @_;
   $final_data .= $data;

   # reduce usage, as per example 3 in POD.
   $next_update = $progress->update(length($final_data))
       if length($final_data) >= $next_update;
}

