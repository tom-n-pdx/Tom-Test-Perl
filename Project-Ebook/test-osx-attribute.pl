#!/usr/bin/env perl


use Modern::Perl '2016'; 
use autodie;

use lib 'MooNode';
use MooNode;


my $file;
$file = "/Users/tshott/Library"; # Has hiddent flag set
# $file = "/private"; # Has hidden and no modify flag set
#$file = "/Users/tshott"; # Has no flagz set
$file = "/Users/tshott/Downloads/_ebook/_test_Zeppelins"; # No flags, has purple label


my $File1 = MooNode->new($file);

say "File $file is hidden: ", $File1->ishidden //"No";

# Check if file is hidden
# -l long d- don't diplay dir 1 - make sure one colume O- show os x flags - add @ for atributes
# my $cmd = 'ls -1lOd ';


# if (!-e $file){
#     die "File does not exist $file";
# }

# say "File: $file";

# my $string = `$cmd $file`;
# chomp($string);
# say "String: $string";
# my ($perms, $flags) = (split(/\s+/, $string))[0, 4];
# my $extended = substr($perms, -1,  1);
# my $perms    = substr($perms,  0, -1);
# say "Perms: $perms Extended: $extended Flags: $flags";


use File::ExtAttr;

#
# Need to translate binary label blob to labels
#

#
# If file has no color - then no atributes set
# * if set / cleaer - then has empty plist
#
# Color is com.apple.metadata:_kMDItemUserTags
# * binary property list blob
# 
#
# command line
# % xattr -l Notes-Book.org
#
# for file creation time & color
# % mdls
#
# In Unix time for creation time
# % stat -f %B _filename_
#
# % ls -l -@ filename
#
say "List Attributes for file:$file";

foreach (File::ExtAttr::listfattr($file))
{ 
   my $value = File::ExtAttr::getfattr($file, $_);
   say "\t$_\t$value";
}


