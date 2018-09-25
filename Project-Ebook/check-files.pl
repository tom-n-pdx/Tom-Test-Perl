#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
#

use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min);	# Import min()
use File::Basename;

#
# Open current directory and create a list of files to scan
#
opendir(my $dh, ".");
my @filenames = readdir $dh;
closedir $dh;

@filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
@filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

my $status_print = 0;
my $status_fix = 0;
my $nfixed = 0;

# for debug only do first N 
my $end = 20;
$end = min($end, scalar(@filenames));                                       
#@filenames = @filenames[0..$end];

foreach my $filename (@filenames){
    #
    # repeat until fixed - but limit to 3 changes
    #
    for(my $i = 1; $i < 4; $i++){
	my ($status, $message, $newname) = check_file_name($filename);
	last if ($status == 0);

	# OK - know we had problems with file
	$nfixed++ if ($i == 1);

	# Only print info on more serious errors
	if ($status > $status_print){
	    say "\nFile: $filename" if ($i == 1);
	    say "    $message";
	    print "\tBefore: $filename\n";
	    print "\tAfter : $newname\n" if ($status <= 2);

	}
	last if ($status == 3);	# unfixable - exit

	$filename = $newname;
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
    

	# # Comma checks
	 if (/\,\S/){
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
