#
# Supports generic Book Object
#
# ToDo
# * if ask for author, use author, author list of author not set?
# * validate isbn, return a isbn if list set and isbn is not
# * generate  file name
# * parse  filename
# * move balanced to utility lib
 

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


#use File::Basename;         # Manipulate file paths
#use Time::localtime;        # Printing stat values in human readable time
# use Data::Dumper qw(Dumper);           # Debug print

package MooBook v0.1.0;
use Moose;
use namespace::autoclean;

has 'title',			         # title of book
    is => 'rw', 
    isa => 'Str',
    required => 1;

has 'subtitle',			         # optional subtitle of book
    is => 'rw', 
    isa => 'Str',
    required => 0;

# has 'author',			         # do I create fake author, is just access to author list?
#     is => 'rw', 
#     isa => 'Str',
#     required => 0;

has 'author_list',                       # optional subtitle of book
    is => 'rw', 
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    required => 0;

has 'publisher',			 # optional subtitle of book
    is => 'rw', 
    isa => 'Str',
    required => 0;

has 'series',			         # optional subtitle of book
    is => 'rw', 
    isa => 'Str',
    required => 0;

has 'year',			         # optional year date published - validate makes sense
    is => 'rw', 
    isa => 'Int',
    required => 0;

# has 'isbn',			         # optional isbn  -do I make a secondary access to isbn list?
#     is => 'rw', 
#     isa => 'Str',
#     required => 0;

has 'isbn_list',			         # optional year date published
    is => 'rw', 
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    required => 0;

#
# Helper Function Last name
# Given a author name - try to guess at last name
#
sub _author_last_name {
    my $name = shift(@_);

    my @values = split(/\s/, $name);
    

    return($values[-1]);
}






#
# Psudo value author is actual value from author list
# get author - returns last word in 1st elelemt of author_list
# set author - if word not in list, unshifts into top, if in list, moves item to top
#

sub author {
    my $self = shift(@_);
    my $author;

    # Get- return 1st Value in list - first author - last name (last word in string)
    if (@_ ==0){
	$author = ${$self->author_list}[0];
	$author = _author_last_name($author);
	return ($author);
    } else {
	#
	# If author, as regexp matches any entry in author list, do not add to list
	#
	$author = shift(@_);
	if (! grep($_ =~ /$author/, @{$self->author_list})){
	    push(@{$self->author_list}, $author); 
	}
    }
}


sub isbn {
    my $self = shift(@_);
    my $isbn;

    # Get 1st Value in list
    if (@_ ==0){
	$isbn = ${$self->author_list}[0];
	return ($isbn);
    } else {
	$isbn = shift(@_);
	# say "Insert isbn: $isbn"; 
	push(@{$self->isbn_list}, $isbn); 
    }
}

#
# Parse a filename into bobject fields
#
# assumes filename includes a extension
#
use File::Basename;         # Manipulate file paths

sub parse_ebook {
   my $self = shift(@_);
   my $filename = shift(@_);

    my  ($name, $path, $ext) = File::Basename::fileparse($filename, qr/\.[^.]*/);
   
   #
   # First check that name has balanced ( )'s & that includes a (ebook, ...)
   #
   if (! balanced($name)){
       warn "WARN: Unbalanced parens in: $name";
       return 0;
   }
   if ( $name !~ /\((ebook.*)\)/){
       warn "WARN: no ebook tag: $name";
       return 0;
   }

   $name =~ /(.*)\((ebook.*)\)/;
   my $rest = $1;

   # Ebook string (ebook, author, publisher, year, ....., Orginal)
   my ($type, $author, $publisher, $year, @values) = split(/,\s*/, $2);

   if ($type ne "ebook"){
       warn "WARN: not a ebook tag: $type in $name";
       return 0;
   }

   $self->author($author);
   $self->publisher($publisher);
   $self->year($year);

   #
   # Parse rest of @values
   # * where do I put @vaues I don't use?
   #
   
   
   # How do I tell series from other comments in rest of title?
   $self->title($rest);
   

   return 1;
}
   

sub dump {
   my $self = shift(@_);
 
   print "Title:    ", $self->title, "\n";
   print "Subtitle: ", $self->subtitle // "", "\n";
   print "Year:     ", $self->year // "", "\n";

}

   
sub dump_raw {
   my $self = shift(@_);
   my $class = blessed( $self );
   # Moose semi unfriendly - uses raw access to class variables... may break in future
   print "INFO: Dump Raw: Book: ", $self->title, " Class: $class\n";

   # #my %atributes = (isfile => 'Bool', isdir => 'Bool', isreadable => 'Bool', stat =>'ArrayRef');

   my @keys = sort keys(%$self);
   foreach (@keys){
       # my $type = $atributes{$_} // "String";
       my $value = $$self{$_} // "";
       my $type = ref($value);
       # $string = true($string) if ($type eq "Bool");
       $value = join(', ',  @{$value}) if ($type eq "ARRAY");
       printf  "\t%-10s %s\n", $_, $value;
   }
}

#
# Utility
#
sub balanced {
    my($str )= @_;
    my @d;

    while(  $str =~ m/([\(\[\{])|([\)\]\}])/g ) {
	# Openning
        if (  $1  ) {
	    # say "match openning: \$1 $1";
	    my $close = $1;
	    $close =~ tr/([{/)]}/;
	    push(@d, $close);
        } else {
	    # return 0 if $#d == -1;                         # no openning
	    my $open = pop(@d);
	    # say "match closing: \$2 $2 vs $open";
	    return 0 if !$open || $open ne $2;                      # wrong openning
        }
    }
    return $#d != 0;
    # return 1;
}




__PACKAGE__->meta->make_immutable;
1;

