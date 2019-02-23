#
# Supports Files object  -a File Object
#
#
# ToDo
# * consider refactor the calc dtime code into a sub
# * list files return list file objects?
# * check times, all times seem to chage ven if not write dir
# * skip system files in list - .DS_store
# * rework to use improve list dir file utility

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

package MooDir;
use Moose;
use namespace::autoclean;
use List::Util qw(max);
use FileUtility qw(dir_list);
use Carp;
use constant MD5_BAD => "x" x 32;

extends 'MooNode';

has 'dtime',
    is => 'ro',
    isa => 'Int',
    writer => '_set_dtime';

sub BUILDARGS {
    my ($class, @original) = @_;

    my %args = MooNode::_args_helper(@original);
    my $filepath = $args{filepath};

    # # If filepath defined - check is a file of some type
    # if ($filepath && ! -e $filepath){
    # 	croak "ERROR: constructor failed - tried to create Dir of non-existent file: ".$filepath;
    # }
    # if ($filepath && ! -d $filepath){
    # 	croak "ERROR: constructor failed - tried to create Dir of non-Dir file: ".$filepath;
    # }

    return \%args;
};


# 
# Moose arranges to have all of the BUILD methods in a hierarchy called when an object is constructed, from parents to children
#
sub BUILD {
    my $self=shift( @_);
    my $args_ref = shift(@_);
    my $opt_update_dtime = $$args_ref{'opt_update_dtime'}  // 1;
    my $update_stats     = $$args_ref{'update_stats'}      // 1; # default is do stat on file on creation

    if ($update_stats){
	if (!-e $self->filepath or !-d _) {
	    croak "ERROR: constructor failed - tried to create Node of non-existent or non-dir file: ".$self->filepath;
	}
    }

    if ($opt_update_dtime){
	$self->update_dtime;
    }

    return
}

#
# Calculate last time the dir or any file in dir changed
# NOTE: assumes online copy of dir. Note it does not look for changes in any dot files
#
sub _calc_dtime {
    my $self = shift(@_);

    # Start with latest of mtime, ctime
    my $dtime = max(@{ $self->stats }[9, 10]);

    # Check files (not subdir, socket, hidden, symlink)
    foreach ($self->list_filepaths){
	if (-f $_){
	    $dtime = max(  (stat(_) )[9, 10], $dtime);
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
    my $update_md5   =  delete $opt{update_md5}    // 0;
    # No check for unused opts - they are passed to dir_list

    
#    my @filepaths = dir_list(dir => $self->filepath, %opt);

    my ($filepaths_r, $names_r, $stats_AoA_r, $flags_AoA_r) = 
	FileUtility::dir_list(dir => $self->filepath, use_ref => 1, %opt);

    my @Nodes;
    foreach (0..( @{$filepaths_r} - 1) ){
	my $Node;
	my $filepath = ${$filepaths_r}[$_];
	

	if (-d $filepath){
	    $Node = MooDir->new(filepath => $filepath, 
				stats => @{$stats_AoA_r}[$_], update_stats => 0,
			        update_dtime => $update_dtime);
	} elsif (-f _) {
	    $Node =  MooFile->new(filepath => $filepath, 
				stats => @{$stats_AoA_r}[$_], update_stats => 0,
			        update_md5 => $update_md5);
	} else {
	    # warn("Unknown file type: $filepath");
	    $Node =  MooNode->new(filepath => $filepath, 
				stats => @{$stats_AoA_r}[$_], update_stats => 0);
	}

	push (@Nodes, $Node);
    }

    return(@Nodes);
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

my $dbtree_template1 = "A4 A2 A33 A9 (A11)13 A441";         # length 512

sub packed_str {
    my $self = shift(@_);
    
    my $type    = "Dir";
    my $extend  = " ";
    my $md5     = MD5_BAD;
    my $flags   = $self->flags;
    my @stats   = @{$self->stats};
    my $name    = $self->filepath;
    warn("Name > space 329 $name") if (length($name) > 329);

    my $str = pack($dbtree_template1, $type, $extend, $md5, $flags, @stats, $name);

    return($str);
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

