#
# Program to test playing cards class
#


use strict;
use warnings;

use lib '.';
use Trainer;

my $paul = Trainer->new();
$paul->debug;
print "Paul is a Geek.\n" if $paul->isa("Geek");
print "Paul is a Trainer.\n" if $paul->isa("Trainer");
print "Paul is a PerlTrainer.\n" if $paul->isa("PerlTrainer");

print "Paul can debug.\n" if $paul->can("debug");


my $bob = PerlTrainer->new();
$bob->debug;
print "Bob is a Geek.\n" if $bob->isa("Geek");
print "Bob is a Trainer.\n" if $bob->isa("Trainer");
print "Bob is a PerlTrainer.\n" if $bob->isa("PerlTrainer");


