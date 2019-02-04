#!/usr/bin/env perl

#
# Test Scan for Library Genesis Files
#

#
# ToDo
# * Delete unused code
# * Move into  a Book Generssis module
# * move crear filename into another module
# * Mov  the publisher cleanup
# * what about unicode cleanup? 
# * rework debug - only count 10 files to convert - not first 10 in dir?


use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

use List::Util qw(min max);	# Import min()
use File::Basename;
use Text::Names;                     # Pasre names into last, first name form


use lib '.';
use MooBook::MooBook;

# 
# ToDo - expand ~ in dir path
#

#
# Main
#

my $debug =0;
my $fix = 1;

my $dir_check = shift(@ARGV);
say "Scanning: $dir_check";

# Open dir & Scan Files
opendir(my $dh, $dir_check);
my @filenames = readdir $dh;
closedir $dh;

chdir($dir_check);

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep($_ !~ /\(ebook/, @filenames);	    # remove already ebook
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

# How sort and match MacOS display order?
#@filenames = sort(@filenames);



# for debug only do first N  files
if ($debug >= 1){
    my $end = 10;
    $end = min($end, $#filenames);                                       
    @filenames = @filenames[0..$end];
}

say "Files: ", join(", ", @filenames) if ($debug >= 2);

#
# Scan Files
#
foreach my $filename (@filenames){
    next if $filename =~ /\(ebook/;
    next if $filename =~ /^_/;

    my ($status, $book) = parse_lib_genessis($filename);
    if ($status){
	say "Filename: $filename";
	$book->dump;


	my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);
	
	my $basename_new = $book->title;
	$basename_new .= "- ".$book->subtitle if $book->subtitle;

	$basename_new .= " (".$book->series.")" if $book->series;

	$basename_new .= " (ebook, ";
	$basename_new .= ($book->author     || "XXXX") . ", ";
	$basename_new .= ($book->publisher || "YYYY") . ", ";
	$basename_new .= ($book->year         || "9999") . ", ";
	$basename_new .= "Orginal)";

	my $filename_new = $basename_new.$ext;
	
       	if ($fix){
	    my $version = 10;
	    while (-e $filename_new){
		++$version;
		$filename_new = $basename_new."_v".$version.$ext;
	    }
	    rename($filename, $filename_new) unless (-e $filename_new);
	}
	say "Filename New: $filename_new";
	say "\n";
    }
}

exit;


sub parse_lib_genessis {
    my ($filename) = pop(@_);
    my ($series, @authors, $title, $subtitle, $year, $publisher, $suffix);

    my ($date_rest);
    my $status = 0;
    my %values;


    my $book = MooBook->new(title => "test");

    my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);
    $_ = $basename;

    #
    # Check for ( * number * ) - if not - fail
    #
    if ($_ !~ /\(.*\d+.*\)/){
	# say "Not Genessis Lib: $filename";
	$status = 0;
	return ($status, $book);
    }

    # say "Checking Filename: $filename"; 


    #
    # First cleanup and non-stndard lib genesis stuff
    #
    # remove leading _
    s/^[_\s]*//;

    # Extract and remove trailing suffix
    if (/(.*\))(\w+?)$/){
	$_ = $1;
	$suffix = $2;
	# say "Suffix: $suffix";
    }

    # Extract leading optional series
    if (/^\s*\[\s*(.*?)\s*\]\s*(.*)\s*/){
	$series = $1;
	$_ = $2;
	#	say "Series: $series";
	$book->series($series);
    }

    # Parse out authors - title - date
    my $match = (my ($author_text, $title_text, $date_text)) = /^(.*?) - (.*?)\s*\(\s*(\d+[^\(\)]*)\)$/;
    if (! $match){
	# say "Fail Parse $filename";
	return (0, $book);
    }

    # say "DEBUG: $date_text";

    #
    # Cleanup authors list
    #
    # Issues:
    # * parseNames also removes author / editor info
    # * does not handle title - Dr / Prof.
    # * Does not handle Suffix Jr, III
    #
    # If authors seperated by _ need to split into array first
    if ($author_text =~ /_/){
    	@authors = split(/_s*/, $author_text);
	@authors = Text::Names::parseNameList(@authors);    
    } else {
    	@authors = Text::Names::parseNames($author_text);
    }
    $book->author_list(\@authors);
    
    # say "\nFilename:$filename\nAuthor: $author_text - ", join("; ", @authors);
    
    
    # 
    # Cleanup title
    #
    # Check if title with . instead of spaces - if so - replace . w/ space
    my $n_spaces = () = $title_text =~ /\s/g;
    my $n_period  = () = $title_text =~ /\./g;
    if ($n_period > $n_spaces){
    	$title_text =~ tr/./ /;
    	say "Convert . to white- White: $n_spaces Period: $n_period Rest:$_:";
    }
    
    #
    # Fixup _ in names
    #
    $title_text =~ tr/_/-/;
    
    # split into title  -subtitle
    if ($title_text =~ /^(.*\w)- (.*)/){
	$title = $1;
	$subtitle = $2;
    } else {
	$title = $title_text;
	$subtitle = "";
    }
    $book->title($title);
    $book->subtitle($subtitle);

    
    # say "\nFilename:$filename\nTitle: $title Subtitle:$subtitle";

    #
    # Parse required date & optional publisher
    #
    # split into date & publisher
    ($year, $publisher) = split(/s*,\s*/, $date_text, 2);                 # Split date, publisher on ,
    $year += 0;

    # Clean up year
    $year = 0 if ($year == 0 or $year == 9999);
    if ($year) {
    	$year += 0;
    	if ($year < 1800 or $year > 2020){
    	    warn "WARN: Year out of range $year file: $filename";
    	    return 0;
    	}
    }
    $book->year($year);

    # Clean up publisher
    if ($publisher){
    	$publisher =~ s/,//;	# remove any commas
    	$publisher = publisher_abrev($publisher);
	$book->publisher($publisher);
    } else {
	$publisher = "";
    }

    # say "\nFilename:$filename\nDate-Text:$date_text Year:$year Publisher:$publisher\n";
    #say "Filename: $filename";
    #$book->dump;
    #say "\n";
        
    return (1, $book);

}

# 
# Parse an aauthor string into  a list of authors
# format 0) First Last
# format 1) First Last, First Last
# format 2) First Last_ First Last_
# format 3) First Last and First Last
#

#
# OK - it correctly splits the list of authors
# But no idea for first author what is last name - likely last....
# It will ocasionally split a single name Last, First into two
#
sub parse_author {
    my ($author) = pop(@_);
    my @authors = [];

    if ($author =~ /_/){
	@authors = split(/_\s*/, $author);
    } elsif ($author =~ /,/){
	@authors = split(/\,\s*/, $author);
    } elsif ($author =~ /\s+and\s+/){
	@authors = split(/\s+and\s+/, $author);
    } else {
	$authors[0] = $author;
    }

    # say "\tauthor: $author";
    # say "\t",  join(":", @authors), ":\n";

    parse_author_first($authors[0]);

    return(@authors);

}

# Fix
# * Consider Company names
# * de Paz
# John Smith III
#
sub parse_author_first {
    my $author_string = pop(@_);
    my @words;
    my $last_name;
    
    # If contains a (auth.) string remove it
    if ($author_string =~ /\s*\(auth\.\)\s*/){
	$author_string =~ s/\s*\(auth\.\)\s*//;
    }
    # if contains (eds.) remove it
    if ($author_string =~ /\s*\(eds\.\)\s*/){
	$author_string =~ s/\s*\(eds\.\)\s*//;
    }


    if ($author_string =~ /\,/){
	@words = split(/\,+/, $author_string);
	$last_name = $words[0];
    } else {
	@words = split(/\s+/, $author_string);
	$last_name = $words[-1];
    }
    return($last_name);
}

sub undef_str {
    my $value = shift(@_);
    return($value // "Undef");
}

sub publisher_abrev {
    my $publisher_long = shift(@_);
    my $publisher_short = $publisher_long;

    my @publisher_regexp = (
	"Wadsworth",
	"Oxford",
	"mcgraw",
	"Oxford University Press",
	"Sage",
	"Cengage",
	"O.Reilly",
	"Packt",
	"For Dummies",
	"Palgrave Macmillan",
	"Wiley",
	"Manning",
	"dk",
	"Harvard Business School",
	"Harvard Business Review",
	"Harvard University Press",
	'Springer',
	"CreateSpace",
	"Microsoft",
	"Morgan and Claypool",
	"Penguin",
	"Cambridge University",
	"Physica-Verlag",
	"Princeton University",
	"Imperial College", 
	"Pearson",
	"Columbia University",
	"Academic Press",
	"Academic Press",
	"CRC",
	"American Mathematical Society",
	"Auerbach",
	"No Starch",
	"Information Science Reference",
	"South Western",
	"New Riders",
	"Berrett-Koehler",
	"Peachpit",
	"IT Governance Publishing",
	"Brill",
	"Dorling Kindersley",
	"Course Technology",
	"Pragmatic",
	"mit press",

    );

    my @publisher = (
	"Wadsworth",
	"Oxford",
	"McGraw-Hill",
	"Oxford",
	"Sage",
	"Cengage",
	"O'Reilly",
	"Packt",
	"Wiley",
	"Palgrave Macmillan",
	"Wiley",
	"Manning",
	"DK",
	"HBR",
	"HBR",
	"Harvard",
	"Springer",
	"CreateSpace", 
	"Microsoft",
	"Morgan & Claypool",
	"Penguin",
	"Cambridge",
	"Springer",
	"Princeton",
	"Imperial College", 
	"Pearson",
	"Columbia",
	"Academic Press",
	"Academic Press",
	"CRC Press",
	"AMS",
	"Auerbach",
	"No Starch",
	"ISR",
	"South Western",
	"New Riders",
	"Berrett-Koehler",
	"Peachpit",
	"ITgp",
	"Brill",
	"DK",

	"Course Technology",	"Pragmatic Bookshelf",
	"MIT",
	
    );

    foreach (0..$#publisher_regexp){
	my $regexp = qr/$publisher_regexp[$_]/i;

	if ($publisher_long =~ $regexp){
	    # say "Match $regexp";
	    $publisher_short = $publisher[$_];
	    last;
	}
    }
    # for (my $i = 0; $i <= $#publisher_regexp; $i++){
    # 	if ($publisher_long =~ /$publisher_regexp[$i]/){
    # 	    $publisher_short = $publisher[$i];
    # 	    last;
    # 	}
    # }
    # say "Convert $publisher_long -> $publisher_short";

    return($publisher_short);
}


