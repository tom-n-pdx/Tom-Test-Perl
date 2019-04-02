#!/usr/bin/env perl
#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP::Simple;
use HTML::TokeParser;


my $url = "https://www.pdx.edu/";


my $html   = get($url);
my $stream = HTML::TokeParser->new(\$html);


my %image  = ( );

while (my $token = $stream->get_token) {
    # Is S (sart) of tag & tag is img
    if ($token->[0] eq 'S' && $token->[1] eq 'img') {
	# store src value in %image
	$image{ $token->[2]{'src'} }++;
    }
}

foreach my $pic (sort keys %image) {
    print "$pic\n";
}
