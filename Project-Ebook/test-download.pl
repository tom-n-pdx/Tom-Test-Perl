#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use LWP::Simple;

# test file to download from book genesis
# staring url http://libgen.io/book/index.php?md5=ECAA9AB472349C93A8EB6BA475EFF37C
#    libgen download http://booksdl.org/get.php?md5=ecaa9ab472349c93a8eb6ba475eff37c&key=1E16PNWRXG2CRH91
#    Libgen.pw https://dnld.ambry.cx/download/book/5a8969aa3a044638e67158c4
#    Gen.lib.rus.ec http://download.library1.org/main/2178000/ecaa9ab472349c93a8eb6ba475eff37c/Phillip%20Johnson%20%28auth.%29%20-%20%20Make%20Your%20Own%20Python%20Text%20Adventure_%20A%20Guide%20to%20Learning%20Programming-Apress%20%282018%29.pdf
#    

my $url;
$url = "http://booksdl.org/get.php?md5=ecaa9ab472349c93a8eb6ba475eff37c&key=1E16PNWRXG2CRH91";
# $url = "https://dnld.ambry.cx/download/book/5a8969aa3a044638e67158c4";
# $url = "http://download.library1.org/main/2178000/ecaa9ab472349c93a8eb6ba475eff37c/Phillip%20Johnson%20%28auth.%29%20-%20%20Make%20Your%20Own%20Python%20Text%20Adventure_%20A%20Guide%20to%20Learning%20Programming-Apress%20%282018%29.pdf";

# my $url = 'http://marinetraffic2.aegean.gr/ais/getkml.aspx';
my $file = 'Phillip Johnson (auth.) -  Make Your Own Python Text Adventure_ A Guide to Learning Programming (2018, Apress).pdf';

# Works
my $rc = getstore($url, $file);
my $bool = is_success($rc) ? "Pass" : "Fail";
say "Code:$rc Success:$bool";


# 200 - sucess
# 500, 501 - fail - 501 maybe bad user agent relate for libgen.pw
