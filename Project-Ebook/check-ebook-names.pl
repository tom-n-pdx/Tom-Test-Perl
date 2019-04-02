#!/usr/bin/env perl -CA
#

# ToDo
# * Rework report errors and status values, need a value > 0 and < 1


use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use Number::Bytes::Human qw(format_bytes);
use List::Util qw(min max);	        # Import min()
use Business::ISBN;


use Unicode::Normalize;
use open ':encoding(UTF-8)';
binmode(STDOUT, ":utf8");
use Encode qw(decode_utf8);

use utf8;
binmode STDOUT, ":utf8";
# use Text::Unidecode;
use feature 'unicode_strings';

use Scalar::Util qw(looks_like_number);
use Term::ReadKey;
ReadMode 3;


use lib '.';
use ScanDirMD5;
use NodeTree;
use NodeHeap;
use FileParse qw(check_file_ext check_file_name);
use FileUtility qw(osx_check_flags_binary osx_flags_binary_string %osx_flags 
		   dir_list rename_unique
		   stats_delta_binary %stats_names);

use EbookParse qw(publisher_ok publisher_fixup);

use lib 'MooNode';
use MooDir;
use MooFile;
use MooNode;



our $verbose = 2;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";

my $interactive = 0;
my $bad_unicode = 0;

my $Files = NodeTree->load(dir => $data_dir, name => "ebook.moo.db");
say "All Files Total Records Loaded: ", $Files->count;

my @Files = $Files->List;
my $i = 0;
my %ext;
my %volume;
my %volume_error;
my %status;
my %publisher;
my %keywords;
my %unicode;
my $record_total = 0;
my $ebook_total = 0;
my $isbn_good  = 0;
my $isbn_bad = 0;


# Create file of publishers for quick testing
my $publisher_filepath = "$data_dir/publishers.txt";
# open(my $fh_pub, ">", "$publisher_filepath");


for my $File (@Files){
    my $filepath = $File->filepath;
    my $filename = $File->filename;
    my $filename_new = $filename;
    my $dir      = $File->path;

    # Skip Torrent
    next if ($filepath =~ m!/Users/tshott/Torrent!);
    # Skip Test Dir
    next if ($filepath =~  m!/Users/tshott/Downloads/_ebook/_test_Zeppelins!);


    next unless $filepath =~ m!/Users/tshott!;
    # next unless $filepath =~ m!/Users/tshott/Downloads/_ebook/_temp!;
    # next unless ($filepath =~  m!/Volumes/Mac_Ebook/!);
    # next unless ($filepath =~  m!/Volumes/Mac_Ebook/Ebook-Orginal_No_Sync/!);
    $record_total++;



    my $basename = $File->basename;
    # next unless ($basename =~ /\(ebook/i);
    # next unless (lc($File->ext) eq '.pdf');

    if ($interactive && !-e $filepath){
	next;
    }

    if (!utf8::is_utf8($filename)){
	$bad_unicode++;
	next;
    }
    # DEBUG
    # say "File: ", $File->filepath;

    my $volume = $File->volume;
    $volume{$volume}++;

    my $ext = $File->ext;

    my $status = 0;
    my($status_new, $message, $ext_new);

    ($status_new, $message, $ext_new) = check_file_ext($ext);
    $filename_new = $basename.$ext_new;
    
    if ($status_new >= 3){
    	say " ";
    	say "Error: ($status_new) $message";
    	say "\t   ", $filename;
    	say "\t-> ", $filename_new if ($filename_new ne $filename);
    	say "\t   ", $File->path;
    	say "\t   ", $File->volume;
    }
    $ext{$ext_new}++;
    $status{$status_new}++ if ($status_new >= 1);
    $volume_error{$volume}++ if ($status_new >= 1);
    $status = max($status, $status_new);
    $status_new = 0;
    
    my $name_new;
    ($status_new, $message, $name_new) = check_file_name($basename);
    $filename_new = $name_new.$ext_new;
    # say "DEBUG: $filepath" if ($status_new == 3);

    if ($status_new >= 3){
    	say " ";
    	say "Error: ($status_new) $message";
    	say "\t   ", $filename;
    	say "\t-> ", $filename_new if ($filename_new ne $filename);
    	say "\t   ", $File->path;
    	say "\t   ", $File->volume;
    }
    $status{$status_new}++ if ($status_new >= 1);
    $volume_error{$volume}++ if ($status_new >= 1);
    $status = max($status, $status_new);
    $status_new = 0;

    
    if ($filename =~ m/([^[:ascii:]])/){
	# say "\nContains Unicode: $filename  ";
	# say "Is Unicode: ", utf8::is_utf8($filename) ? "Yes" : "No";

	while ($filename =~ m/([^[:ascii:]])/g){
	    my $pos = pos($filename);
	    # say "Found: $1 $pos";
	    $unicode{$1}++;
	}
    }

    # Ebook specific checks
    if ($basename =~ /\(ebook/i){
	$ebook_total++;

    	($status_new, $message, $name_new) = check_parse_ebook ($name_new);
    	$filename_new = $name_new.$ext_new;

    	if ($status_new >= 3){
    	    say " ";
    	    say "Error: ($status_new) $message";
    	    say "\t   ", $filename;
    	    say "\t-> ", $filename_new if ($filename_new ne $filename);
    	    say "\t   ", $File->path;
    	    say "\t   ", $File->volume;
    	}

    	$status{$status_new}++ if ($status_new >= 1);
    	$volume_error{$volume}++ if ($status_new >= 1);
    	$status = max($status, $status_new);
    	$status_new = 0;

	

	
    }
    $i++;

    # Fix simple errors
    if ($interactive && $status <= -2 && $filename_new ne $filename){
    	say "\t   Do rename";
    	my $filename_rename = rename_unique("$dir/$filename", "$dir/$filename_new");
    	if ($filename_rename ne "$dir/$filename_new"){
    	    say "\t   Unique Rename to $filename_rename";
    	}
    	say " ";
    	say " ";
    }

    if ($interactive && $status >= 4){
	print "Options: o)pen in finder f)fix space skip q)quit: ";
	my $command = lc(getc);

	if ($command eq 'q') {
	    say " ";
	    ReadMode 0;
	    exit;
	}
	
	if ($command eq "o"){
 	    `open -R "$filepath"`;
	}
	
	if ($command eq "f"){
	    my $filename_rename = rename_unique("$dir/$filename", "$dir/$filename_new");
	}

	say " ";
	say " ";
    }

}

#close($fh_pub);

say "\nBad Unicode: $bad_unicode";


say "\nTotal Records: $record_total Ebook Total: $ebook_total ISBN Good: $isbn_good ISBN Bad: $isbn_bad";

say " ";
say "Status: ";
foreach (sort keys %status){
     say "    $_ ", $status{$_}; 
}

# say " ";
# say "Extensions: ";
# foreach (sort keys %ext){
#     say "    $_ ", $ext{$_}; 
# }

# say " ";
# say "Volumes: ";
# foreach (sort keys %volume){
#     say "    $_ ", $volume{$_}; 
# }

say " ";
say "Volumes Errors: ";
foreach (sort keys %volume_error){
    say "    $_ ", $volume_error{$_}; 
}

# say "\nUnicode Characters Found";
# my @chars = sort {$unicode{$b} <=> $unicode{$a} } keys %unicode;
# @chars = @chars[0..10];
# foreach my $char ( @chars ){
#     say "$char ", nice_string($char), ":  $unicode{$char}";
# }



# say " ";
# say "Keywords: ";
# foreach (sort { $keywords{$a} <=> $keywords{$b} } keys %keywords){
#     say "    $_ ", $keywords{$_}; 
# }


# How print publisher close? +- 1 name?

# my @publishers;
# @publishers = sort( {$publisher{$b} <=> $publisher{$a} } keys %publisher);
# my $bad_publisher = 0;
# my $total         = 0;
# foreach (@publishers){
#     $total          += $publisher{$_};
#     $bad_publisher  += $publisher{$_}  if (! publisher_ok($_) );
# }

# @publishers = @publishers[0 .. 300];

# say " ";
# say "Publisher: ";
# my $bad = 0;
# for (my $i = 0; ($i <= $#publishers && $bad <= 15); $i++){
#     my $publisher = $publishers[$i];

#     my $ok = publisher_ok($publisher);
#     if ($ok) {
# 	say "$publisher: ", $publisher{$publisher};
#     } else {
# 	say "    $publisher: ", $publisher{$publisher};
# 	$bad++;
#     }
# }

# say " ";
# say "Total Publishers: $total Bad: $bad_publisher";


# reset terminal Mode
ReadMode 0;
exit;



# sub publisher_hot {
#     my $i = shift(@_);
#     my $hit = 0;
#     my $publisher = $publishers[$i];

#     if ($publisher{$publisher} < 1){
# 	return ($hit);
#     }

#     for ($i-3 .. $i+3){	
# 	$publisher = $publishers[$_];
# 	if ( defined $publisher && $publisher{$publisher} > 5){
# 	    $hit = 1;
# 	}
#     }
#     return($hit);
# }

# 0      1       2          3               4
# ebook, Author, Publisher, Year, Keywords, End


sub check_parse_ebook {
    my $name_start = shift(@_);
    my $status = 0;
    my $message = "";
    my $name = $name_start;

    if ($name !~ /\(ebook/i) {
	$message .= "Not a ebook\n";
	$status  = max($status, 3);
	return($status, $message, $name);
    }

    # ToDo
    # Fix parse nested ( )'s
    $name =~ /\((ebook.*)\)/i;
    my $ebook_str = $1;
    my @ebook_fields = split(/,\s*/, $ebook_str);

    
    # Check that has at least 5 fields
    if (@ebook_fields < 5){
	$message .= "Short Ebook records field\n";
	$status  = max($status, 3);
    }	

    #
    # Check catagory of files - last value in name
    #
    my %catagory_types = (orginal => 1, fixed => 1, converted => 1, ocr => 1, missing => 1, edited => 1, merged => 1, 
			  unknown => 1);

    my $catagory = lc($ebook_fields[-1]);
    if (! defined $catagory_types{$catagory}){
	$message .= "Unknown catagory: '$catagory'\n";
	$status  = max($status, 3);
    }

    #
    # Check Publisher
    #
    my $publisher = $ebook_fields[2] // "";
    my ($status_new, $message_new, $publisher_new) = check_publisher ($publisher);

    if ($status_new >= 1){
    	$message .= $message_new;
    	$status  = max($status, $status_new);
    }	

    # 	if ($publisher_new ne $publisher){
    # 	    $name =~ s/$publisher/$publisher_new/;
    # 	}
    # }


    #
    # Check date of file
    #
    my $date = $ebook_fields[3] // "";
    if (! looks_like_number($date) ){
	$message .= "Date does not seem to be a number: '$date'\n";
	$status  = max($status, 3);
    } elsif ( $date != 9999 && ($date >= 2021 || $date <= 1800)){
	$message .= "Invlid date value: $date\n";
	$status  = max($status, 2);
    }



    # Check legal keywords
    my %keywords_types = (noocr => 1,   ocr => 1,  scanned => 1, watermark => 1, converted => 1, "2up" => 1,   edit => 1, 
			  damaged => 1, isbn => 1, ocd => 1,     locked =>1,     asin => 1,       merged => 1, older => 1,
			  archive => 1, clip => 1, preview => 1);
    my @keywords_str;

    if (@ebook_fields > 5){
	# say "Checking Keywords";
	my @keywords_str = @ebook_fields[4 .. ($#ebook_fields - 1)];

	my @keywords_unknown;	
	foreach my $keyword_str (@keywords_str){
	    my ($key, $value) = split /\s+/, $keyword_str, 2;
	    $keywords{lc($key)}++;

	    push(@keywords_unknown, $key) if (!defined $keywords_types{ lc($key)} );

	    if (lc($key) eq 'isbn'){
		my ($status_new, $message_new, $isbn_new) = check_isbn($value);
		if ($status_new >= 1){
		    $message .= $message_new;
		    $status  = max($status, $status_new);
		}
	    }
	}

	if (@keywords_unknown){
	    $message .= "Unknown keywords: ". join(", ", @keywords_unknown). "\n";
	    $status  = max($status, 3);
	}
    }


    chomp($message);
    return($status, $message, $name);
}


sub check_publisher {
    my $publisher = shift(@_);
    my $status = 0;
    my $message = "";
    my $publisher_new = $publisher;

    # Temp Publisher list for trying ideas
    # print $fh_pub "$publisher\n";

    if (! publisher_ok($publisher)) {
	$publisher_new = publisher_fixup($publisher);
     	if ($publisher_new ne $publisher){
    	    # $status = max($status, 2);
    	    # $message .= "Publisher Fixup $publisher => $publisher_new\n";
	    # $publisher_new = $publisher;
	} else {
    	    # $status = max($status, 1);
    	    # $message .= "Bad Publisher $publisher\n";

	}
    }
	
    if ($publisher_new =~ /([^[:ascii:]])/){
	$status = 2;
	$message .= "Unicode in Publisher $publisher_new\n";
    }
	
    $publisher{$publisher_new}++;

    chomp($message);
    return($status, $message, $publisher);
}

sub check_isbn {
    my $isbn = shift(@_);
    my $status = 0;
    my $message = "";
    my $isbn_new = $isbn;

    if (! $isbn){
	$status = 3;
	$message .= "No ISBN Value\n";
	chomp($message);
	return($status, $message, $isbn);
    }

    if ($isbn =~ /([^[:ascii:]])/){
	$status = 3;
	$message .= "Unicode in ISBN $isbn\n";
    }

    # Bug in check isbn code - marks this as bad
    if ($isbn =~ /^978-981/){
	chomp($message);
	return($status, $message, $isbn);
    }


    
    # Will check both the chracters, valid prefix, publisher, article, & checksum
    my $Isbn = Business::ISBN->new($isbn);
    if (!defined $Isbn){
	$status = 3;
	$message .= "ISBN is invalid - bad format '$isbn'\n";
	$isbn_bad++;
    } elsif (! $Isbn->is_valid) {
	$message .= "ISBN is invalid - ".$Isbn->error_text." '$isbn'\n";
	$status = $Isbn->error == -1 ? 1 : 3;
	$isbn_bad++;
    } else {
	$isbn_good++;
    }

    chomp($message);
    return($status, $message, $isbn);
}

sub nice_string {
    join("",
	 map { $_ > 255                        # if wide character...
		   ? sprintf("\\x{%04X}", $_)  # \x{...}
		   : chr($_) =~ /[[:cntrl:]]/  # else if control character...
		   ? sprintf("\\x%02X", $_)    # \x..
		   : quotemeta(chr($_))        # else quoted or as themselves
	       } unpack("W*", $_[0]));         # unpack Unicode characters
}
