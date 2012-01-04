#!/usr/bin/perl
#

#
# One shot program to screen scape the ISI journal list
#
#
# Info - 58187 journals
#        27439 duplicates !! need to check
#
# ToDo
# Better format output - clean up - use some kind of formated output so aligned - longest short journal name?
# How deal with mult aprevations of same journal?
# * only problem for ISI -> Google
# * could try all...
# Need database abrev -> journal, journal -> abrev

use strict;
use warnings;

use LWP::UserAgent;     # fetch web page
use HTML::Entities;     # translate &amp, etc

#
# Iterate thru list 0-9 & A-Z
# 

my @letters = ("0-9", "A" .. "Z");
my $base_url = "http://images.webofknowledge.com/WOK46/help/WOS/";

# Iterate through all pages of abreveations
foreach my $letter ( "0-9", "A" .. "Z" ){
#foreach my $letter ( "0-9", "A" ){
    my $url = $base_url.$letter.'_abrvjt.html';
#   print "$url\n";

	my $ua = LWP::UserAgent->new;
#	$ua->agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:9.0) Gecko/20100101 Firefox/9.0");
    my $res = $ua->get($url);
	$res=$res->decoded_content;

    my $journal = '';
    my $abrev   = '';
    my %journal;
    my @lines = split /\n/, $res;
    foreach (@lines){
        $_ = decode_entities($_);

#        print $_,"\n";

        if (/\<DT\>\s*(.*)/){
            $journal = $1;
        }

        if (/\<DD\>\s*(.*)/){
            $abrev = $1;
   
            if ($journal{$abrev}){
 #               print "Dup A:$abrev\tJ:$journal\n";
            } else{
                $journal{$abrev} = $journal;
            }
   
           print "$abrev\t$journal\n";
        }
    }
	
	# debug
#	print "$res\n";


}

exit;

