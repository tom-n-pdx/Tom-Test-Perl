#
# From Object Oriented Perl Chapter 6 - Named arguments
# Small tests to try out passing arguments
# 


#use strict;
#use warnings;
use Carp; 
use Params::Validate qw(validate :types);

	# Faster if define only once - needs to run before main code
	my %default = ( 
		desired_temperature => {	type => SCALAR, default => 4 }, 
		price 				=> { 	type => SCALAR, default => 1.20 }, 
		starting_change 	=> { 	type => ARRAYREF, 
											default => [ 0, 0, 50, 30, 10 ]}, 
		drinks 				=> { 	type => ARRAYREF, 
											default => [qw(cola orange lemonade squash water)]},	
		location 			=> { 	type => SCALAR }, 
		); 

		
# Use interets
interests(name => "Paul", language => "Perl", favourite_show => "Buffy");

interests(name => "Tom");

# Try positional?
# Generates warning and ignores positional arguments
#
interests("Tom");


# 2nd Exampe
&set_editing_tools(pager => "less", editor => "emacs");

# Use Defaults
&set_editing_tools;

# 3rd try
&DrinksMachine(location => "Division");



#
# Uses named paramaters
#
sub interests { 
	my(%args) = @_;
	
	my $name = $args{name} 						|| "Bob the Builder"; 
	my $language = $args{language} 				|| "none that we know"; 
	my $favourite_show = $args{favourite_show}	|| "the ABC News";

	print "${name}'s primary language is $language. " . "$name spends their free time watching $favourite_show\n";

}

#
# Named arguments with external defaults
#

sub set_editing_tools { 

	my %defaults = ( pager => "/usr/bin/less", editor => "/usr/bin/vim" );

	my (%args) = @_;

	# Here we join our arguments with our defaults. Since when 
	# building a hash it’s only the last occurrence of a key that \
	# matters, our arguments will override our defaults. 
	%args = (%defaults, %args);

	# print out the pager: 
	print "The new text pager is: $args{pager}\n";
	
	# print out the editor: 
	print "The new text editor is: $args{editor}\n";
	
}


#
# Reworked Class example - use Validate
#
# Consider Params::ValidationCompiler instead...
#
# The default_fields for a drinks machine. 
# desired_temperature - best temp for operation, deg. Cel 
# drinks - drink flavours 
# price - all drinks have the same price, standard decimal 
# starting_change - the change we start out with. Represented by a list 
# of the number of coins in following denominations: 
# 				$2, $1, 50c, 20c, 10c, 5c 
# 				so [qw/0 0 50 50 30 10/] makes, 0 x $2, 0 x $1, 
# 					50 x 50c, 50 x 20c, 30 x 10c, 10 x 5c. 
# 
# ’location’ is a required field, and has no default.


sub DrinksMachine { 
	#my %args = @_;

	# The line above is enough to get our named parameters, 
	# but we’re going to use Params::Validate to perform some 
	# basic input checking and set defaults.
	

	my %p = validate(@_, \%default);		# Requires hash ref
	print %p, "\n";

}

