#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use Text::CSV_XS;

#
# Todo
#
my $debug = 0;
my $errors = 0;
my $english_count = 0;
my %error_type;

# setup Txt::CSV to read from csv file
my $csv = Text::CSV_XS->new ({
    auto_diag => 1,
    diag_verbose => 1, 
    binary    => 1,                                     # Need to parse the unicode file
    escape_char => "\\",                          # Need to handle quoted quotes in strings - Error 2023
});

# On Error, ignore & continue
$csv->callbacks(error => \&ignore_csv_error); 

my $datadir = "/Users/tshott/Downloads/_ebook/_data";
my $datafile;
# $datafile = "/Users/tshott/Downloads/_ebook/_data/libgen_content_2019.01.18.rar";
$datafile= "libgen_content_2018.12.28.rar";
# $datafile = "libgen_content_2019.01.18.csv";
# $datafile = "/Users/tshott/Downloads/_ebook/_data/libgen_content_2019.01.18.test.csv";

my $datapath = $datadir.'/'.$datafile;

my $cmd =  "< $datapath";
if ($datapath =~ /\.rar$/){
    $cmd = "unrar p -inul $datapath|";
}
open(my $fh, $cmd);
binmode($fh, ":encoding(UTF-8)");

while(<$fh>){
    chomp;

    #
    # Broken rcords in file - the lines ending with \ are broken
    #
    # Keep concatinating lines until find line that does not end in \
    while (/\\$/){
	# say "Fix Rec $. ";
	s/\\$//;
	my $temp = <$fh>;
	$_ = $_.$temp;
    }

    $csv->parse ($_);
    my @fields = $csv->fields;
    
    # Assume short number of fields becuase extra carrage returninserted  into record
    # This is safty code to check for errors - should not trigger
    # If short record, skip
    if ($#fields != 46){
	say "WARN: Rec: $. Num Fields: $#fields";
	say;
	say " ";
	$errors++;

	next;
    }

    my $id        = $fields[0] + 0;
    my $md5     =  $fields[37];
    my $title     = $fields[1];
    my $vol      = $fields[2];
    my $series  = $fields[3];
    my $author = $fields[5]; 

    my $date_str =  $fields[6];
    my $date = undef;
    if ($date_str =~/(\d{4})/){ 
	$date = $1 + 0;
	if ($date < 1000 || $date > 2019){
	    # say "$id Invalid Date: $date md5:$md5";
	    $date = undef;
	} 
    }

    my $edition =  $fields[7];
    my $pub      =  $fields[8];
    my $lang     =  $fields[12];
    my $isbn     =  $fields[16];
    my $size      =  $fields[35];
    my $ext       =  $fields[36];
 
    if ($lang =~ /english/i  && 0){

	print "ID:         $id  ";
	# say "Title:      $title";
	# say "Series:    $series"; 
	# say "Vol:        $vol";
	# say "Author:   $author";
	say "Date:       $date";
	# say "Edition:    $edition";
	# say "Pub:        $pub";
	# say "Lang:       $lang";
	# say "ISBN:       $isbn";
	# say "Size:       $size";
	# say "Ext:        $ext";
	# say "MD5:        $md5";

	# say "";
    }
    

    $english_count++ if defined $lang and $lang =~ m/English/i;

    say "$. - $english_count - $errors" if ($. % 100000 == 0);
    last if  ($errors >= 5);
    # last if  ($english_count >= 500);
    # last if ($. >= 200000);
}

say "";

# close($fh);

say "Count: $. - English: $english_count - Errors:$errors";

if ($errors > 0){
    say "";
    say "Errors";
    foreach my $err (keys(%error_type)) {
	say "$err $error_type{$err}";
    }
}

exit;

sub ignore_csv_error
{
    my ($err, $msg, $pos, $recno, $fldno) = @_;
    $csv->SetDiag (0);
    say "Rec: $recno Field: $fldno Error: $err $msg";
    say;
    say " ";
    $error_type{$err}++;
    $errors++;
    return;
} 
