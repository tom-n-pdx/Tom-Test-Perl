#!/usr/bin/env perl

#
# Test Scan for Library Genesis Files
#

#
# ToDo
# * Use Book Obj to collect info and print
# * Delete unused code
# * Move into  a Book Generssis module
# * Mov  the publisher cleanup



use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

use List::Util qw(min max);	# Import min()
use File::Basename;
use Text::Names;                     # Pasre names into last, first name form



# 
# ToDo - expand ~ in dir path
#

#
# Main
#

my $debug = 0;

my $dir_check = pop (@ARGV);
say "Scanning: $dir_check";

# Open dir & Scan Files
opendir(my $dh, $dir_check);
my @filenames = readdir $dh;
closedir $dh;

chdir($dir_check);

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
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

    parse_lib_genessis($filename);
}

exit;


sub parse_lib_genessis {
    my ($filename) = pop(@_);
    my ($series, @authors, $title, $subtitle, $year, $publisher, $suffix);
    my ($date_rest);
    my $status = 0;
    my %values;

    my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);
    $_ = $basename;

    #
    # Check for (date..) - if not - fail
    #
    if ($_ !~ /\(\d+.*\)/){
	# say "Not Genessis Lib: $filename";
	return $status;
    }

    #
    # Parse required (date, optional publisher) optional suffix off end
    # * Parse off suffix!
    my $year_pub_str;
    ($_, $year_pub_str) = /(.*)\((.*)\)/;
    ($year, $publisher) = split(/s*,\s*/, $year_pub_str, 2);                 # Split date, publisher on ,

    
    # Clean up year
    $year = undef if ($year == 0 or $year == 9999);
    if ($year) {
	$year += 0;
	if ($year < 1800 or $year > 2020){
	    warn "WARN: Year out of range $year file: $filename";
	    return 0;
	}
    }

    # Clean up publisher
    if ($publisher){
	$publisher =~ s/,//;	# remove any commas
	$publisher = publisher_abrev($publisher);
    }
    #say "Year:", undef_str($year), " Publisher:", undef_str($publisher), " File: $filename";
  
    #
    # Parse optional series off front of name
    #
    if ($basename =~ /^\s*\[\s*(.*?)\s*\]\s*(.*)/){
	$series = $1;
	$_ = $2;
    }

    #
    # Parse required author list
    # Mostly Works - some problems with Suffix Dr/Prof. 
    # Some pronlems with Prefix III
    # Ocassional weird problems
    # Doesn't handle company names well
    #
    my $author_text;
    ($author_text, $_) = /^\s*(.*) - (.*)/;
 
    # If authors seperated by _ need to split into array first
    if ($author_text =~ /_/){
	@authors = split(/_s*/, $author_text);
	@authors = Text::Names::parseNameList(@authors);
    } else {
	@authors = Text::Names::parseNames($author_text);
    }
    #say "Author: $author_text - ", join("; ", @authors);


    #
    # Extract Title & Subtitle
    #
    # if ($basename =~ /^(.*?)\s*(\(.*)/){
    # 	$title = $1;
    # 	$basename = $2;

    # Parse off any trailing whitespace
    s/\s*$//;

    #
    # Fixup names with period instead of space
    # Count . vs white space in title
    #
    my $n_spaces = () = $_ =~ /\s/g;
    my $n_period  = () = $_ =~ /\./g;
    if ($n_period > $n_spaces){
	tr/./ /;
	say "White: $n_spaces Period: $n_period Rest:$_:";
    }

    #
    # Fixup _ in names
    #
    tr/_/-/;

    # Check Subtitle
    if (/^\s*(.*)\s*\-+\s*(.*)/){
	$title = $1;
	$subtitle = $2;
    } else {
	$title = $_;
    }
    say "Title: $title Subtitle: ", undef_str($subtitle);
    
    return;
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
	"McGraw.Hill",
	"Oxford University Press",
	"Sage",
	"Cengage",
	"O.Reilly",
	"Packt",
	"For Dummies",
	"Palgrave Macmillan",
	"Wiley",
	"Manning",
	"DK",
	"Harvard Business School",
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
    );

    foreach (0..$#publisher_regexp){
	my $regexp = qr($publisher_regexp[$_]);

	if ($publisher_long =~ /$regexp/i){
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