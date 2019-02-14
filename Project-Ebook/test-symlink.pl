#!/usr/bin/env perl

our $verbose = 2;

use Modern::Perl '2016'; 
use autodie;

use lib '.';
use lib 'MooNode';
use MooFile;
use MooNode;
use MooDir;

use FileUtility;
use File::Basename;

my $dir;
# $dir = "/Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp";
# $dir = "/Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local/Microsoft/Windows/Burn"; # has uchg flag set
$dir = "/Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local"; # Some hidden dirs

# my $Dir = MooDir->new($dir);
my @list = FileUtility::dir_list(dir => $dir, inc_dot => 1);

say "Checking $dir";
print "List Dir: ";
foreach (@list){
    my ($name, $path, $suffix) = File::Basename::fileparse($_);	
    print $name, ", ";
}
say " ";

# say $Dir->dump;

exit;

my $file;
$file = "/Users/tshott/Torrent/_Archive/_Move_Backup/Copy_Bootcamp/AppData/Local/Microsoft/Windows/Burn/Burn"; # has uchg flag set
# $file = "/Users/tshott/Library"; # Has hiddent flag set
# $file = "/private"; # Has hidden and no modify flag set
#$file = "/Users/tshott"; # Has no flagz set
# $file = "/Users/tshott/Downloads/_ebook/_test_Zeppelins"; # No flags, has purple label

# say "File $file is hidden: ", $File1->ishidden //"No";

say "Checking: $file";
if (!-w $file){
    say "Is not writeable";
}

my @flags = FileUtility::osx_check_flags($file);
say "Flags: ", join(", ", @flags);

my $File = MooDir->new($file);

say $File->dump;
