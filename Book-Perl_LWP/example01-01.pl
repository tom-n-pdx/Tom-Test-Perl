#!/usr/bin/env perl
#!/usr/bin/env perl -CA
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

use LWP::Simple;



my $pdx = get("https://www.pdx.edu/");
my $count = 0;
$count++ while $pdx =~ m{psu}gi;
print "count pdx: $count\n";



