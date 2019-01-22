#!/usr/bin/env perl
#
# Read lib genesis csv file
#
# ToDo

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code
use utf8;                          # Allow utf8 in source text
binmode STDOUT, ":utf8";

my $test = "Vous avez aimé l'épée offerte par les elfes à Frodon";
my $decomposed;
say "Test Before: $test";


# No - doesn't work
use Unicode::Normalize;
$decomposed = NFKD( $test );
say "After Decompose: $decomposed";


$decomposed =~ s/\p{NonspacingMark}//g;
# No - doesn't work - get weird characters in output


# No - doesn't work
# use Text::Unidecode;
# $decomposed = unidecode($test);

# Slightly differen
# use Unicode::Normalize;

# $test =~    s/\xe4/ae/g;  ##  treat characters ä ñ ö ü ÿ
# $test =~    s/\xf1/ny/g;  ##  this was wrong in previous version of this doc    
# $test =~    s/\xf6/oe/g;
# $test =~    s/\xfc/ue/g;
# $test =~    s/\xff/yu/g;

# $decomposed = NFD($test);

# $decomposed =~ s/\pM//g;         ##  strip combining characters
# $decomposed =~ s/[^\0-\x80]//g;  ##  clear everything else

#
# 3rd try
#

#use Text::Undiacritic qw(undiacritic);
# binmode(STDIN, ":utf8");
# binmode(STDOUT, ":utf8");
#$decomposed = undiacritic($test);



say "Test After: $decomposed";

