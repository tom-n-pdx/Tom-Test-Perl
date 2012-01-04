#!/usr/bin/perl
#

#
# One shot program to screen scape the ISI journal list
#
# Access the ISI web of knowledge web site and screen scape the list of journals and abrevations
#
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
# Store into data file & print to output file
#

use strict;
use warnings;

use LWP::UserAgent;     # fetch web page
use HTML::Entities;     # translate &amp, etc

#
# Iterate thru the list 0-9 & A-Z
# For each letter need to grab the web page and extract the journals & abrevations
# sanple page: http://images.webofknowledge.com/WOK46/help/WOS/A_abrvjt.html
#

#my @letters = ("0-9", "A" .. "Z");
my $base_url = "http://images.webofknowledge.com/WOK46/help/WOS/";

my %journal_count;
my %abrev_count;
my $journal = '';
my $abrev   = '';


#
# Iterate through all pages of abreveations
#
foreach my $letter ( "0-9", "A" .. "Z" ){
#foreach my $letter ( "0-9", "A" ){
    my $url = $base_url.$letter.'_abrvjt.html';
#   print "$url\n";

	my $ua = LWP::UserAgent->new;
#	$ua->agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:9.0) Gecko/20100101 Firefox/9.0");
    my $res = $ua->get($url);
	$res=$res->decoded_content;

	$journal = '';
	$abrev   = '';


#
# For a web page, break down into lines and find the journal & abrevations pairs
# Very simple format so just use regular expression
#
    my @lines = split /\n/, $res;
    foreach (@lines){
        $_ = decode_entities($_);			# Convert &amp to &, etc.

        if (/\<DT\>\s*(.*)/){				# Match <DT> for journal
            $journal = $1;
        }

        if (/\<DD\>\s*(.*)/){
            $abrev = $1;					# Match <DD> for abrev
   

#            if ($journal{$abrev}){
#               print "Dup A:$abrev\tJ:$journal\n";
#            } else{
#                $journal{$abrev} = $journal;
#            }
   
      		printf "%-25s\t%s\n",$abrev, $journal;

			$journal_count{$journal}++;
			$abrev_count{$abrev}++;

 			$abrev = '';
 			$journal = '';
        }
    }
	
	# debug
#	print "$res\n";

}

# Do some journals have a count greater then 1?
print "\n\nJournal Count > 1\n";

foreach $journal (sort {$journal_count{$a} <=> $journal_count{$b}} keys %journal_count){
	if ($journal_count{$journal} > 1){
		print $journal_count{$journal}, "\t$journal\n";
	}
	
}

# Do some abrevs have a count greater then 1?
print "\n\nAbrev Count > 1\n";

foreach $abrev (sort {$abrev_count{$a} <=> $abrev_count{$b}} keys %abrev_count){
	if ($abrev_count{$abrev} > 1){
		print $abrev_count{$abrev}, "\t$abrev\n";
	}
	
}

exit;

