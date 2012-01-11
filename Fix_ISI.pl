#!/usr/local/bin/perl

#
# Read in isi file and add a extra space before PT field
#

use strict;
use warnings;

#use feature 'state';    # Perl > 5.9.4, provides persistent varables

binmode STDOUT, ":utf8";
my $last_line = 0;


while (<>){
    
 
 
    if (/^PT/){
        if ($last_line =~ /ER/){
            print "\n";
#            print "Do Add line before PT\n";
        } else {
#            print "Not Add line before PT\n";
        }
    }
    print $_;

    $last_line = $_;
        
}

exit;

