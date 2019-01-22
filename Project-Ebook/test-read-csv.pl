#!/usr/bin/env perl
#
# Read lib genesis csv file
#
# ToDo

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code



my @headers = qw(ID	Title	Volume	Series	NA1	Author	Year	Edition	Publisher	City	Pages	Pages	Language	NA2	Library	Library Issue	ISBN	ISSN	ASIN	NA3	LBC	DDC	LLC	DOI	GoogleID	OpenLibraryID	Commentary	DPI	Color	Clean	Landscape	Paginated	Scanned	Bookmarked	OCR	Size	Extension	MD5_Hash	NA5	NA6	Path	NA7	Date_Added	Date_Modified	Cover_Path	Tag);




my $data_filepath;
# $data_filepath = "/Users/tshott/Downloads/_ebook/_data/_libgen_content_2018.08.25-test.csv";
$data_filepath ="/Users/tshott/Downloads/_ebook/_data/libgen_content_2018_10_20.csv";

use Text::CSV;
my @rows;

# Lib Genesis needs allow_lose_escape to prevent  error: CSV_XS ERROR: 2023 - EIQ - QUO character not allowed @ rec 372 pos 108 field 4

my $csv = Text::CSV->new( { sep_char => ',', binary => 1, auto_diag => 1,  allow_loose_escapes => 1});
# my $csv = Text::CSV->new( { sep_char => ',', binary => 0, auto_diag => 1});

open my $FH, "<:encoding(UTF-8)", $data_filepath;

while (<$FH>) {
    
    # chomp;
    # say;
    $csv->parse($_);
    my $recno = $csv->record_number ();
    last if $recno > 10000;

    my @fields = $csv->fields;
    
    next unless defined $fields[12] &&  $fields[12] eq "English";

    my $value = $fields[0];
    # say "Row: $recno - ", $value if $value;
}

# use Parse::CSV;

# my $csv = Parse::CSV->new( file => $data_filepath);

# while ( my $array_ref = $csv->fetch ) {
#     # Do something...
#     # say @$array_ref[1];
# }
