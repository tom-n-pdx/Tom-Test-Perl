#!/usr/bin/env perl
#
# Apply standard fixe-up regs o check files names
#
#

# Standard uses's
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code


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
    
	# Check for multuple spaces in name
	while (/\s{2,}/){
	    $message =  "File has repeated whitespace";
	    $status = 1;
	    s/\s{2,}/ /;
	    $filename_new = "$_$ext";
	}
	next if $status;

	# Check trailing whitespace in name
	if (/\s$/){
	    $message =  "File has trailing whitespace";
	    $status = 1;
	    s/\s+$//;
	    $filename_new = "$_$ext";
	    next;
	}

	# Check leading whitespace in name
	if (/^\s/){
	    # say "DEBUG: Leading whitespace:$_";
	    $message =  "File has leading whitespace";
	    $status = 1;
	    s/\^\s//;
	    $filename_new = "$_$ext";
	    # say "DEBUG: Leading whitespace rename:$_";
	    next;
	}


	my %unicode_table = (
	    '%e2%80%99' => "'",
	    '%e2%80%93' => "-"); 

	# Check for Unocode encode characters
	if (/%e2/){
	    my ($unicode) = /(%e2%\d\d%\d\d)/;
	    my $ascii = $unicode_table{$unicode};

	    # known Unicode
	    if ($ascii){
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
