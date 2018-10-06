#
# Supports Files object  -a File Object
#
#
# ToDo
# * consider refactor the calc dtime code into a sub
# * list files return list file objects?
#


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

package MooDir;
use Moose;
use namespace::autoclean;
use List::Util qw(max);

extends 'MooNode';

has 'dtime',
    is => 'ro',
    isa => 'Int',
    writer => '_set_dtime';

sub BUILDARGS {
    my ($class, @original) = @_;

    my %args = MooNode::_args_helper(@original);
    my $filepath = $args{filepath};

    # If filepath defined - check is a file of some type
    if ($filepath && ! -e $filepath){
    	die "ERROR: constructor failed - tried to create Dir of non-existent file: ".$filepath;
    }
    if ($filepath && ! -d $filepath){
    	die "ERROR: constructor failed - tried to create Dir of non-Dir file: ".$filepath;
    }

    return \%args;
};


# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    my $args_ref = shift(@_);

    $self->update_dtime;

    return
}

#
# Calculate last time the dir or any file in dir changed
# NOTE: assumes live version
#
sub _calc_dtime {
    my $self = shift(@_);

    # Start with latest of mtime, ctime
    my $dtime = max(@{ $self->stat }[9, 10]);

    # Check files (not subdir, socket, hidden)
    foreach ($self->list_files){
	if (-f $_){
	    $dtime = max(  (stat($_) )[9, 10], $dtime);
	}
    }

    return $dtime;
}

#
# Update the dtime for dir
#
sub update_dtime {
    my $self = shift(@_);
    
    my $dtime = $self->_calc_dtime;
    $self->_set_dtime($dtime);

    return;
};


#
# Dir list method
# Returns a list of filepath not objects
# Skips ., .. and other hidden files - may need to create option for all files, etc.
# it does include un-readable normal files
# Store a version?
# 
sub list_files {
    my $self = shift(@_);

    # Open dir & Scan Files
    opendir(my $dh, $self->filepath);
    my @filepaths = readdir $dh;
    closedir $dh;

    
    @filepaths = grep(!/^\./, @filepaths);	                            # remove dot files
    @filepaths = map($self->filepath.'/'.$_, @filepaths);	    # make into absoule path         
    @filepaths = grep( {-f} @filepaths);                                       # remove none standard files (drop dirs, sockets, etc)  -check absolute path

    return(@filepaths);
}

#
# Live check for if anything changed on disk
# Can't use moose extend becuase need to modify return values
# Does not update stats - just checks against file on disk and returns if changed
#
sub ischanged {
    my $self = shift(@_);
 
    # First call ischanged for the dir file itself
    my @changes = $self->SUPER::ischanged;

    # If any of the file check items changed -  no need to do the expensive dtimes check
    # this avoids redoing check for file exist or is still dir
    # Know wil have to rereun list of files and andd see what added / deleted
    #
    return (@changes) if (@changes);

    if ($self->dtime && $self->dtime != $self->_calc_dtime){
	push(@changes, "dtime");
    }

   return @changes;
}



#
# Extend dump method to include dtime
#
sub dump {
   my $self = shift(@_);
 
   # First call my parents dump
   $self->SUPER::dump();

   # Now dtime - last change to any file in dir including dir itself but excluding subdirs
   print "\tDtime: ", Time::localtime::ctime($self->dtime), "\n";

   return;
}

__PACKAGE__->meta->make_immutable;
1;

