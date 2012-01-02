#!/usr/bin/perl

# pagerank.pl by HM2K (c) 2011 (Updated: 06/10/11)
#		Downloaded from http://pagerank.phurix.net/

# Description: Calculates the Checkhash and returns the Google PageRank
# Usage: ./pagerank.pl <query>

use strict;
use warnings;

sub getpagerank {
	my $q = shift;
	#settings

#	my $url = 'http://toolbarqueries.google.com/tbr?client=navclient-auto&ch=%s&features=Rank&q=info:%s';
#	my $url = 'https://www.google.com/webhp?hl=en#sclient=psy-ab&hl=en&site=webhp&source=hp&q=james+shott';
	my $url = 'http://scholar.google.com/scholar?q=james+shott&hl=en&btnG=Search&as_sdt=1%2C38';

	my $seed = "Mining PageRank is AGAINST GOOGLE'S TERMS OF SERVICE. Yes, I'm talking to you, scammer.";
	my $result = 0x01020345;
	my $len = length($q);
	for (my $i=0; $i<$len; $i++) {
		$result ^= ord(substr($seed,$i%length($seed))) ^ ord(substr($q,$i));
		$result = (($result >> 23) & 0x1ff) | $result << 9;
	}
	my $ch=sprintf("8%x", $result);
	$url = sprintf($url,$ch,$q);
	use LWP::UserAgent;

	my $ua = LWP::UserAgent->new;
	$ua->agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:9.0) Gecko/20100101 Firefox/9.0");
    my $res = $ua->get($url);
	$res=$res->decoded_content;
	
	# debug
	print "$res\n";

	return substr($res, rindex($res, ':')+1);
}

#print getpagerank(shift);
print getpagerank("www.pdx.edu");

