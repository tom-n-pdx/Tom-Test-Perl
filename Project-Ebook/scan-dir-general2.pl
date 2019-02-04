#!/usr/bin/env perl
#
# Generic check of files in dir for odd things - any type files - not specific to ebooks
#

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use List::Util qw(min max);	# Import min()
use Getopt::Long;

use Unicode::Normalize;


use lib '.';
use FileParse qw(check_file_name);
# use MooNode::MooDir;
use ScanDirMD5;




# use utf8;
# use Text::Unidecode;

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
my $fix               = 0;    # rename if status <= this number

GetOptions (
    'debug=i' => \$debug,
    'print=i'   => \$status_print,
    'fix=i'      => \$fix,
);

say "Debug: $debug";
say "Print: $status_print";
say "Fix: $fix";


# scan thru args - if file, check - if dir, generate list of files and check


foreach my $dir_check (@ARGV){
    say "Scanning: $dir_check";
    my @filenames;

    # if (!-e $dir_check || !-r $dir_check || ! (-d $dir_check || -t $dir_check)){
    if (!-e $dir_check || !-r $dir_check){
	warn "Bad Dir/File Arg: $dir_check";
	next;
    }
    if (-d $dir_check){
	@filenames = ScanDirMD5::list_dir_files($dir_check);
    } elsif (-f $dir_check){
	my ($name, $path, $null) = File::Basename::fileparse($dir_check);
	push(@filenames, $name);
	$dir_check = $path;
    } else {
	warn "Bad Dir/File Arg: $dir_check";
    }
    # say "Dir: $dir_check";
    # say "Files: ", join(", ", @filenames);

    foreach my $filename (@filenames){
	my ($name, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);

	
	my($status, $message, $ext_new) = check_file_ext($ext);
	if ($status > 0 && $status >= $status_print){
	    say "$name";
	    say "Fixed Ext Problem ($status) $message";
	}

	my $name_new;
	($status, $message, $name_new) = check_file_name2($name);
	if ($status > 0 && $status >= $status_print){
	    say "$name";
	    print "Fixed name Problem ($status) $message";
	}
	
	my $filename_new = $name_new.$ext_new;

	if ($filename ne $filename_new){
	    if ($status_print <= 1){
		say "Old :$filename ";
		say "New :$filename_new";
	    }
	    if ($fix){
		rename_unique("$dir_check/$filename", "$dir_check/$filename_new");
		say "renamed"  if ($status_print <= 1);
	    }
	}
    }
}


sub check_file_ext {
    my $ext = shift(@_);
    my $status = 0;
    my $message = "";

    # Check if ext not lowercase ext
    if (lc($ext) ne $ext) {
	$message = "uppercase extension: $ext converted to lc";
	$status = 1;
	$ext = lc($ext);
    }
    
    return($status, $message, $ext);
}


sub check_file_name2 {
    my $name = shift(@_);
    my $status = 0;
    my $message = "";

    # my @match = ('^\s+');
    # my @sub     = ('');
    # my @status = (1);
    # my @message = ("Leading whitespace removed");
    my (@match, @sub, @status, @message);

    my $data =<<'END_DATA';
^\s+;;     1; Leading Whitespace removed
\s+$;;     1; Trailing Whitespace removed
 copy$;;    1; Trailing copy removed
_v1\d*$;;  1; Trailing _v removed
\s{2,}; ;     1; Multuple whitespace reduced 
END_DATA

    my $i= 0;
    foreach (split(/\n/, $data)){
	($match[$i], $sub[$i], $status[$i], $message[$i]) = split(/;/);
	$status[$i] +=  0;
	$i++;
    }

    $i = 0;
    for ($i = 0; $i <= $#match; $i++){
	# say "$i $message[$i]";
	while ($name =~ /$match[$i]/){
	    $message .= $message[$i]."\n";
	    $status = $status[$i];
	    $name =~ s/$match[$i]/$sub[$i]/;
	}
    }

    if ($name =~ /([^[:ascii:]])/){
    	if ($name ne Unicode::Normalize::NFC($name)){
    	    $message .= "Normalized unicode in name\n";
    	    $status = 1;
    	    $name = Unicode::Normalize::NFC($name);
    	}
    }

    # Check for unbalanced paerns - can't fix
    if (! balanced($name)) {
	$message .= "Unbalanced parens\n";
	$status = 3;
    }
    
    return($status, $message, $name);
}


#

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

