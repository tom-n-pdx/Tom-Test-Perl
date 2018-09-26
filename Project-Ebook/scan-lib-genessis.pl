#!/usr/bin/env perl

#
# Test Scan for Library Genesis Files
#

#
# ToDo
# * Move all this stuff into a object
#




use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use File::Basename;

# 
# ToDo - expand ~ in dir path
#

#
# Main
#

# Open dir & Scan Files
opendir(my $dh, ".");
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

# How sort and match MacOS display order?
@filenames = sort(@filenames);

# for debug only do first N 
my $end = 100;
$end = min($end, $#filenames);                                       
@filenames = @filenames[0..$end];

foreach my $filename (@filenames){
    parse_lib_genessis($filename);
}

exit;



sub parse_lib_genessis {
    my ($filename) = pop(@_);
    my ($series, $author, $title, $subtitle, $date, $publisher, $suffix);
    my ($date_rest);
    my %values;

    my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);

    # If exist - grab series off front
    if ($basename =~ /^\s*\[(.*?)\s*\]\s*(.*)/){
	$values{series} = $1;
	# print "\tSeries:$series:\n";
	$basename = $2;
	# print "\tRest:$basename:\n";
    }

    if ($basename =~ /^\s*(.*?) \- (.*)/){
	# my $author_string = $1;
	# Call Parse Authors to convert string to the required list	
	my @authors = parse_author($1);
	
	$values{authors} = \@authors;
	# print "\tAuthors: ", join('; ', @authors),"\n";
	$basename = $2;
	# print "\tRest:$basename:\n";

    }
    
    if ($basename =~ /^(.*?)\s*(\(.*)/){
	$title = $1;
	$basename = $2;

	# Check Subtitle
	if ($title =~ /^(.*?)\s*_+\s*(.*)/){
	    $values{title} = $1;
	    $values{subtitle} = $2;
	} else {
	    $values{title} = $title;
	}
	
	# print "\tTitle:$title:\n";
	# print "\tSubtitle:$subtitle:\n" if defined $subtitle;
	# print "\tRest:$basename:\n";
    }

    if ($basename =~ /\(\s*(\d+)\s*(.*)\)\s*(.*)$/){
	$values{date} = $1;
	#print "\tDate:$date:\n";
	$date_rest = $2;
	#print "\tRest:$basename:\n";

	# Suffix
	if (defined $3 && $3 ne ""){
	    $values{suffix} = $3;
	    #print "\tSufix:$suffix:\n";
	}
	if ($date_rest =~ /\s*\,\s*(.*)/){
	    $values{publisher} = $1;
	    #print "\tPublisher:$values{publisher}:\n";
	}
    }

    
    # Print everything


    #
    # My guess is need at least 3 values to have valid file
    #
    if (scalar keys %values >= 3){

	say "$filename";

	foreach (keys %values){
	    my $string = "";
	    if ($_ eq "authors"){
		$string = join("; ", @{$values{$_}});
	    } else {
		$string = $values{$_};
	    }
	    print "\t$_ = $string\n";
	}

	say "\n";

	
    }

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

