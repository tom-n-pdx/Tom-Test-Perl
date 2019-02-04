#!/usr/bin/env perl
#
# Apply standard fixe-up regs o check files names
# * rework unicode
# * check for unicode characters
# * check suffix
#

# Standard uses's
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

use Text::Unaccent::PurePerl;
use File::Basename;

# package FileParse v0.1.2;

sub check_file_name {
    my $filename_old = pop @_;
    my $message = "";
    my $status = 0;
    my $filename_new;

    # say "debug: $filename_old";
    my  ($basename, $path, $ext) = File::Basename::fileparse($filename_old, qr/\.[^.]*/);

    #
    # First check file extension
    #
    {
	# Check if not lowercase ext
	if (lc($ext) ne $ext) {
	    $message = "uppercase extension: $ext";
	    $filename_new = $basename.lc($ext);
	    $status = 1;
	    next;
	}
    }

    if ($status){
	return($status, $message, $filename_new);
    }

    #
    # Check main file name
    #
    {
	$_ = $basename;		# put basename checking into $_ so can use short form regexp
	
	# Checked balanced ()'s - worst type problem
	if (!balanced($basename)) {
	    $message = "Unbalanced parens";
	    $status = 3;
	    next;
	}
    
	# Check leading whitespace in name
	if (m/^\s+/){
	    say "DEBUG: Leading whitespace:$_";
	    $message =  "File has leading whitespace";
	    $status = 1;
	    s/\^\s+//;
	    $filename_new = "$_$ext";
	    say "DEBUG: Leading whitespace rename:$_";
	    next;
	}

	# Check for multuple spaces in name - loop until all fixed
	while (/\s{2,}/){
	    $message =  "File has repeated whitespace";
	    $status = 1;
	    s/\s{2,}/ /;
	    $filename_new = "$_$ext";
	}
	# next if $status;

	# Check trailing whitespace in name
	if (/\s$/){
	    $message =  "File has trailing whitespace";
	    $status = 1;
	    s/\s+$//;
	    $filename_new = "$_$ext";
	    next;
	}

	# Check trailing " copy" in name
	if (/ copy$/){
	    # say "DEBUG: trailing copy:$_";
	    $message =  "File has trailing copy";
	    $status = 1;
	    s/\ copy$//;
	    $filename_new = "$_$ext";
	    # say "DEBUG: Trailing copy in name:$_";
	    next;
	}

	# Check trailing _v1* in name
	if (/_v1\d*$/){
	    say "DEBUG: v1* in name:$_";
	    $message =  "File has _v";
	    $status = 1;
	    s/\_v1\d*$//;
	    $filename_new = "$_$ext";
	    # say "DEBUG: Trailing _v in name:$_";
	    next;
	}

	# Check for a trailing (d) for a copy of a file
	# NO - maybe a trailing date (0)
	# if (/\(\d+\)$/){
	#     $message =  "File maybe a 2nd copy";
	#     $status = 3;
	#     next;
	# }

	


	my %unicode_table = (
	    '%e2%80%99' => "'",
	    '%e2%80%93' => "-",
	    '%e2%84%a2' => "",	# (TM) - repalce with space

	    '%c3%a0'       => "a",
	    '%c3%a1'       => "a",
	    '%c3%a3'       => "a",
	    '%c3%a4'       => "a",
	    '%c3%a8'       => "e",
	    '%c3%a9'       => "e",
	    '%c3%ad'       => "i",
	    '%c3%b3'       => "a",
	    '%c3%b6'       => "o",
	    '%c3%bc'       => "o",
	    '%c3%a7'       => "c",
	    '%c3%b8'       => "o",

	    '%c4%87'       => "c",

	    '%c5%81'      => "L",
	    '%c5%82'       => "l",
	    '%c5%84'      => "n",
	    '%c5%87'       => "l",
	    '%c5%99'       => "r",
	    '%c5%a1'      => "s",
	    '%c5%bc'      => "z",


	    '%d0%90'      => "s",
	); 

	if (/(%\p{AHex}{2})/){
	    my $unicode_start = $1;
	    my $unicode;

	    if ($unicode_start eq "%e2"){
		($unicode) = /(%e2%\p{AHex}{2}%\p{AHex}{2})/; # 3 byte string
	    } else {
		($unicode) = /(%\p{AHex}{2}%\p{AHex}{2})/; # 2 byte string
	    }
	    my $ascii = $unicode_table{$unicode};
	    
	    # say "Found Unicode: $unicode";

	    # known Unicode
	    if (defined $ascii){
		$status = 2;
		$message =  "File has known Unicode: $unicode - Translate to: $ascii";
		s/$unicode/$ascii/;
		$filename_new = "$_$ext";
	    } else {
		$status = 3;
		$message =  "File has unknown Unicode: $unicode";
	    }

	    next;
	}


	my %convert = (
	    'é'     => 'e',
	    'ø'     => 'o',
	    '–'     => '-',
	    ' ́'    => '',
	    "’"    => "'",
	    "‐"   => "-",
	    "-"   => "-",
	    "-"   => "-",
	);


	# Unicode weirdness. A unicode character maybe multuple characters - so have to match multuple ones
	if (/([^[:ascii:]]+)/){
	    my $unicode = $1;

	    my $ascii = $convert{$unicode};
	    if ($ascii){
		$status = 2;
		$message =  "File has known Unicode: $unicode Translate to: $ascii";
		s/$unicode/$ascii/g;
		$filename_new = "$_$ext";
	    } else {
		#my $temp = unac_string($_);
		#say "Before: $_";
		#say "After: $temp";
		$status = 3;
		$message =  "File has unknown Unicode: $unicode";
	    }
	    next;
	}

	# Check suffix
	


    }

    return($status, $message, $filename_new);    

}	

#
# Adopted from Perlmonks post 
# https://www.perlmonks.org/?node_id=885660
# credit to tye  
#
#
# Test on ()'s, also {}, []'s
#
# sub balanced {
#     my($str )= @_;
#     my $d= 0;
#     while(  $str =~ m(([(])|([)]))g ) {
#         if(  $1  ) {
#             $d++;
#         } elsif(  --$d < 0  ) {
#             return 0;
#         }
#     }
#     return 0 == $d;
# }

sub balanced {
    my($str )= @_;
    my @d;

    while(  $str =~ m/([\(\[\{])|([\)\]\}])/g ) {
	# Openning
        if (  $1  ) {
	    # say "match openning: \$1 $1";
	    my $close = $1;
	    $close =~ tr/([{/)]}/;
	    push(@d, $close);
        } else {
	    # return 0 if $#d == -1;                         # no openning
	    my $open = pop(@d);
	    # say "match closing: \$2 $2 vs $open";
	    return 0 if !$open || $open ne $2;                      # wrong openning
        }
    }
    return $#d != 0;
    # return 1;
}


1; # End Module
