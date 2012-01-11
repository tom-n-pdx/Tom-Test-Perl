#!/usr/local/bin/perl

#
# Utility for test ISI citation parse
# REad in citations & parse them
# It's hard coded for now to use the patent search ISI cittaions file
#
# Problems to fix
# In Press Tags - > J9 value?
# Things like 'picmet' refrenced multuple ways
# Look for citations where author, year, J9 match - but vol / page don't match
# Remove multuple spaces in author, J9
# Search for names that are close? Journal names that are close?
#  
# Fuzzy Match author or journal?
# http://search.cpan.org/~jhi/String-Approx-3.26/Approx.pm
# http://search.cpan.org/~markm/Text-Soundex-3.03/Soundex.pm
# http://aspell.net/metaphone/
# http://www.catalysoft.com/articles/StrikeAMatch.html
# http://www.perl.com/pub/2003/07/15/nocode.html
# Search thru all refrences
# * find delta simularity from every item in every refrence
# * print ones the highest score?
# * high weight if volume, page match
# 
# Is it important to get correct journal name?
#
# Run all through http://www.crossref.org/guestquery/
# Get DOI
# If no DOI - try DOI lookup?
# First build all db - then can do DOI on important articles
# If no long name, can use DOI to get long name
# 
#

use strict;
use warnings;

binmode STDOUT, ":utf8";

#print "Extract all CR fileds to stdout from input filese\n";

my $data_dir  = "/u/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";
#my $data_dir = "/Users/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";

my $data_file = "Patent_Search_Refs_Citations.out";

$data_file = $data_dir.'/'.$data_file;

open( my $fh, $data_file ) || die ("Can't open $data_file $! \n");
binmode $fh, ":utf8";

my %citations;
my %info;
my %author;
my %author_info;
my %journal;

while(<$fh>){
#	print;
	chomp($_);
	&parse_citation_str($_);
}

#foreach my $key (sort keys %citations){
#	my $data = $citations{$key};
#	next if $data <= 1;
#	print $key, ',', $data;
#	print "\t\t",$info{$key},"\n";
#}

#foreach my $key (sort keys %author){
#	my $data = $author{$key};
##	next if $data <= 1;
#	print $key, ',', $data,"\t",$author_info{$key},"\n";
#}

foreach my $key (sort keys %journal){
	my $data = $journal{$key};
	next if $data <= 1;
	print $key, ',', $data,"\n";
}


exit;


sub parse_citation_str {

	my $citation_str = shift(@_); 

	my $author = 'BAD0';
	my $year   = -1;
	my $journal= 'BAD0';

	my @citation_data = split( /,\s*/, $citation_str);

	if ($#citation_data < 0){
		print "Line too short\nRAW:$citation_str\n";
		return;
	}	

	# Parse Author
	# First field is Author or a Year
	if ( $citation_data[0] !~ /\d+/){
		$author = shift @citation_data; 
		$author = lc($author);
	} else {
#		print "Illegal Author - ";
#		print "0:",$citation_data[0],"\n"; 
		$author = '';
	}

	# Parse Year
	# Optional Second field is a Year
	if ( ($#citation_data >= 0) && $citation_data[0] !~ m/[^0-9.]/){
		$year = shift @citation_data;
	} else {
#		print "Illegal Year - ";
#		print "0:",$citation_data[0],"\n"; 
#		print "RAW:$citation_str\n";
		$year = 0;
	}
	
	# Parse Journal
	if ( $#citation_data >= 0 ){
		$journal = shift @citation_data;
		$journal = lc($journal);
	} else {
#		print "Illegal Journal - ";
#		print "0:",$citation_data[0],"\n"; 
#		print "RAW:$citation_str\n";
		$journal = '';
	}

	# Cleanup rest data
	if ($#citation_data >= 0 && $citation_data[-1] =~ /DOI/){
		pop(@citation_data);
	}

	# Hack
	# What if no author? Skip
	return if ($author eq '');
	
	# What if no year? Skip
	return if ($year == 0);
	
	# What if no journal? Skip
	return if ($journal eq '');
	
	my $data = '';
	if ($#citation_data >=0){
		$data .= join(',',@citation_data);
	}
	$data .= ';';

	my $key = $author.','.$year.','.$journal;
	$citations{$key}++;	
	$info{$key} .= $data;
	
	$author{$author}++;
	$author_info{$author} .= $journal.';';
	
	$journal{$journal}++;
	
}