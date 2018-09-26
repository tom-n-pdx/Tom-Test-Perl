#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
#
# ToDo
# * add check premissions
# * make checks do all the mistakes of a type in a name, not just first one
# * Fix number of files fixed vs number problems remaining

use Modern::Perl 2017; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use File::Basename;

#
# Open current directory and create a list of files to scan
#
opendir(my $dh, ".");
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

my $status_print = 2; # Print message if status >= this number
my $status_fix = 2;    # rename if status <= this number
my $nfixed = 0;

# for debug only do first N 
my $end = 100;
$end = min($end, $#filenames);                                       
@filenames = @filenames[0..$end];

foreach my $filename (@filenames){
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
	    say "\nFile: $filename" if ($i == 1);
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
    if  ($filestatus > 0 && $filestatus <= $status_fix){
	print "    Do rename $orginalname to $filename Status:$filestatus\n\n";
	rename($orginalname, $filename) || die ("Rename error: $! $orginalname");
    }

}

print "Number Files Fixed: $nfixed\n";

exit;

sub check_file_name {
    my($filename) = pop @_;
    my $message = "";
    my $status = 0;
    my $newname = "";

    {
	#
	# Check Extension
	#
	my  ($basename, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);

	# Check if not lowercase ext
	if (lc($ext) ne $ext) {
	    $message = "uppercase extension: $ext";
	    $newname = $basename.lc($ext);
	    $status = 1;
	    next;
	}

	my @legal_ext = ("gif", "jpg", "pdf", "chm", "djvu", "azw3", "epub", "tif", "txt", "pl");
	my $match = grep('.'.$_ eq lc($ext), @legal_ext);
	if (!$match) {
	    $message = "File ext not recognized: $ext";
	    $status = 3;
	    next;
	}

	#
	# Check basename
	#
	$_ = $basename;
	#$newname = $basename;

	# Checked balanced ()'s - worst type problem
	if (!balanced($basename)) {
	    $message = "Unbalanced parents";
	    $status = 3;
	    next;
	}
    

	#
	# Whitespace checks
	#
	if (/^\s/){
		$message = "File starts with whitespace";
		$status = 1;
		s/^\s+//;
		$newname = "$_$ext";
		next;
	}
    
	 if (/\s$/){
		$message = "File ends with whitespace";
		$status = 1;
		s/\s+$//;
		$newname = "$_$ext";
		next;
	}
    
	 if (/\s{2,}/){
		$message =  "File has repeated whitespace";
		$status = 1;
		s/\s{2,}/ /;
		$newname = "$_$ext";
		next;
	}
    

	# # Braces Checks (), []

	#
	# Need to fix - allow _[ at start of file
	 if (/\S[\(\[\{]/ && !/^_/){
		$message =  "File has no whitespace before openning brace";
		$status = 2;
		s/(\S)([\(\[\{}])/$1 $2/;
		$newname = "$_$ext";
		next;
	}

	 if (/[\(\[\{]\s/){
		$message =  "File has whitespace after openning brace";
		$status = 2;
		s/([\(\[\{])\s+/$1/;
		$newname = "$_$ext";
		next;
	}
    

	#
	# problem with ),
	#
	if (/[\)\]\}][a-zA-Z0-9]/){
		$message =  "File has no whitespace after closing brace";
		$status = 2;
		s/([\)\]\}])(\S)/$1 $2/;
		$newname = "$_$ext";
		next;
	}
    
	 if (/\s[\)\]\}]/){
		$message =  "File has whitespace before closing brace";
		$status = 2;
		s/\s([\)\]\}])/$1/;
		$newname = "$_$ext";
		next;
	}
    

	# Comma checks
	 if (/\,\S/ && !/\d\,\d/){
		$message =  "File has no whitespace after comma";
		$status = 2;
		s/\,(\S)/\, $1/;
		$newname = "$_$ext";
		next;
	}

	 if (/\s\,/){
		$message =  "File has whitespace before comma";
		$status = 2;
		s/\s\,/\,/;
		$newname = "$_$ext";
		next;
	}
    	
    }
    return($status, $message, $newname);
}

#
# Adopted from Perlmonks post 
# https://www.perlmonks.org/?node_id=885660
# credit to tye  
#
#
# Test on ()'s, also {}, []'s
#
sub balanced {
    my($str )= @_;
    my $d= 0;
    while(  $str =~ m(([(])|([)]))g  ) {
        if(  $1  ) {
            $d++;
        } elsif(  --$d < 0  ) {
            return 0;
        }
    }
    return 0 == $d;
}
