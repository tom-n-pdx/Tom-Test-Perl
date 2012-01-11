#!/usr/local/bin/perl

#
# Utility for test ISI parse
# This utility reads a ISI standard file and outputs all the CR (cittaion) records to stdout
# It's hard coded for now to use the patent search ISI file
#
#

use strict;
use warnings;

#use feature 'state';    # Perl > 5.9.4, provides persistent varables

#binmode STDOUT, ":utf8";

#print "Extract all CR fileds to stdout from input filese\n";

my $data_dir  = "/u/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";
#my $data_dir = "/Users/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";

#my $data_file = "Lee_2011_article_only_wok.isi";
#my $data_file = "Lee_2011_article_refs_wok.isi";
#my $data_file = "Patent_Search_refs_wok.isi";
#my $data_file = "ISI_Data/Jiao_1999-Ref.isi";
my $data_file = "Patent_Search_refs_wok.isi";

$data_file = $data_dir.'/'.$data_file;

open( my $fh, $data_file ) || die ("Can't open $data_file $! \n");
binmode $fh, ":utf8";

my $last_field = '';
my $now_field  = '';

READ: while(<$fh>){
	

	next READ if length($_) < 2;
	 
	$now_field = substr($_, 0, 2);

	if ($now_field eq '  '){
		$now_field = $last_field;
	} else {
		$last_field = $now_field;
	}

	if ($now_field eq 'CR'){
		my $citation = substr($_,3);	
		print $citation;
	}
		
#	print;



}

exit;

