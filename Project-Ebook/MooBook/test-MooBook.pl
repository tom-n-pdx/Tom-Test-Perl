#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code

#
# ToDo - expand ~ in dir path
# * prerry print info - 1 line, multuple lines
#

# use Number::Bytes::Human qw(format_bytes);
# use List::Util qw(min);	# Import min()
use Data::Dumper;           # Debug print

# use Storable qw(nstore_fd);
# use Fcntl qw(:DEFAULT :flock);


# My Modules
use lib '.';
use MooBook;
# use MooFile;


my $test = MooBook->new(title => "My Book");

# my $test = MooNode->new;
say "Version: ", $test->VERSION;

say "Test Dump";
$test->dump;
$test->dump_raw;

say Dumper($test);

my $test = MooBook->new(title => "My Book", subtitle => "Dumb", publisher => "Wiley", 
			year => 2010, series => "For Dummies", 
			author_list=> ["Bob Smith", ],     # author => "Smith",
			isbn_list=> ["12345", ],          isbn     => "1235" );

say "Author: ", $test->author;

say "Test Dump";


$test->dump;

$test = MooBook->new(title => "My Book", year => 2010, series => "For Dummies", 
			isbn_list=> ["12345", ], isbn => "1235" );

$test->author("Bob Smith");
$test->author("Mark Jones");
$test->author("Alice Doe");
$test->author("Bob Smith");
$test->author("Bob Smith");

$test->dump_raw;
say "author method returns: ", $test->author;



my $test_name_ebook; 

$test_name_ebook = "[Business] Rich Dad's Before You Quit Your Job- 10 Real-Life Lessons Every Entrepreneur Should Know About Building a Million-Dollar Business (ebook, Kiyosaki, Hachette Book Group, 2005, ISBN 978-0-7595-1453-9, Converted, Orginal).pdf";

$test_name_ebook = "Rich Dad's Before You Quit Your Job- 10 Real-Life Lessons Every Entrepreneur Should Know About Building a Million-Dollar Business (ebook, Kiyosaki, Hachette Book Group, 2005, ISBN 978-0-7595-1453-9, Orginal) ) ).pdf";

$test->parse_ebook($test_name_ebook);

$test_name_ebook = "Rich Dad's Before You Quit Your Job- 10 Real-Life Lessons Every Entrepreneur Should Know About Building a Million-Dollar Business (2005, ISBN 978-0-7595-1453-9, Orginal).pdf";

$test->parse_ebook($test_name_ebook);

$test_name_ebook = "Rich Dad's Before You Quit Your Job- 10 Real-Life Lessons Every Entrepreneur Should Know About Building a Million-Dollar Business (ebook, Kiyosaki, Hachette Book Group, 2005, ISBN 978-0-7595-1453-9, Orginal).pdf";

$test = MooBook->new(title => "Test");
$test->parse_ebook($test_name_ebook);
$test->dump_raw;


