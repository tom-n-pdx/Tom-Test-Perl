#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;

# Usefull Perl one liners
# perl -MLWP::Simple -e "getprint 'http://cpan.org/RECENT'"       - grab a quick URL

use LWP::Simple;

# Just an example: the URL for the most recent /Fresh Air/ show 
my $url = 'http://freshair.npr.org/dayFA.cfm?todayDate=current';
# my $url = 'http://www.npr.org/programs/fresh-air-TEST';
# my $url = 'http://luckylab.com';
#

my $content = get($url);
die "Couldn't get $url" unless defined $content;

#
# No error message
# Use getprint to debug.
# my $code = getprint($url);
# print("\n");


# Do things with $content:
if ($content =~ m/jazz/i) {
    print "They're talking about jazz today on Fresh Air!\n";
} else { 
    print "Fresh Air is apparently jazzless today.\n";
}

# Head is usefull to get basic info about a page
# perl -MLWP::Simple -e 'print join "\n", head "http://cpan.org/RECENT"'
#
# If successful, a HEAD request should return the content type (plain text, in this case), the document length
# (49675), modification time (1059640198 seconds since the Epoch, or July 31, 2003 at 01:29:58), content
# expiration date,

