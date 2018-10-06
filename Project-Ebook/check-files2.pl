#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
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

#
# Open current directory and create a list of files to scan
#
my $debug = 2;

my $status_print = 0; # Print message if status >= this number
my $status_fix = 0;    # rename if status <= this number
my $nerror = 0;


my $dir_check = pop (@ARGV);
say "Scanning: $dir_check";

opendir(my $dh, $dir_check);
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

my $nfixed = 0;

# for debug only do first N  files
my $end = 10;
$end = min($end, $#filenames);                                       
@filenames = @filenames[0..$end];

say "Files: ", join(", ", @filenames) if ($debug >= 2);


foreach my $filename (@filenames){
    say "Checking: $filename" if ($debug >= 2);;

    my ($status, $message, $newname, $orginalname, $filestatus);
    $orginalname = $filename;
    $filestatus = 0;

    #
    # repeat until fixed - but limit changes
    #
    for(my $i = 1; $i < 5; $i++){
	($status, $message, $newname) = check_file_name($filename);
	$filestatus = max($filestatus, $status);
	last if ($status == 0);

	# OK - if non-zero status had problem, only count for first fix
	$nfixed++ if ($status != 0 && $i == 1);

	# Only print info on more serious errors
	# If any status > $sttaus_print start printing
	# Might miss a first status 1 fix
	if ($filestatus >= $status_print){
	    say "File: $filename" if ($i == 1);
	    say "    $message Status: $status";
	    print "\tBefore: $filename\n";
	    print "\tAfter : $newname\n" if ($status <= 2);
	}
 	last if ($status >= 3);	#  fatal - status = 3, exit loop, can't fix

	$filename = $newname;
    }

    #
    # Add code to really fix!
    #
#    if  ($filestatus > 0 && $filestatus <= $status_fix){
# 	print "    Do rename $orginalname to $filename Status:$filestatus\n\n";
# 	# rename($orginalname, $filename) || die ("Rename error: $! $orginalname");
#     }
}

# print "Number Files Fixed: $nfixed\n";

# exit;

