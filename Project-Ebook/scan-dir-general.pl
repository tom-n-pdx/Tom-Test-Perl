#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
# Using Dir Object
#
# ToDo
# * move fix file into sub so can run as part of tree search
# * make checks do all the mistakes of a type in a name, not just first one
# * Fix number of files fixed vs number problems remaining
# * Use no colide rename!
# * Better fix of unicode
# * count number fixes
# * make fix files more of a 


use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use Getopt::Long;

use lib '.';
use FileParse qw(check_file_name);
use MooNode::MooDir;
use ScanDirMD5;

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
my $status_print = 1; # Print message if status >= this number
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

    #chdir($dir_check);
    # opendir(my $dh, ".");

    # opendir(my $dh, $dir_check);
    # my @filenames = readdir $dh;
    # closedir $dh;

    # @filenames = grep($_ !~ /^\./, @filenames);		    # remove . files from last
    # @filenames = grep(!-d $_ , @filenames);		            # remove dirs from last

    my @filenames = ScanDirMD5::list_dir_files($dir_check);
    # @filenames = @filenames[0..min(10,$#filenames) ] if ($debug >= 1);

    # for debug only do first N  files
    # if ($debug >= 1){
    # 	my $end = 10;
    # 	$end = min($end, $#filenames);                                       
    # }

    say "Files: ", join(", ", @filenames) if ($debug >= 2);

    foreach my $filename (@filenames){
	say "Checking: $filename" if ($debug >= 2);;
	next if $filename =~ /.part$/;                                  # skip partial downloads

	my $filepath = "$dir_check/$filename";

	# if (! -r -w $filepath){
	#     say "\nFile: $filename";
	#     say "    Not RW";
	#     # last;
	# }

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
		my$fixname = &rename_unique("$dir_check/$filename", "$dir_check/$newname");
	    }

	    last if ($status >= 3);	#  fatal - status = 3, exit loop, can't fix
	    $filename = $newname;
	}
    }
}

use File::Copy;
use File::Basename;                  # Manipulate file paths

sub rename_unique {
    my $filename_old = shift(@_);
    my $filename_new = shift(@_);
    my $version = 9;
    my ($name, $path, $ext) = File::Basename::fileparse($filename_new, qr/\.[^.]*/);

    # say "Unique Rename $filename_old -> $filename_new";
    if (!-e $filename_old){
	die "Starting file does not exisit: $filename_old";
    }

    while (-e $filename_new){
	$version++;
	$filename_new = "$path/${name}_v$version$ext";
    }
    rename($filename_old, $filename_new) unless (-e $filename_new);
    # say "New: $filename_new";

    return($filename_new);
}

