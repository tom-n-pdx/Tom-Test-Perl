#!/usr/bin/env perl
#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP::Simple;
# use HTML::TokeParser;
use HTML::TreeBuilder;

my $url = "https://www.pdx.edu/";


my $html   = get($url);
# my $stream = HTML::TokeParser->new(\$html);

my $root = HTML::TreeBuilder->new_from_content($html);
my %images;

foreach my $node ($root->find_by_tag_name('img')) {
    $images{ $node->attr('src') }++;
}


foreach my $pic (sort keys %images) {
    print "$pic\n";
}
