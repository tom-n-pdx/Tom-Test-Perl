#!/usr/bin/env perl
#
# Scan a big tree and extract os x flags from evey file
#
use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use File::Find;
use Getopt::Long;

use lib '.';
use ScanDirMD5;
use FileUtility;
use NodeTree;

use lib 'MooNode';
use MooDir;
use MooFile;


our $debug = 0;
our $verbose = 1;
our $fast_scan = 0;
our $fast_dir  = 0;
our $tree=0;
our $md5_save_limit = 100;

my %flags;


GetOptions (
    'debug=i'     => \$debug,
    'verbose=i'   => \$verbose,
    'fast'        => \$fast_scan,
    'quick'       => \$fast_dir,
    'tree'        => \$tree,
);

if ($debug or $verbose >= 2){
    say "Options";

    say "\tDebug: ", $debug;
    say "\tVerbose: ", $verbose;
    say "\tFast: ", $fast_scan;
    say "\tQuick Dir: ", $fast_dir;
    say "\tTree: ", $tree;

    say " ";
}


my $filepath;

$filepath = "/Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local/Microsoft/Windows/Burn/Burn";
# $filepath = "/Users/tshott/Downloads/_ebook/_test_Zeppelins/ [AIAA Education] Grant E. Carichner, Leland M. Nicolai, Bernd Chudoba - Fundamentals of Aircraft and Airship Design, Volume 2 – Airship Design and Case Studies 2(2013, Amer Inst of Aeronautics)_v10.pdf";
# $filepath = "/System";

my $flags = FileUtility::osx_check_flags_binary($filepath);
my $string = FileUtility::osx_flags_binary_string($flags);

printf "Flags: %04o\n", $flags;
say "String: $string";

exit;




#
# Scan each arg as dir, using dir or tree scan.
#
foreach my $dir (@ARGV){
    if ($tree){
	say "Scanning Tree: $dir" if ($verbose >= 0); 
	find(\&wanted,  $dir);
    } else {
	say "Scanning Dir: $dir" if ($verbose >=0 ); 
	# update_dir(dir=>$dir, fast_scan=> $fast_scan, fast_dir => $fast_dir);
    }
}

say "Flags:";
foreach (keys %flags){
    say $_;
}

exit;



#
# File find wanted sub. For any file that is a readable dir 
# 
sub wanted {
    return unless (-r $File::Find::name);   # if not readable skip

    # Need to check flags on OSX 
    my @flags = FileUtility::osx_check_flags($File::Find::name);
    
    #say "Check Flags $_ ", join(', ', @flags);
    foreach (@flags) {
	$flags{$_}++;
	if ( $flags{$_} == 1) {
	    say "Flag: $_ File: $File::Find::name";
	}
    }


    return;
}


