#!/usr/local/bin/perl

#
# Read in isi file & parse
#
# ISI files are two letter codes, 1 space, rest of line
# no code - continuation of earlier
#
# File starts with FN & ennds with EF
# Records starts with PT and ends with ER



use strict;
use warnings;




my $line = &read_line();

print "$line\n";

exit;




sub read_line {

	my $line = <>;
	chop($line);
 	
 	return($line);	
}