#!/usr/bin/env perl
#
use Modern::Perl; 		         # Implies strict, warnings
# use List::Util qw(min max);	 # Import min()
#use Digest::MD5::File;
use autodie;
# use File::Find;
# use constant MD5_BAD => "x" x 32;
# use Cwd;
# use List::MoreUtils qw(uniq);

use lib '.';
use ScanDirMD5;
# use constant MD5_BAD => "x" x 32;

our $debug = 0;
our $print_width = 80;
our $md5_limit = 4 * $print_width;;
my $fast_scan = 0;

my $global_updates = 0;

my %HoA;

my @list =   ScanDirMD5::HoA_list(\%HoA, "Bob");
say "Bob Pop ", scalar(@list), " ", join("; ", @list);

ScanDirMD5::HoA_push(\%HoA, "Bob", 1);

ScanDirMD5::HoA_push(\%HoA, "Bob", 2);

my $count = ScanDirMD5::HoA_push(\%HoA, "Sam", 3);

say "Bob ($count) ", join("; ", @{ $HoA{'Bob'} });

ScanDirMD5::HoA_push(\%HoA, "Bob", 4);

$count = ScanDirMD5::HoA_push(\%HoA, "Bob", 5);

say "Bob ($count) ", join("; ", @{ $HoA{'Bob'} });

ScanDirMD5::HoA_push(\%HoA, "Bob", 5);

$count = ScanDirMD5::HoA_push(\%HoA, "Bob", 1);

say "Bob ($count) ", join("; ", @{ $HoA{'Bob'} });

ScanDirMD5::HoA_pop(\%HoA, "Bob");
@list =   ScanDirMD5::HoA_list(\%HoA, "Bob");
say "Bob Pop ", scalar(@list), " ", join("; ", @list);

ScanDirMD5::HoA_pop(\%HoA, "Bob");
ScanDirMD5::HoA_pop(\%HoA, "Bob");

@list =  ScanDirMD5::HoA_list(\%HoA, "Bob");
say "Bob Pop ", scalar(@list), " ", join("; ", @list);
say "Keys ", join(", ", keys %HoA);

ScanDirMD5::HoA_pop(\%HoA, "Bob");
ScanDirMD5::HoA_pop(\%HoA, "Bob");
@list =  ScanDirMD5::HoA_list(\%HoA, "Bob");
say "Bob Pop ", scalar(@list), " ", join("; ", @list);
say "Keys ", join(", ", keys %HoA);

ScanDirMD5::HoA_pop(\%HoA, "Bob");
@list =   ScanDirMD5::HoA_list(\%HoA, "Bob");
say "Bob Pop ", scalar(@list), " ", join("; ", @list);
say "Keys ", join(", ", keys %HoA);



exit;

