#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * Fix bug with non-existent hash being removed - maybe only after file is restored?
# * Make remove work on Objects
# * add make sure insert, delete work both for single or list
# * find way to pass no md5 or no dtime to create
# * save / restore
# * look for dupes in size, md5
# * usng inode instead of ref in HoA's until solve rcusion depth problem
# * itterator method to cycle over whole tree
# * Need update if re-calc MD5 for file gets added, fixup HoA's

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
	    # &HoA_push($self->size_HoA , $size, $obj);

	    # If object is file also insert into MD5 HoA if has a MD5
	    if ($obj->isfile && defined $obj->md5) {
	    	my $md5 = $obj->md5;
	    	&HoA_push($self->md5_HoA , $md5, $hash);
	    	# &HoA_push($self->md5_HoA , $md5, $obj);
	    }

	}
    }
    return;
}

# Uses inodes - fix to use objects
sub remove {
   my $self   = shift( @_);
   my @hashs = @_;
   my $deleted;

   foreach my $hash (@hashs){
       #my $type = blessed($hash) // "Not Blessd";
       #say "Type: $type";
      #if (! $obj->isa('MooNode')){
	#   $obj = ${$self->nodes}{$obj};
       #}

       # Add error messge if try and delete non-existent
       if (!defined ${$self->nodes}{$hash}){
	   say "Trying to delete non-existent hash from Tree";
	   next;
       }
       my $obj = ${$self->nodes}{$hash};

       $deleted = delete ${$self->nodes}{$hash};

       # Delete from size_HoA
       my $size = $obj->size;
       &HoA_remove($self->size_HoA , $size, $hash);       
       # &HoA_remove($self->size_HoA , $size, $obj);


       # If file & has MD5 - remove from MD5_HoA
       # if ($obj->isfile){
       # 	   my $md5 = $obj->md5;
       # 	   &HoA_remove($self->md5_HoA , $md5, $hash) if defined $md5;
       # 	   # &HoA_remove($self->md5_HoA , $md5, $obj) if defined $md5;
       # }
       
   }
   
   return($deleted);
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

# sub pop {
#    my $self   = shift( @_);
#
#    my $hash = (sort keys %{$self->nodes})[0] // 0;
#    my $obj = $self->remove($hash);
#
#    return($obj);
# }

#
# HoA utility subs
#

sub HoA_push {
    my $HoA_ref  = shift(@_);
    my $hash = shift(@_);
    my $value = shift(@_);

    if (  !defined( $$HoA_ref{$hash}) || !grep( {$_ eq $value} @{ $$HoA_ref{$hash} }) ){
	push( @{ $$HoA_ref{$hash} }, $value);
    }

    return( scalar( @{ $$HoA_ref{$hash} }));
}

# sub HoA_pop {
#     my $HoA_ref  = shift(@_);
#     my $hash = shift(@_);
#     my $value;
#     # my $value = shift(@_);

#     if (  !defined( $$HoA_ref{$hash}) ) {
# 	$value = pop( @{ $$HoA_ref{$hash} });
#     }

#     return($value);
# }

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
