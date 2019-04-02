#!/usr/bin/env perl
#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP;

my $browser = LWP::UserAgent->new( );
$browser->credentials("www.example.com:80", "music", "fred" =>"l33t1");
my $response = $browser->get("http://www.example.com/mp3s");

