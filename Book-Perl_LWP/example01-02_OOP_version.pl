#!/usr/bin/env perl
#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP::Simple;


my $url = "https://www.pdx.edu/";

my $browser = LWP::UserAgent->new( );
my $response = $browser->get($url);
print $response->header("Server"), "\n";



