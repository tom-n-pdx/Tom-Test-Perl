#!/usr/local/bin/perl

#
# Read in isi file & parse
#
# ISI files are two letter codes, 1 space, rest of line
# no code - continuation of earlier
#
# File starts with FN & ennds with EF
# Records starts with PT and ends with ER
#
# embedded data for fields at end
#

use strict;
use warnings;
#use feature 'state';    # Perl > 5.9.4, provides persistent varables

binmode STDOUT, ":utf8";

#
# ISI field names
# Refrence: http://images.webofknowledge.com/WOKRS54B7/help/WOS/hs_wos_fieldtags.html
#
#my %name = (
#	'TI'	=> 'Title',
#	'AU'	=> 'Author',
#	'J9'	=> 'Journal',
#	'PY'	=> 'Year',
#	'BP'	=> 'Page',
#	'VL'	=> 'Volume',
#	'DI'	=> 'DOI',
#	'CR'	=> 'Cite'
#);

# Fields to concat with ';'
	my %concat = (
		'AU' => 1,		# Author
		'AF' => 1,		# Author
		'C1' => 1,		# Author
		'EM' => 1,		# Email address
		'CR' => 1,		# Cittaions
	);

#
# Setup data fields
#

my %name;

# Data format is Field, Name, optional seperator
while (<main::DATA>){
	chomp;
	my $code;
	my $name;
	my $seperator;
	
	my $match = ($code, $name, $seperator) = split(/\s\t+/);
	if ( $match >= 2){
#		print "$code:$name\n";		
		$name{$code} = $name;
	}
	
	if ( $match >= 3){
#		$concat{$code} = $seperator;
	}
}


#my $data_dir  = "/u/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";
my $data_dir  = "/Users/tshott/git/Tom-Test-Perl/Bibliographic_IO/data";
#my $data_file = "Lee_2011_article_only_wok.isi";
#my $data_file = "Lee_2011_article_refs_wok.isi";
my $data_file = "ISI_Data/Jiao_1999-Ref.isi";


open( my $fh, $data_dir . '/' . $data_file ) || die;
binmode $fh, ":utf8";

my $code;
my $data;

# Discard first two records
my $null = <$fh>;
$null = <$fh>;
 
while(&read_record($fh)){
	
}

print "End\n";

exit;


#
# Need to know if add ';' to field as grow or not
#
sub read_record {

	my %field;
	my $line;
	my $code = '';
	my $last_code;
	my $data;
	

	# Read lines until get to field with PT record or end of data file

PT:	while($line = <$fh>){
		chomp $line;

		if ($line =~ /PT (.*)/){
			$code = 'PT';
			$data = $1;
			last PT;
		}
	}
		
	return if ($code ne 'PT');

	$field{$code} = $data;
		


READ: while (my $line = <$fh>){
		chomp $line;

		die "read blank line\n" if (length($line) <1 );

		$code = substr( $line, 0, 2);
		last READ if ( $code eq 'ER');  

		$code = $last_code if $code eq '  ';

		if (length($line) >= 3){
			$data = substr( $line, 3 ) if ( length($line) >= 3 );

			my $seperator = ' ';
			if ($concat{$code}){
				$seperator = '; ';
			}

			if (defined $field{$code}){
				$field{$code} .= $seperator.$data;
			} else { 
				$field{$code} .= $data;
			}
		}		

		$last_code = $code;
	}
		
	my @print = ('TI', 'AU', 'J9', 'PY', 'DI');
	foreach $code (@print){

		printf "%-40s ",$name{$code};
		
		print $field{$code} if defined $field{$code};

		print "\n";
	}
	if ($field{'CR'}){
		print "\nCITATIONS:\n";
		&parse_cite ($field{'CR'});
	}

	print "\n";	

#	print "Title: ",$field{'TI'},"\n";

	return 1;
}

#
#	Parse Cite string with ';'s to parse
#
sub parse_cite {
	my $cite_list = shift @_;
	
	my @citations = split(/;\s/,$cite_list);
	my $author;
	my $year;
	my $journal;
#	my $volume;
#	my $page;
#	my $unsp;

#
# Problem, sometimes DOI spans > 1 line; how know where cit ends?
# Need to fix DOI parse
# Some other minor problems, thesis, etc - ignore
#
	
	foreach my $cite_string (@citations) {

		# Cleanup IN PRESS dates
#		$cite_string =~ s/IN PRESS/9999,/;
				
		my $match = ($author,$year, $journal, my @cite_data) = split(/,\s/,$cite_string);

		if ($match >=3){
			print "AU:$author YE:$year J9:$journal\n";

			if ( $year !~ /\d\d\d\d/){
				warn "WARN: Cite year - $cite_string\n";
			}

			if ( $author =~ /\d\d\d\d/){
				warn "WARN: Cite author - $cite_string\n";
			}

	   } else {
			if ($cite_string !~ /10\.1/){
				warn "WARN Cite String Parse: $cite_string\n";
			}
		}
	}	
}



__END__
FN	File Name
VR	Version Number
EF 	End of File

PT 	Publication Type (J=Journal; B=Book; S=Series)
AU 	Authors										;
AF 	Author Full Name							;
BA 	Book Authors								;
CA 	Group Authors								;
GP 	Book Group Authors							;
TI 	Document Title
BE 	Editors										;
SO 	Publication Name
SE 	Book Series Title
BS 	Book Series Subtitle
LA 	Language
DT 	Document Type
CT 	Conference Title
CY 	Conference Date
HO 	Conference Host
CL 	Conference Location
SP 	Conference Sponsors
DE 	Author Keywords
ID 	Keywords Plus
AB 	Abstract
C1 	Author Address								;
RP 	Reprint Address								;
EM 	E-mail Address								;
FU 	Funding Agency and Grant Number
FX 	Funding Text
CR 	Cited References							;
NR 	Cited Reference Count
TC 	Times Cited
PU 	Publisher
PI 	Publisher City
PA 	Publisher Address
WC 	Web of Science Category
SC 	Subject Category
SN 	ISSN
BN 	ISBN
J9 	29-Character Source Abbreviation
JI 	ISO Source Abbreviation
PD 	Publication Date
PY 	Year Published
VL 	Volume
IS 	Issue
PN 	Part Number
SU 	Supplement
SI 	Special Issue
BP 	Beginning Page
EP 	Ending Page
AR 	Article Number
PG 	Page Count
DI 	Digital Object Identifier (DOI)
GA 	Document Delivery Number
UT 	Unique Article Identifier
ER 	End of Record
