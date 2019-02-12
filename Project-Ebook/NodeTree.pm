#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * Make remove work on Objects
# * add make sure insert, delete work both for single or list
# * find way to pass no md5 or no dtime to insert
# * save / restore
# * look for dupes in size, md5
# * itterator method to cycle over whole tree
# * Need update if re-calc MD5 for file gets added, fixup HoA's
# * add "name"  filepath for tree

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


package NodeTree;
use Moose;
use namespace::autoclean;

use Carp;

# use Data::Dumper qw(Dumper);           # Debug print
# use Storable qw(nstore_fd nstore retrieve);
# use Fcntl qw(:DEFAULT :flock);

# A list of the files in collection. Hashed by hash method of object. 
# Will work on any datatype that can generate a hash and has a size
#
has 'nodes',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    
# A hash of the size of the nodes in the collection - hash of arrays of refs to node objs
#
has 'size_HoA',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    
# A hash of the size of the nodes in the collection - hash of arrays of refs to node objs
# 
has 'md5_HoA',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    

#
# Insert Node Obj(s) into tree
#
sub insert {
    my $self = shift( @_);
    my @objs =  @_;
    
    foreach my $obj (@objs){
	croak "not a node object" if ! $obj->isa('MooNode');

	my $hash = $obj->hash;
	if (defined ${$self->nodes}{$hash} ){
	    carp "WARN: Inserting dupe node. hash=$hash";
	} else {
	    ${$self->nodes}{$hash} = $obj;

	    # Now insert into Size_HoA
	    my $size = $obj->size;
	    &HoA_push($self->size_HoA , $size, $hash);

	    # If object is file also insert into MD5 HoA if has a MD5
	    if ($obj->isfile && defined $obj->md5) {
	    	my $md5 = $obj->md5;
	    	&HoA_push($self->md5_HoA , $md5, $hash);
	    }

	}
    }
    return;
}

# Uses inodes - fix to use objects
sub remove {
   my $self   = shift( @_);
   my @hashs = @_;
   my @deleted;

   foreach my $hash (@hashs){
       if (!defined ${$self->nodes}{$hash}){
	   carp "Trying to delete hash not in Tree $hash";
	   next;
       }
       my $obj = ${$self->nodes}{$hash};
       my $deleted = delete ${$self->nodes}{$hash};
       push(@deleted, $deleted);

       # Delete from size_HoA
       &HoA_remove($self->size_HoA , $obj->size, $hash);       

       # If file & has MD5 - remove from MD5_HoA
       if ($obj->can('md5') && defined $obj->md5){
       	   &HoA_remove($self->md5_HoA , $obj->md5, $hash);
       }
       
   }
   
   return(@deleted);
}

sub count {
   my $self   = shift( @_);
   my $count  = keys %{$self->nodes};
   
   return($count);
}

sub List {
    my $self = shift(@_);
    my @Nodes;

    my @keys = sort keys %{$self->nodes};
    foreach my $key (@keys){
	push(@Nodes, ${$self->nodes}{$key});
    }

    return(@Nodes);
}

#
# Save & restore functions for Tree
# Need to solve the problems with nesting too deep
# * Consider deleting HoA before save, rebuild after load
#

sub save {
    my $self = shift(@_);
    my %opt = @_;

    my $filepath  =  delete $opt{filepath} or croak("Missing 'filepath' param");
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    
    store($self, "$filepath.tmp");
    rename($filepath, "$filepath.old")if -e $filepath;
    rename("$filepath.tmp", $filepath);
}




#
# HoA utility subs
#

sub HoA_push {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my $value = shift(@_);

    if ( !defined( $$HoA_ref{$hash}) || !grep( {$_ eq $value} @{ $$HoA_ref{$hash} }) ){
	push( @{ $$HoA_ref{$hash} }, $value);
    }

    return( scalar( @{ $$HoA_ref{$hash} }));
}


#
# HoA utility functions
#

sub HoA_list {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my @list;

    @list = @{ $$HoA_ref{$hash} } if (defined$$HoA_ref{$hash});

    return( @list );
}

sub HoA_remove {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my $value = shift(@_);
    my @list;

    if (defined $$HoA_ref{$hash} ){
	@list = @{ $$HoA_ref{$hash} };
	@list = grep( $_ ne $value, @list);
	@{ $$HoA_ref{$hash} } = @list;

	delete $$HoA_ref{$hash} if (scalar( @{ $$HoA_ref{$hash} }) == 0);

    } else {
	carp "Tried to remove non-existent value hash: $hash value: $value";
    }

    return;
}



__PACKAGE__->meta->make_immutable;
1;
