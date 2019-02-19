#
# Supports Files object  -a File Object
#
#
# ToDo
# * consider refactor the calc dtime code into a sub
# * list files return list file objects?
# * check times, all times seem to chage ven if not write dir
# * skip system files in list - .DS_store


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

package MooDir;
use Moose;
use namespace::autoclean;
use List::Util qw(max);
use FileUtility qw(dir_list);
use Carp;

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
    	croak "ERROR: constructor failed - tried to create Dir of non-existent file: ".$filepath;
    }
    if ($filepath && ! -d $filepath){
    	croak "ERROR: constructor failed - tried to create Dir of non-Dir file: ".$filepath;
    }

    return \%args;
};


# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    my $args_ref = shift(@_);
    my $opt_update_dtime = $$args_ref{'opt_update_dtime'}  // 1;

    if ($opt_update_dtime){
	$self->update_dtime;
    }

    return
}

#
# Calculate last time the dir or any file in dir changed
# NOTE: assumes online copy of dir. Note that by default it does not look for changes in any dot files
#
sub _calc_dtime {
    my $self = shift(@_);

    # Start with latest of mtime, ctime
    my $dtime = max(@{ $self->stat }[9, 10]);

    # Check files (not subdir, socket, hidden, symlink)
    # Check dir?
    foreach ($self->list_filepaths){
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
# sub list_filepaths {
#     my $self = shift(@_);

#     # Open dir & Scan Files
#     opendir(my $dh, $self->filepath);
#     my @filepaths = readdir $dh;
#     closedir $dh;

#     @filepaths = grep(!/^\./, @filepaths);                  # remove dot files
#     @filepaths = map($self->filepath.'/'.$_, @filepaths);   # make into absoule path         
#     @filepaths = grep( {-f} @filepaths);                    # remove none standard files (drop dirs, sockets, etc)
    

#     return(@filepaths);
# }

sub list_filepaths {
    my $self = shift(@_);
    my %opts  = @_;

    my @filepaths = dir_list(dir => $self->filepath, %opts);

    return(@filepaths);
}
#
# Dir list obj method
# Returns a list of file objects
# Skips ., .. and other hidden files by default
# it does include un-readable normal files
#
sub List {
    my $self = shift(@_);
    my %opt = @_;
    my $update_dtime =  delete $opt{update_dtime}  // 0;
    my $update_md5   =  delete $opt{update_md5}  // 0;
    # No check for unused opts - they are passed to dir_list

    
    my @filepaths = dir_list(dir => $self->filepath, %opt);

    my @Files;
    foreach my$filepath (@filepaths){
	my $File;
	if (-d $filepath){
	    $File =  MooDir->new(filepath => $filepath,  opt_update_dtime => $update_dtime, %opt);
	} elsif (-f _) {
	    $File =  MooFile->new(filepath => $filepath, opt_update_md5 => $update_md5, %opt);
	} else {
	    # warn("Unknown file type: $filepath");
	    $File =  MooNode->new(filepath => $filepath);
	}

	# If hidden file, don't put on list
	# next if ($File->ishidden);

	push(@Files, $File);
    }

    return(@Files);
}

#
# Live check for if anything changed on disk
# Can't use moose extend becuase need to modify return values
# Does not update stats - just checks against file on disk and returns if changed
#
sub ischanged {
    my $self = shift(@_);

    my %opt = @_;
    my $check_dtime =  delete $opt{check_dtime}  // 1;
 
    # First call ischanged for the dir file itself
    my @changes = $self->SUPER::ischanged;

    # If any of the file check items changed -  no need to do the expensive dtimes check
    # this avoids redoing check for file exist or is still dir
    # Know will have to rereun list of files and see what was added / deleted
    #
    return (@changes) if (@changes);

    if ($check_dtime && $self->dtime && $self->dtime != $self->_calc_dtime){
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

