#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
# Using Dir Object
#
# ToDo
# * fix _(1) ->_v11
# * add check dir to scan exists
# * move fix file into sub so can run as part of tree search
# * add check premissions
# * make checks do all the mistakes of a type in a name, not just first one
# * Fix number of files fixed vs number problems remaining
# * Use no colide rename!

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use Getopt::Long;

use lib '.';
use FileParse qw(check_file_name);
use MooNode::MooDir;


use utf8;
use Text::Unidecode;

# try this
# use Unicode::Normalize;
# my $decomposed = NFKD( $test );
# $decomposed =~ s/\p{NonspacingMark}//g;




# Enable utf8 output in print
# binmode(STDOUT, ":utf8");


#
# Parse Args
# * Need to define vars before parse args
#
my $debug = 0;
my $status_print = 2; # Print message if status >= this number
my $status_fix = 0;    # rename if status <= this number

GetOptions (
    'debug=i' => \$debug,
    'print=i'   => \$status_print,
    'fix=i'      => \$status_fix,
);

say "Debug: $debug";
say "Print: $status_print";
say "Fix: $status_fix";


#
# Open current directory and create a list of files to scan
#



# my $nerror = 0;

# my $dir_check = pop (@ARGV);
foreach my $dir_check (@ARGV){

    say "Scanning: $dir_check";

    chdir($dir_check);
    opendir(my $dh, ".");
    my @filenames = readdir $dh;
    closedir $dh;

    @filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
    @filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

    # my $nfixed = 0;

    # for debug only do first N  files
    if ($debug >= 1){
	my $end = 10;
	$end = min($end, $#filenames);                                       
	@filenames = @filenames[0..$end];
    }

    say "Files: ", join(", ", @filenames) if ($debug >= 2);

    foreach my $filename (@filenames){
	say "Checking: $filename" if ($debug >= 2);;
	next if $filename =~ /.part$/; # skip partial downloads

	if (! -r -w $filename){
	    say "\nFile: $filename";
	    say "    Not RW";
	    last;
	}

	#
	# repeat until fixed - but limit changes
	#
	for(my $i = 1; $i <= 4; $i++){
	    say "Check $i: $filename" if ($debug >= 3);
	    my($status, $message, $newname) = check_file_name($filename);
	    last if ($status == 0);
	
	    if ($status >= $status_print) {
		say "\nFile: $filename" if ($i == 1);
		say "    $message Status: $status";
		print "\tBefore:$filename\n";
		print "\tAfter :$newname\n" if ($status <= 2);
	    }
	    if ($status > 0 && $status <= $status_fix) {
		print "\tDo rename\n" if $status >= $status_print;
		rename($filename, $newname) if (!-e $newname);
	    }

	    last if ($status >= 3);	#  fatal - status = 3, exit loop, can't fix
	    $filename = $newname;
	}

    }

}
