#!/usr/bin/env perl

#
# Test Scan for Library Genesis Files
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use File::Basename;

#
# ToDo - expand ~ in dir path
#



sub files_scan_dir {
    my ($dir_path, @args) = @_;
    my @files;

    # Open dir & Scan Files
    opendir(my $dh, $dir_path);
    my @filepaths = readdir $dh;
    closedir $dh;

    @filepaths = grep($_ !~ /^\./, @filepaths);		    # remove . files from last
    @filepaths = map($dir_path.'/'.$_, @filepaths);	    # make into absoule path         

    # print "List files: ", join("\n", @filepaths), "\n";

    foreach (@filepaths) {
	if (!-f $_ && !-d $_) {
	    warn "SKIP non-standard file $_\n";
	    next;
	}

	if (! -r $_){
	    warn "WARN: Can't open file $_\n";
	    next;
	}

	# Create File Object
	# rewrite - so can do checks inside object and return error if problem?
	my $obj = Ebook_Files->new("filepath"=>$_, @args);
	push(@files, $obj);
    }
    
    return @files;
}

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

    my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);

    # If exist - grab series off front
    if ($basename =~ /^\s*\[(.*?)\s*\]\s*(.*)/){
	$series = $1;
	# print "\tSeries:$series:\n";
	$basename = $2;
	# print "\tRest:$basename:\n";
    }

    if ($basename =~ /^(.*?) \- (.*)/){
	$author = $1;
	# print "\tAuthor:$author:\n";
	$basename = $2;
	# print "\tRest:$basename:\n";
    }
    
    if ($basename =~ /^(.*?)\s*(\(.*)/){
	$title = $1;
	$basename = $2;

	# Check Subtitle
	if ($title =~ /^(.*?)\s*_+\s*(.*)/){
	    $title = $1;
	    $subtitle = $2;
	}
	
	# print "\tTitle:$title:\n";
	# print "\tSubtitle:$subtitle:\n" if defined $subtitle;
	# print "\tRest:$basename:\n";
    }

    if ($basename =~ /\(\s*(\d+)\s*(.*)\)\s*(.*)$/){
	$date = $1;
	#print "\tDate:$date:\n";
	$date_rest = $2;
	#print "\tRest:$basename:\n";

	# Problms with suffix - defined but blank
	if (defined $3 && $3 ne ""){
	    $suffix = $3;
	    #print "\tSufix:$suffix:\n";
	}
	if ($date_rest =~ /\s*\,\s*(.*)/){
	    $publisher = $1;
	    #print "\tPublisher:$publisher:\n";
	}
    }

    
    # Print everything

    my $total_defined = 3;
    # my $total_defined = 0 + defined $series + defined $author +  defined $title + defined $subtitle + defined $date + defined $publisher + defined $suffix;

    if ($total_defined >= 3 ){

	say "$filename";

	print "\tSeries:$series:\n" if defined $series; 
	print "\tAuthor:$author:\n" if defined $author;
	print "\tTitle:$title:\n" if defined $title;
	print "\tSubtitle:$subtitle:\n" if defined $subtitle;
	print "\tDate:$date:\n" if defined $date;
	print "\tPublisher:$publisher:\n" if defined $publisher;
	print "\tSufix:$suffix:\n" if defined $suffix;
    
	say "\n";
    }

    return;
}



