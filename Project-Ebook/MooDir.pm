#
# Supports Files object  -a File Object
#
#
# ToDo
# * consider refactor the calc dtime code into a sub
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


around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = @_;
    my $filepath =$args{filepath};

    if (! -d $filepath){
    	die "constructor failed - tried to create Dir of non-dir file: $filepath";
    }

    return $class->$orig(@_);;
};





#
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    # my $args_ref = shift(@_);

    my $filepath =  $self->filepath;
   
    # die "File Obj Construction failed - file is a not readable: ".$self->filename if !$self->isreadable;
    # die "File Obj Construction failed - file is not a dir: ".$self->filename if !$self->isdir;

    return
}

#
# Extend update_stat medthod to find when last change to any file in dir
# this sub gets called after standard update_stat is called
# Normally update stat called as part of node object creating so will get called anytime
# dir object created.
#
after 'update_stat' => sub {
    my $self = shift(@_);

    #
    # We need to know when any file in dir has changed
    # Initalize to greater of the dir ctime or mtime
    #
    my @stat = @{$self->stats};
    my $dtime = max($stat[9], $stat[10]);

    # 
    # Loop through all the files in the dir and take max of mtime & ctime
    # skip dirs & other non file files (dirs, sockets, etc)
    #
    # ISSUE: Assumes live version
    #
    foreach ($self->list_files){
	if (-f $_){
	    @stat = stat($_);
	    $dtime = max($stat[9], $stat[10], $dtime);
	}
    }

    $self->_set_dtime($dtime);
    return;
};


#
# Dir list method
# Returns a list of filepath not objects
# Skips ., .. and other hidden files - may need to create option for all files, etc.
# 
sub list_files {
    my $self = shift(@_);

    # Open dir & Scan Files
    opendir(my $dh, $self->filepath);
    my @filepaths = readdir $dh;
    closedir $dh;

    @filepaths = grep(!/^\./, @filepaths);	                            # remove dot files         
    @filepaths = map($self->filepath.'/'.$_, @filepaths);	    # make into absoule path         

    return(@filepaths);
}

#
# Extend ischanged to include dtime check
#
# sub ischanged {
#    my $self = shift(@_);
#    my $other = shift(@_);
 
   # First call parents ischanged
#    my @changes = $self->SUPER::ischanged($other);

#    # If any of the file check items of changed - then no need to do the expensive dtimes check
#    # this avoids redoing check for file exist or is still dir
#    return (@changes) if (@changes);

#    # Can use stored stats since know didn't change
#    my @stat = $self->stats;
#    my $dtime = max($stat[9], $stat[10]);

#    # Find max of ctime / mtime for all normal files in dir (no check dirs or sockets, links)
#    foreach ($self->list_files){
# 	if (-f $_){
# 	    @stat = stat($_);
# 	    $dtime = max($stat[9], $stat[10], $dtime);
# 	}
#     }

#    push(@changes, "dtime") if ($self->dtime != $dtime);
   
#    return @changes;
# }


# #
# # extend isdiskchanged
# #
# sub isdiskchanged {
#    my $self = shift(@_);
#    my $other = shift(@_);
 
#    # First call parents iseqal
#    my @changes = $self->SUPER::ischanged($other);

#    # Now check dtime
   
#    push(@changes, "dtime") if ($self->dtime != $other->dtime);
   
#    return @changes;
# }




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

