#!/usr/bin/env perl


use Modern::Perl '2016'; 
use autodie;

use File::ExtAttr;

my $file = "Notes-Book.org";

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


