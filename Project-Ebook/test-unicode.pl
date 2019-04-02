#!/usr/bin/env perl
#
# Read lib genesis csv file
#
# ToDo

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code
use utf8;                          # Allow utf8 in source text
binmode STDOUT, ":utf8";
# use utf8;

my $unicode_string;
# $unicode_string = "\N{WHITE SMILING FACE}";
# $unicode_string = "\N{U+263a}";
$unicode_string = "Vous avez aimé l'épée offerte par les elfes à Frodon";

say "Is Unicode: ", utf8::is_utf8($unicode_string) ? "Yes" : "No";
say "Test Before: $unicode_string";

my %unicode;

# Search - find all unicode
while ($unicode_string =~ m/([^[:ascii:]])/g){
    say "Found: $1";
    $unicode{$1}++;
}

say "\nUnicode Characters Found";
foreach my $char (keys %unicode){
    say "$char:  $unicode{$char}";
}





# my $decomposed =~ s/\p{NonspacingMark}//g;
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

# say "Test After: $decomposed";

