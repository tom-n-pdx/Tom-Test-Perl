#!/usr/bin/env perl
#
use Modern::Perl; 		   # Implies strict, warnings
use autodie;
$|++;


use WWW::Mechanize;
use File::Basename;


# my $url       = 'http://disobey.com/';
# my $url       = 'http://disobey.com/amphetadesk/';
# my $url       = 'http://libgen.io/search.php?mode=last';
# my $url         = 'http://booksdescr.org/item/index.php?md5=B5F6E6170362590813623D48B865C043';
# my $url         = 'http://booksdescr.org/item/index.php?md5=F3452353C2B7B7D37E3479B312A03ACC';
my $url         = 'http://booksdescr.org/';
# my $url       = 'http://classify.oclc.org/classify2/';
# my $url       = 'https://dlfeb.com/searchd/d?query=%2A%20%3Aextension%20pdf%20%3Aposted%20%3C%202d'; # Restricts Access - cloudfire
# my $url         = 'https://www.google.com/';
# my $url        = "http://search.cpan.org";


my $mech = WWW::Mechanize->new( );
$mech->agent_alias("Mac Safari");

$mech->get( $url );
say "Status:   ",  $mech->success;
say "Response: ",  $mech->response->message, "  ", $mech->response->status_line;
say "Success:  ",  $mech->response->is_success;

die $mech->response->status_line unless $mech->success;

print $mech->title, "\n";

my @forms = $mech->forms;
say "Forms found: ", scalar(@forms);


# Select the form, fill the fields, and submit
$mech->form_number( 1 );
$mech->field( req => "python" );
# $mech->field( mode => "author" );
$mech->submit(  );

$mech->success or die "post failed: ", $mech->response->status_line;

# Exract All links
my @links = $mech->links;
say "Links found: ", scalar(@links);

foreach my $link(@links){
    next unless $link->url =~/book\/index.php\?md5/i;
    say "Text: ", $link->text, " Link: ", $link->url;
}


# try dump
# say $mech->content( format => 'text' );
say $mech->content();

# my $html = $mech->content; # Big text string of HTML






# /html/body/table/tbody/tr[8]/td[2]
# Many URL's don't provide content length

	 
# my $browser = LWP::UserAgent->new(  );
# $browser->agent('Mozilla/4.76 [en] (Win98; U)'); # Required cloudfire

# say "Test URL: $url";
# my $response  = $browser->get( $url );

# print "Status: ", $response->status_line, "\n";

# say "Content Type: ", $response->content_type // "Undefined";
# say "Last Modified(Epoch): ", $response->last_modified // "Undefined", "  ", time2str($response->last_modified);
# say "Title: ", $response->title;


# # Now that we have our content, initialize a new HTML::TokeParser object with it.
# my $stream = new HTML::TokeParser(\$response->content);

# # Look at each table entry
# # while (my $tag = $stream->get_tag("tr")) {                        # Looks for next tr start tag

# #   # Is there a 'class' attribute?  Is it 'cf'?
# #   if ($tag->[1]{valign} and $tag->[1]{valign} eq "top") {

# #       # Store everything from <a> to </a>.
# #       my $result = $stream->get_trimmed_text("/td");

# #       # Remove leading.
# #       # '&nbsp;' character.
# #       # $result =~ s/^.//g;

# #       # Echocloud sometimes returns the artist we searched
# #       # for as one of the results.  Skip the current loop
# #       # if the string given matches one of the results.
# #       # next if $result =~ /$artist/i;

# #       # And we can print our final result.
# #       print "$result\n";
# #   }
# # }

# #
# # e.g. - find every link
# #
# while (my $token = $stream->get_tag("a")) {
#     my $url = $token->[1]{href} || "-";
#     my $text = $stream->get_trimmed_text("/a");

#     next if ($url =~ /search\.php\?req=topicid/);

#     print "$url\t$text\n";
# }
