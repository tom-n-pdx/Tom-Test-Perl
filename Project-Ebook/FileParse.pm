#!/usr/bin/env perl
#
# Apply standard fixe-up regs o check files names
# * rework unicode
# * check for unicode characters
# * check suffix
#

package FileParse v0.1.2;
use Exporter qw(import);
our @EXPORT_OK = qw(check_file_ext check_file_name);

# Standard uses's
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code
use utf8;
use Text::Unidecode;

use Text::Unaccent::PurePerl;
use File::Basename;
use List::Util qw(min max);	        # Import min()

# sub check_file_name {
#     my $filename_old = pop @_;
#     my $message = "";
#     my $status = 0;
#     my $filename_new;

#     # say "debug: $filename_old";
#     my  ($basename, $path, $ext) = File::Basename::fileparse($filename_old, qr/\.[^.]*/);

#     #
#     # First check file extension
#     #
#     {
# 	# Check if not lowercase ext
# 	if (lc($ext) ne $ext) {
# 	    $message = "uppercase extension: $ext";
# 	    $filename_new = $basename.lc($ext);
# 	    $status = 1;
# 	    next;
# 	}
#     }

#     if ($status){
# 	return($status, $message, $filename_new);
#     }

#     #
#     # Check main file name
#     #
#     {
# 	$_ = $basename;		# put basename checking into $_ so can use short form regexp
	
# 	# Checked balanced ()'s - worst type problem
# 	if (!balanced($basename)) {
# 	    $message = "Unbalanced parens";
# 	    $status = 3;
# 	    next;
# 	}
    
# 	# Check leading whitespace in name
# 	if (m/^\s+/){
# 	    say "DEBUG: Leading whitespace:$_";
# 	    $message =  "File has leading whitespace";
# 	    $status = 1;
# 	    s/\^\s+//;
# 	    $filename_new = "$_$ext";
# 	    say "DEBUG: Leading whitespace rename:$_";
# 	    next;
# 	}

# 	# Check for multuple spaces in name - loop until all fixed
# 	while (/\s{2,}/){
# 	    $message =  "File has repeated whitespace";
# 	    $status = 1;
# 	    s/\s{2,}/ /;
# 	    $filename_new = "$_$ext";
# 	}
# 	# next if $status;

# 	# Check trailing whitespace in name
# 	if (/\s$/){
# 	    $message =  "File has trailing whitespace";
# 	    $status = 1;
# 	    s/\s+$//;
# 	    $filename_new = "$_$ext";
# 	    next;
# 	}

# 	# Check trailing " copy" in name
# 	if (/ copy$/){
# 	    # say "DEBUG: trailing copy:$_";
# 	    $message =  "File has trailing copy";
# 	    $status = 1;
# 	    s/\ copy$//;
# 	    $filename_new = "$_$ext";
# 	    # say "DEBUG: Trailing copy in name:$_";
# 	    next;
# 	}

# 	# Check trailing _v1* in name
# 	if (/_v1\d*$/){
# 	    say "DEBUG: v1* in name:$_";
# 	    $message =  "File has _v";
# 	    $status = 1;
# 	    s/\_v1\d*$//;
# 	    $filename_new = "$_$ext";
# 	    # say "DEBUG: Trailing _v in name:$_";
# 	    next;
# 	}

# 	# Check for a trailing (d) for a copy of a file
# 	# NO - maybe a trailing date (0)
# 	# if (/\(\d+\)$/){
# 	#     $message =  "File maybe a 2nd copy";
# 	#     $status = 3;
# 	#     next;
# 	# }

	


# 	my %unicode_table = (
# 	    '%e2%80%99' => "'",
# 	    '%e2%80%93' => "-",
# 	    '%e2%84%a2' => "",	# (TM) - repalce with space

# 	    '%c3%a0'       => "a",
# 	    '%c3%a1'       => "a",
# 	    '%c3%a3'       => "a",
# 	    '%c3%a4'       => "a",
# 	    '%c3%a8'       => "e",
# 	    '%c3%a9'       => "e",
# 	    '%c3%ad'       => "i",
# 	    '%c3%b3'       => "a",
# 	    '%c3%b6'       => "o",
# 	    '%c3%bc'       => "o",
# 	    '%c3%a7'       => "c",
# 	    '%c3%b8'       => "o",

# 	    '%c4%87'       => "c",

# 	    '%c5%81'      => "L",
# 	    '%c5%82'       => "l",
# 	    '%c5%84'      => "n",
# 	    '%c5%87'       => "l",
# 	    '%c5%99'       => "r",
# 	    '%c5%a1'      => "s",
# 	    '%c5%bc'      => "z",


# 	    '%d0%90'      => "s",
# 	); 

# 	if (/(%\p{AHex}{2})/){
# 	    my $unicode_start = $1;
# 	    my $unicode;

# 	    if ($unicode_start eq "%e2"){
# 		($unicode) = /(%e2%\p{AHex}{2}%\p{AHex}{2})/; # 3 byte string
# 	    } else {
# 		($unicode) = /(%\p{AHex}{2}%\p{AHex}{2})/; # 2 byte string
# 	    }
# 	    my $ascii = $unicode_table{$unicode};
	    
# 	    # say "Found Unicode: $unicode";

# 	    # known Unicode
# 	    if (defined $ascii){
# 		$status = 2;
# 		$message =  "File has known Unicode: $unicode - Translate to: $ascii";
# 		s/$unicode/$ascii/;
# 		$filename_new = "$_$ext";
# 	    } else {
# 		$status = 3;
# 		$message =  "File has unknown Unicode: $unicode";
# 	    }

# 	    next;
# 	}


# 	my %convert = (
# 	    'é'     => 'e',
# 	    'ø'     => 'o',
# 	    '–'     => '-',
# 	    ' ́'    => '',
# 	    "’"    => "'",
# 	    "‐"   => "-",
# 	    "-"   => "-",
# 	    "-"   => "-",
# 	);


# 	# Unicode weirdness. A unicode character maybe multuple characters - so have to match multuple ones
# 	if (/([^[:ascii:]]+)/){
# 	    my $unicode = $1;

# 	    my $ascii = $convert{$unicode};
# 	    if ($ascii){
# 		$status = 2;
# 		$message =  "File has known Unicode: $unicode Translate to: $ascii";
# 		s/$unicode/$ascii/g;
# 		$filename_new = "$_$ext";
# 	    } else {
# 		#my $temp = unac_string($_);
# 		#say "Before: $_";
# 		#say "After: $temp";
# 		$status = 3;
# 		$message =  "File has unknown Unicode: $unicode";
# 	    }
# 	    next;
# 	}

# 	# Check suffix
	


#     }

#     return($status, $message, $filename_new);    

# }	

sub check_file_name {
    my $name = shift(@_);
    my $status = 0;
    my $message = "";

    my $name_start = $name;
    # my (@match, @sub, @status, @message);

    # Check for unbalanced paerns - can fix two common cases
    if (! balanced($name)) {

	if ($name =~ /fixed$/i){
	    $name .= ")";
	    $status = max($status, 2);
	} elsif ($name =~ /converted\), Fixed\)/i) {
	    $name =~ s/converted\),/Converted,/i;
	    $status = max($status, 2);
	} else {
	    $status = max($status, 3);
	}

	$message .= "Unbalanced parens\n";
    }
    
    # Some unicode checks
    if ($name =~ /([^[:ascii:]])/){
    	if ($name ne Unicode::Normalize::NFC($name)){
    	    $message .= "Normalized unicode in name\n";
    	    $status = max($status, 1);
    	    $name = Unicode::Normalize::NFC($name);
	}
  }


    # Series of regular expression fixes
    my (@match, @sub, @message);

    my $data =<<'END_DATA';
^\s+;;Leading Whitespace removed
\s+$;;Trailing Whitespace removed
\s{2,}; ;Multuple whitespace reduced 
 copy$;;Trailing copy removed
_v1\d*$;;Trailing _v removed
\s+,;,;Space before comma
END_DATA

    # Read Regular expression into arrays
    my $i= 0;
    foreach (split(/\n/, $data)){
	($match[$i], $sub[$i], $message[$i]) = split(/;/);
	# chomp($message[$i]);
	$i++;
    }

    for ($i = 0; $i <= $#match; $i++){
	while ($name =~ /$match[$i]/){
	    $status = max($status, 1);
	    $message .= $message[$i]."\n";
	    $name =~ s/$match[$i]/$sub[$i]/;
	}
    }
    
    chomp($message);
    return($status, $message, $name);
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



sub check_file_ext {
    my $ext = shift(@_);
    my $status = 0;
    my $message = "";
    my $ext_start = $ext;

    my %ebook_ext = (".pdf"  => 1, ".chm"  => 1, ".epub" => 1, 
		     ".mobi" => 1, ".djvu" => 1, ".azw"  => 1, ".azw3" => 1, ".txt" => 1, ".ps" => 1, ".doc" => 1,
		     ".rar"  => 2, ".zip"  => 2, ".7z"   => 2, ".tgz" => 2,
		     ".jpg"  => 3, ".gif"  => 3, ".tif"  => 3);

    # Check if ext not lowercase ext
    if (lc($ext) ne $ext) {
	$message = "uppercase extension: $ext converted to lc";
	$status = 1;
	$ext = lc($ext);
    }
    
    # Check if ext has whitepace
    if ($ext =~ /\s/) {
	$message = "white space in extension: $ext";
	$status = 3;
    }
    
    # Check if know extension
    if (! defined $ebook_ext{$ext} ) {
	$message = "unknown extension: '$ext'";
	$status = 3;
    }
    
    return($status, $message, $ext);
}


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
