#!/usr/bin/env perl
#

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use File::chdir;

my $dir_path = shift(@ARGV);

$CWD = $dir_path;

my @files = <*Fixed).pdf>;

foreach (@files){
    check_other($_);
}
exit;



# my $file_fixed = $files[0];

# say "File Fixed: $file_fixed  Size: ", -s $file_fixed;

# my ($file_org) = $file_fixed =~ /(.*Orginal\))/;
# $file_org .= ".pdf";

# say "File: Orginal; $file_org Size: ", -s $file_org;

# my ($file_convert) = $file_fixed =~ /(.*)\, Fixed\)/;
# $file_convert .= ".pdf";

# say "File: Convert; $file_convert Size: ", -s $file_convert;


sub check_other {
    my $file_fixed = shift(@_);

    if (! -e $file_fixed){
	say "WARN: File Fixed does not exisit $file_fixed";
	return;
    }

    my ($file_org) = $file_fixed =~ /(.*(Orginal|Merged)\)(_v.+)?)\,/;
    $file_org .= ".pdf";
    # say "Check: $file_org";
    if (! -e $file_org){
	say "WARN: File Org does not exisit $file_org Fixed: $file_fixed";
	return;
    }

    my ($file_convert) = $file_fixed =~ /(.*)\, Fixed\)/;
    $file_convert .= ".pdf";
    if (! -e $file_convert){
	say "WARN: File Convert does not exisit $file_convert Fixed: $file_fixed";
	return;
    }


    return;
}
