#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
# Using Dir Object
#
# ToDo
# * add check premissions
# * make checks do all the mistakes of a type in a name, not just first one
# * Fix number of files fixed vs number problems remaining
# * add args for print, fix, debug

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()

use lib '.';
use FileParse qw(check_file_name);
use MooDir;

#
# Open current directory and create a list of files to scan
#
my $debug = 0;

my $status_print = 1; # Print message if status >= this number
my $status_fix = 1;    # rename if status <= this number
my $nerror = 0;


my $dir_check = pop (@ARGV);
say "Scanning: $dir_check";

chdir($dir_check);
opendir(my $dh, ".");
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

my $nfixed = 0;

# for debug only do first N  files
if ($debug >= 1){
    my $end = 10;
    $end = min($end, $#filenames);                                       
    @filenames = @filenames[0..$end];
}

say "Files: ", join(", ", @filenames) if ($debug >= 2);

foreach my $filename (@filenames){
    say "Checking: $filename" if ($debug >= 2);;

    # $orginalname = $filename;
    # my $status = 99;

    #
    # repeat until fixed - but limit changes
    #
    for(my $i = 1; $i <= 4; $i++){
	say "Check $i: $filename" if ($debug >= 3);
	my($status, $message, $newname) = check_file_name($filename);
	last if ($status == 0);
	
	if ($status >= $status_print){
	    say "File: $filename" if ($i == 1);
	    say "    $message Status: $status";
	    print "\tBefore:$filename\n";
	    print "\tAfter :$newname\n" if ($status <= 2);
	}
	if  ($status > 0 && $status <= $status_fix){
		print "\tDo rename\n" if $status >= $status_print;
		rename($filename, $newname);
	}

 	last if ($status >= 3);	#  fatal - status = 3, exit loop, can't fix
        $filename = $newname;
    }

    #
    # Add code to really fix!
    #
}

# print "Number Files Fixed: $nfixed\n";

# exit;

