#!/usr/bin/env perl
#
# Try using find to create file objects
#

#
# Scan a tree and create a file object for all normal files that are readable
#

use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

# use Number::Bytes::Human qw(format_bytes);
# use List::Util qw(min);	# Import min()
# use Data::Dumper;           # Debug print
use File::Find;

# My Modules
use lib '.';
use MooFile;


my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $scan_dir;
#$scan_dir = "$ebook_base_dir/_Zeppelins";
#$scan_dir = $ebook_base_dir;
$scan_dir = "/Volumes/Mac_Ebook/Ebook - Orginal No_Sync/_OCD_Lib/_OCD_Lib_Agile_16-03-01_(Orginal)";
$scan_dir = "/Volumes/Mac_Ebook/Ebook - Orginal No_Sync/_OCD_Lib";
$scan_dir = "/Volumes/Mac_Ebook/Ebook - Orginal No_Sync";
$scan_dir = "/Volumes/Mac_Ebook/Ebooks/_Inbox/__Inbox_NoSync (SKIP)/Ebooks - Springer (Raw, Clean, Dedupe)";

my @files;

sub find_sub
{
    return if /^\./;
    return if !-f -r;
    print" $_ \n";

    my $file = MooFile->new('filepath' => $File::Find::name, 'opt_update_md5' => 1);
    push(@files, $file);
}

find(\&find_sub, $scan_dir);
# find(\&find_sub, "/Volumes/Mac_Ebook/Ebooks");

#foreach (@files){
#    say $_->filename;
#}

#
# Loop for dupes by checking dup sizes
#
my %hash;

# Lookup size and push onto array at that size
foreach (@files){
    push(@{$hash{$_->size}}, $_);
}

# Now  -walk hash  -find which values have a array > 0 length  -those are dupe sizes
foreach my $size  (sort keys %hash){
    my @values = @{ $hash{$size} };
    if ($#values > 0){
	# say "Dupe files size: $size";
	foreach (@values) {
	    #say $_->filepath;
	    # say "\t", $_->path;
	    $_->update_md5;
	    # say "\t", $_->md5;
	}
	# $i++;

	# last if ($i >= 5);
	
    }
}

#
# Check for repeated md5
#
undef(%hash);

# Lookup size and push onto array at that size
foreach (@files){
    if ($_->md5){
	push(@{$hash{$_->md5}}, $_);
    }
}

my $i = 0;


say "\n";
foreach my $md5  (sort keys %hash){
    my @values = @{ $hash{$md5} };
    if ($#values > 0){
	say "Dupe files md5: $md5";
	foreach (@values) {
	    say "\t", $_->filename;
	    say "\t", $_->path;
	}
	say "\n";

	$i++;
	last if ($i >= 5);

    }
}
