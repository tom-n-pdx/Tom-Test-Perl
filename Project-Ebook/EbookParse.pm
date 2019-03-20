#!/usr/bin/env perl
#
# Apply standard fixe-up regs o check files names
# * rework unicode
# * check for unicode characters
# * check suffix
#

package EbookParse v0.1.0;
use Exporter qw(import);
our @EXPORT_OK = qw(publisher_ok publisher_fixup %publisher_legal);

# Standard uses's
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

# use Text::Unaccent::PurePerl;
# use File::Basename;
# use List::Util qw(min max);	        # Import min()

#
# On startup initiaize legal publisher list
#

my $data =<<'END_DATA';
A Book Apart
A K Peters
ABC-CLIO
ACSD
Adobe
AIAA
Allen & Unwin
AMACOM
Academic Press
Adams Media
Addison-Wesley
Alpha
Amazon
America's Test Kitchen
AMS
Apress
Artech
Artisan
APA
Ashgate
Atlantis Press
Auerbach
Basic Books
BCS
Berrett-Koehler
Bedford
Big Nerd Ranch
Birkhauser
Belknap
Black Library
Bloomsbury
Brill
Britannica
Butterworth-Heinemann
Business Expert
Brooks-Cole
Brookings Institution
Cambridge
Career Press
Cisco Press
CRC Press
CreateSpace
Cengage
Chandos Publishing
Charles River
Chronicle Books
Chelsea House
Clarkson Potter
Columbia
Cool Springs
Continuum
Course Technology
Creative Publishing
Crown
Crown Business
Delmar
De Gruyter
Digital Press
DK
Dover
Doubleday
Ecco
Emerald
Entrepreneur Press
Edward Elgar
Elsevier
FT Press
Facts On File
Fair Winds
Falcon Guides
Focal Press
Free Press
Farrar Straus and Giroux
Games Workshop
Guilford Press
Globe Pequot
Good Books
Gooseberry Patch
Good Move
Gower
Greenwood
Hay House
HBR
Harmony
HarperCollins
Harper Business
Harvard
Harvard Business Press
Houghton Mifflin
How To Books
Holy Macro Books
Human Kinetics
Hungry Minds
Hunter Publishing
IBM Press
IDEA
IDG
IEEE
IET
IGI Global
Imperial College
Imagine
Insight Guides
InTech
IOS Press
Island Press
Ishi
Java Code Geeks
JIST
Jossey-Bass
Johns Hopkins
Jones & Bartlett
Kiseido
Kluwer
Kogan-Page
Leanpub
LearningExpress
Lawrence Erlbaum
Laurence King
Lonely Planet
Longman
Ludwig von Mises
Marshall Cavendish
Marcel Dekker
Maker Media
MIT Press
Manning
Macmillan
McGraw-Hill
McFarland & Company
Meyer & Meyer Sport
Mercury Learning
Morgan-Kaufmann
Moon Travel
Murach
Microsoft
Midland
Morgan & Claypool
NA
National Academies
Naval Institute Press
New Age
New Riders
New Harbinger
New York University
Newnes
Nicholas Brealey
No Starch
NoLo
North Holland
Nova Science
O'Reilly
Open Design
Open University Press
Oracle Press
OECD
Orchard Publications
Osborne
Osprey
Oxford
Palgrave Macmillan
Packt
Peachpit
Pearson
Pen & Sword
Penguin
Pfeiffer
Pluto Press
Portfolio
Praeger
Pragmatic
Premier Press
Prentice-Hall
Prima
Princeton University
Productivity Press
QA International
Quarto
Quiver
Que
Random House
Rocky Nook
Rockport
Rodale
Routledge
Rowman & Littlefield
Rough Guides
Running Press
Sage
Sams
SAS
Sense
Shambhala
Simon & Schuster
Skyhorse
Sourcebooks
South-Western
SG Games
Stylus
St. Martin's
Smashing
SPIE
SyncFusion
Syngress
The Economist
University of California
Taunton Press
Ten Speed
The Scarecrow Press
Thomson
Tuttle
Summersdale
Stanford University
Sybex
Springer
SIAM
SitePoint
Syncfusion
Wadsworth
White Wolf
William Morrow
Worth
Workman
Writer's Digest
University of Chicago
University of Minnesota
University of Michigan
University of Nebraska
University of Pennsylvania
Visibooks
Verso
W. W. Norton
Wiley
Wiley-Blackwell
Wordware
World Scientific
Wrox
Yale
YYYY
Zephyros
Zed
END_DATA


our %publisher_legal;
foreach (split(/\n/, $data)){
    chomp;
    my $publisher = $_;;
    $publisher_legal{lc($publisher)} = $publisher;
}

#
# Now Initalize list of publisher fix-ups
#
$data =<<'END_DATA';
^\s+;;
\s+$;;
\s{2,};;
END_DATA

our (@publisher_long, @publisher_short);

# Read Regular expression into arrays
my $i= 0;
foreach (split(/\n/, $data)){
    ($publisher_long[$i], $publisher_short[$i]) = split(/;/);
    $i++;
}


sub publisher_ok {
    my $publisher_check = shift(@_);
    my $ok = 0;

    if ($publisher_legal{lc($publisher_check)}){
	$ok = 1;
    }

    return $ok;
}

sub publisher_fixup {
    my $publisher_long = shift(@_);
    my $publisher_short;

    my %publisher_fix = ("Prentice Hall"          => "Prentice-Hall",
			 MIT                      => "MIT Press",
			 "Morgan Kaufmann"        => "Morgan-Kaufmann", 
		         "Pragmatic Bookshelf"    => "Pragmatic",
			 "Pragmatic Programmers"  => "Pragmatic",
			 "Pragmatic Programmer"   => "Pragmatic",
		         "Microsoft Press"        => "Microsoft",
		         "Palgrave"               => "Palgrave Macmillan",
			 "Addison Wesley"         => "Addison-Wesley",
			 "Cengage Learning"       => "Cengage",
			 "Taunton"                => "Taunton Press",
			 "Oxford University"      => "Oxford",
			 "Artech House"           => "Artech",
			 "The Guilford Press"     => "Guilford Press",
			 "Premier"                => "Premier Press",
			 "Nova"                   => "Nova Science",
			 "Blackwell"              => "Wiley-Blackwell",
			 "IGI"                    => "IGI Global",
			 "ISR"                    => "IGI Global",
			 "Kogan Page"             => "Kogan-Page",
			 "Academic"               => "Academic Press",
			 "IBM"                    => "IBM Press",
			 "CRC"                    => "CRC Press",
			 "Morgan-Claypool"        => "Morgan & Claypool",
			 "Cisco"                  => "Cisco Press",
			 "Pluto"                  => "Pluto Press",
			 "XXXX"                   => "YYYY",
			 "Gabler"                 => "Springer",
			 "No Starch Press"        => "No Starch",
			 "Princeton"              => "Princeton University",
			 "Focal"                  => "Focal Press",
			 "Harper Collins"         => "HarperCollins",
			 "Cool Springs Press"     => "Cool Springs",
			 "Rough Guide"            => "Rough Guides",
			 "New Harbinger Publications" => "New Harbinger",
			 "University Of Chicago"  => "University of Chicago",
			 "SyncFusion"             => "Syncfusion",
			 "Guilford"               => "Guilford Press",
			 "Chronicle"              => "Chronicle Books",
			 "Cambridge University"   => "Cambridge",
			 "SAGE"                   => "Sage",
			 "Jones and Bartlett"     => "Jones & Bartlett",
			 "Prentice"               => "Prentice-Hall",
			 "Course-Technology"      => "Course Technology",
			 "Korgan-Page"            => "Kogan-Page",
			 "Osprey Publishing"      => "Osprey",
			 "Chandos"                => "Chandos Publishing",
			 "Academic-Press"         => "Academic Press",
			 "Brooks_Cole"            => "Brooks-Cole",
			 "Yale University"        => "Yale",
			 "Cambridge University Press" => "Cambridge", 
			 "Harper"                 => "HarperCollins",
			 "Rowman-Littlefield"     => "Rowman & Littlefield",
			 "Business Expert Press"  => "Business Expert",
			 "BEP"                    => "Business Expert",
			 "Morgan-Kaufman"         => "Morgan-Kaufmann",
			 "Morgan _ Claypool"      => "Morgan & Claypool",
			 "Ten Speed Press"        => "Ten Speed",
			 "Tuttle Publishing"      => "Tuttle",
			 "Meyer & Meyer"          => "Meyer & Meyer Sport",
			 "Sense Publishers"       => "Sense", 
			 "Apres"                  => "Apress",
			 "Rough"                  => "Rough Guides",
			 "Gruyter"                => "De Gruyter",
			 "McFarland"              => "McFarland & Company",
			 "McFarland-Company"      => "McFarland & Company",
			 "Basic"                  => "Basic Books",
			 "Newness"                => "Newnes",
			 "Jones-Bartlett"         => "Jones & Bartlett",
			 "Harvard University"     => "Harvard",
			 "William Morrow Cookbooks" => "William Morrow",
			 "Maker"                  => "Maker Media",
			 "W.W. Norton"            => "W. W. Norton",
			 "Oracle"                 => "Oracle Press",
			 "Information Science"    => "IGI Global",
			 "Oxford University Press" => "Oxford",
			 "Pen and Sword"          => "Pen & Sword",
			 "McGraw-Hill Education"  => "McGraw-Hill",
			 "Brooks:Cole"            => "Brooks-Cole",
			 "Gabler Verlag"          => "Springer",
			 "Fair Winds Press"       => "Fair Winds",
			 "University of Chicago Press" => "University of Chicago",
			 "Palgrave-Macmillan"     => "Palgrave Macmillan",
			 "Marshall-Cavendish"     => "Marshall Cavendish",
		     );
    

    if ($publisher_long =~ /O.*Reilly/i){
	$publisher_short = "O'Reilly";
    } else {
	$publisher_short = $publisher_fix{$publisher_long};
    }
    



    return($publisher_short // $publisher_long);

}


#
# Notes Publishers
# Course Technology bought Premier Press 2002
# Thomson Learning became Cengage Learning 2007
# Blackwell was bought by Wiley in 2007 and became Wiley-Blackwell
# Ashgate became part of Routledge in 2016

1; # End Module
