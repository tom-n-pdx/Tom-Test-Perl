#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
$|++;   			# Autoflush

use LWP;
use HTTP::Date;
# use Time::localtime;            # Printing stat values in human readable time
# use Term::ProgressBar;
use HTML::TreeBuilder 5 -weak;

# my $url       = 'http://disobey.com/';
# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://libgen.io/search.php?mode=last';
my $url         = 'http://booksdescr.org/item/index.php?md5=B5F6E6170362590813623D48B865C043';
my $url         = 'http://booksdescr.org/item/index.php?md5=F3452353C2B7B7D37E3479B312A03ACC';
# my $url       = 'http://classify.oclc.org/classify2/';
# my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire
# my $url         = 'https://www.google.com/';

# /html/body/table/tbody/tr[8]/td[2]
# Many URL's don't provide content length

	 
my $browser = LWP::UserAgent->new(  );
$browser->agent('Mozilla/4.76 [en] (Win98; U)'); # Required cloudfire

say "Test URL: $url";
my $response  = $browser->get( $url );

print "Status: ", $response->status_line, "\n";

say "Content Type: ", $response->content_type // "Undefined";
say "Last Modified(Epoch): ", $response->last_modified // "Undefined", "  ", time2str($response->last_modified);
say "Title: ", $response->title;


my $tree = HTML::TreeBuilder->new;
$tree->implicit_tags(1);


#my $p = HTML::TreeBuilder->new_from_content( $response->content );
$tree->parse_content($response->content);

# say $p->dump;
# exit;

# Returns 1st H1
# say "\n\n";
# my $h1 = $tree->look_down('_tag', 'h1');


# my $body = $tree->look_down('_tag', 'body');

# if (! $body) {
#     say "No body";
# } else {
#     say "Found Body";
# }

my $table = $tree->look_down('_tag', 'table');
die ("No Table") if (!$table);




# Look for just book title
# xpath: /html/body/table/tbody/tr[2]/td[3]
my $book_title = $table->look_down('_tag' => 'td',
				   colspan => 2);

say "Book Title: ", $book_title->as_trimmed_text;


#
# ISBN
#
# xpath /html/body/table/tbody/tr[8]/td[2]
my $book_isbn = $table->look_down('_tag'       => 'td',
				  sub {
				      $_[0]->as_trimmed_text() =~ /ISBN/i;
				  })->right->as_trimmed_text;
				  

# $book_isbn = ($book_isbn->parent->look_down('_tag' => 'td'))[1]->as_trimmed_text;
say "Book ISBN: ", $book_isbn;

#
# Year
#
# Year /html/body/table/tbody/tr[6]/td[2]
my $book_year = $table->look_down('_tag' => 'td',
				  sub {
				      $_[0]->as_trimmed_text() =~ /year/i;
				  });

my @book_year = $book_year->parent->look_down('_tag' => 'td');
say "Book Year: ", $book_year[1]->as_trimmed_text+0;


#
# Publisher
#
# xpath /html/body/table/tbody/tr[5]/td[2]
my $book_pub = $table->look_down('_tag' => 'td',
				  sub {
				      $_[0]->as_trimmed_text() =~ /publisher/i;
				  });

my @book_pub = $book_pub->parent->look_down('_tag' => 'td');
say "Book Year: ", $book_pub[1]->as_trimmed_text;

#
# Author
#
my $book_author = $table->look_down('_tag' => 'td',
				  sub {
				      $_[0]->as_trimmed_text() =~ /author/i;
				  });

my @book_author = $book_author->parent->look_down('_tag' => 'td');
say "Book Auhor: ", $book_author[1]->as_trimmed_text;


exit;



