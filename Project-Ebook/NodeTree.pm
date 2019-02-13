#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * Make remove work on Objects
# * add make sure insert, delete work both for single or list
# * find way to pass no md5 or no dtime to insert
# * look for dupes in size, md5
# * itterator method to cycle over whole tree
# * Need update if re-calc MD5 for file gets added, fixup HoA's
# * add "name" filepath for tree  -so know wheer save by default?
# * write pack / unpack save & restore
# * index by filename
# * Move HoA to seperate utility file
# * add search methods. by size, md5, name, mtime, 
# * lock save / rstore file?


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


package NodeTree;
use Moose;
use namespace::autoclean;
use Carp;


use Data::Dumper qw(Dumper);           # Debug print

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

use Storable;
#
# Save Obj to file. Use Perl Storable format 
# Do not use rotate file since it will change mtime for the dir.
#
sub save {
    my $self = shift(@_);
 
    my %opt = @_;   
    my $dir   =  delete $opt{dir} or croak("Missing 'dir' param");
    my $name  =  delete $opt{name} // ".moo.db";
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    
    my $filepath = $dir.'/'.$name;

    # save into temp and then rotate files
    store($self, $filepath);
    # rename($filepath, "$filepath.old")if -e $filepath;
    # rename("$filepath.tmp", $filepath);

    my $count = $self->count;
    say "Saved $count records" if ($main::verbose >= 2);

}

#
#
#
sub load {
    my $self = shift(@_);

    my %opt = @_;
    my $dir     =  delete $opt{dir} or croak "Missing param 'dir' ";
    # my $name    =  ".moo.db";
    my $name  =  delete $opt{name} // ".moo.db";
    die "Unknown params:", join ", ", keys %opt if %opt;

    my $dbfile_mtime = 0;
    my $filepath = $dir.'/'.$name;

    if (-e $filepath) {

	# Need to test for exceptions if have old incompatable file
	eval { $self = retrieve($filepath)} ;

	if (blessed($self)){ 
	    my $count = $self->count;
	    # say "\tLoaded $count records" if ($verbose >= 2);
	    say "\tLoaded $count records" if ($main::verbose >= 2);
	} else {
	    # clear data if not load blessed object, rename file since no good
	    carp "File Not Blessed $filepath";
	    rename($filepath, "$filepath.old");
	    $self = NodeTree->new();
	}
	$dbfile_mtime = (stat(_))[9];
    } else {
	$self = NodeTree->new();
    }

    # say Dumper($self);
    # return ($self, $dbfile_mtime);
    return ($self);
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
