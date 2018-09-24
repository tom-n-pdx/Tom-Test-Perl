#
# Object Oriented Perl - Chapter 10 Inheritence
#

use strict;
use warnings;
use NEXT;

#
# Need to make sure any ISA class does exist
#

package PerlTrainer;		# Works Perl > 5.6
# Must use Our - not My - so exported
our @ISA = qw(Trainer Geek);

# sub new { 
#     my ($class, @args) = @_;

#     # Create an anonymous hashref and naively fill in our fields.
#     my $self = { _data => "PerlTrainer"};
    
#     return bless($self, $class);
# }


#
# Constructor method. Just creates the hash and then passes 
# the work off to the initialiser method.
#
sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless($self,$class);

    $self->_init(@args);

    return $self;
}

sub _init {
    my ($self, %args) = @_;
    my $PACKAGE = __PACKAGE__;	                             # Magic variable with name of class

    # Initialise the object for all of our base classes. 
    #$self->Trainer::_init(%args); 
    # $self->Geek::_init(%args);

    #
    # Automate calling all parents _init if exist
    #
    # foreach my $parent (@ISA) {
    # 	my $parent_init = $parent->can("_init"); 
    # 	$self->$parent_init(%args) if $parent_init;
    # }

    # Call all parents using NEXT module - even in diamond calls easy parent oncly once
    $self->NEXT::DISTINCT::_init(%args);

    # Class-specific initialisation. 
    # $self->{_perl_courses} = $args{courses} || [];

    # Return the initialised object. 
    return $self;
}


package Trainer;
our @ISA = ("Geek");

#
# Constructor method. Just creates the hash and then passes 
# the work off to the initialiser method.
#
sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless($self,$class);

    $self->_init(@args);

    return $self;
}

#
# Initialiser method, does all the hard work. 
#
sub _init {
    my ($self, %args) = @_;

    # Initialise the object for parents class  -works ONLY for single inheratence
    # Finds 1st _init in @ISA
    # Call my parent’s _init function. 
    $self->SUPER::_init(%args);


    # Class-specific initialisation. 
    $self->{_perl_courses} = $args{courses} || [];

    # Return the initialised object. 
    return $self;
}


sub debug {
    my ($self, @args) = @_;
    
    print "Class Trainer Value: $self \n";
}

package Geek;

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless($self,$class);

    $self->_init(@args);

    return $self;
}

sub _init {
    my ($self, %args) = @_;

    # Class-specific initialisation. 
    $self->{_name} = $args{"name"} || "bob";

    # Return the initialised object. 
    return $self;
}

package Teacher;

package Writer;

1;

