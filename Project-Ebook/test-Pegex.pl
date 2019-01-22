#!/usr/bin/env perl
#

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use Pegex;			# Parser
use Pegex::Parser;
use Pegex::Grammar;
use Pegex::Tree;
use Pegex::Tree::Wrap;
use Pegex::Input;

use Data::Dumper;


#
# Handle 
# 

#
# Define Grammer using Here Is Doc

my $grammar_text = <<EOF;
%grammar lib-genesis
%version 0.01

book: <series>? <author>? (<title-date> | <title>) <suffix>? / - /

series: /- LSQUARE  -  ( ANY+ ) -  RSQUARE -/  

author: /- (  ANY*  ) SPACE DASH SPACE -/

# Due to inabality to distiguish trailing parens - must make date part of title
title-date: / ( ANY+) - LPAREN - <pub-date> - RPAREN/

# May optionally contain a publisher
pub-date: / - ( DIGIT+ ) ( COMMA - ( ANY* ))? - /

title: / ( ANY+) -/

suffix: /\ (_v DIGIT+ )/

EOF

my $test;
$test = " [ Dummies Guide]   Smith, Bob - Dummies Guide to (bad) parsing (  9999, Wiley (Inc.) )_v11";
# $test = " [ Dummies Guide]   Smith, Bob - Dummies Guide to (bad) parsing";
#$test = " - Dummies Guide to (bad) parsing";
# my $result = pegex($grammar)->parse($test);

my $grammar = Pegex::Grammar->new(text => $grammar_text);
my $receiver = Pegex::Tree->new();
# my $receiver = Pegex::Tree::Wrap->new();
my $parser = Pegex::Parser->new(
    grammar => $grammar,
    receiver  =>  $receiver,
    debug => 1,
);
my $input = Pegex::Input->new(string => $test);
my $result = $parser->parse($input);

say Dumper($result);



