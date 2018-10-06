#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * need way to update item after md5 added
# * need a remove by $obj
# search by md5, size, filename, filepath, 
# * check for dupe filename? inode? on insert?
# * use dev-inode
#

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

use File::Basename;         # Manipulate file paths
use Time::localtime;        # Printing stat values in human readable time

package NodeCollection;
use Moose;
use namespace::autoclean;
use Data::Dumper qw(Dumper);           # Debug print
use Storable qw(nstore_fd nstore retrieve);
use Fcntl qw(:DEFAULT :flock);


# A list of the files in collection
has 'nodes',
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [ ] };
    
# A hash of the size of the nodes in the collection - hash of arrays of refs to node objs
has 'size_hash',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    
# actually dev-inode hash to be unique across systems
has 'inode_hash',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    
has 'md5_hash',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    

# sub BUILD {
#     my ($self)=shift( @_);
#     my $args_ref = shift(@_);

#     # my @files;
#     # $self->files(\@files);

#     # my %size;
#     # $self->size_hash(\%size);

#     #my %md5_hash;
#     # $self->md5_hash(\%md5_hash);

#     return
# }


#
# internal datastructure utilites
#

sub length_hash_array {
    my ($hash_ref, $value, $obj) = @_;

    my @array = @{$hash_ref->{$value}};
    my $length = @array // -1;

    say "size: $value length: $length";

    return($length);
}

sub insert_hash {
    my ($hash_ref, $value, $obj) = splice(@_, 0, 3);
    push( @{$$hash_ref{$value}}, $obj );
};

#
# Push file obj onto list of objects
# * also hook into hash'es
#
sub insert {
    my $self = shift( @_);
    my $obj = shift(@_);
    
    die "not a node object" if ! $obj->isa('MooNode');
    
    # add Obj to list
    push( @{ $self->nodes }, $obj );
    
    # Insert into size hash
    my $size = $obj->size;
    insert_hash($self->size_hash, $size, $obj); 

    # Should never have dup inode
    # my $inode =  ${$obj->stat}[0]."-".${$obj->stat}[1];
    my $inode =  ${$obj->stat}[1];
    insert_hash($self->inode_hash, $inode, $obj); 

    # Insert into md5 hash - if obj has md5 method & value is set
    if ($obj->can('md5') && $obj->md5){
    	my $md5 = $obj->md5;
    	insert_hash($self->md5_hash, $md5, $obj); 
    }

    return;
}

sub remove_hash {
    my ($hash_ref, $value, $obj) = splice(@_, 0, 3);

    # push( @{$$hash_ref{$value}}, $obj );
    my @array = @{$$hash_ref{$value}};

    # foreach (@array){
    # 	say "before: ", $_->filename;
    # }
    # print "Before: Size $value ", join(', ', @array), "\n";
    @array = grep {$_->filepath ne $obj->filepath} @array;

    #
    # If array is empty - remove key
    #
    my $length = $#array + 1;
    # say "Length after pop: $length";
    if ($length < 1){
	delete $$hash_ref{$value};
    } else {
	@{$$hash_ref{$value}} = @array;
    }

    # foreach (@array){
    # 	say "after: ", $_->filename;
    # }

    # print "After: Size $value ", join(', ', @{$$hash_ref{$value}}), "\n";
};

#
# Pop item from list
#

sub pop {
    my $self = shift( @_);
    
    # pop file Obj off list
    my $obj = pop( @{$self->nodes} );
    
    return($obj) if !defined($obj);

    my $size = $obj->size;
    if ($size){
	remove_hash($self->size_hash, $size, $obj); 
    }

    # my $md5 = $obj->md5;
    # if ($md5){
    # 	remove_hash($self->md5_hash, $md5, $obj); 
    # }
    
    return($obj);
}

#
# Return a list of filesnames match regexp
#
sub search_filepath {
    my $self = shift(@_);
    my $regexp = shift(@_);
    my @nodes;

    @nodes = grep($_->filepath =~$regexp, @{$self->nodes});

    return(@nodes);
}


#
# Return a list of nodes size match
#
sub search_size {
    my $self = shift(@_);
    my $size = shift(@_);
    my @nodes;

    @nodes = grep($_->size == $size, @{$self->nodes});

    return(@nodes);
}


#
# Return a list of nodes size match
#
sub search_inode {
    my $self = shift(@_);
    my $inode = shift(@_);
    my @nodes;

    @nodes = grep($_->inode eq $inode, @{$self->nodes});

    return(@nodes);
}





sub dup_size {
    my $self = shift( @_);
    my %hash = %{$self->size_hash};

    foreach my $size  (sort keys %hash){
	my @values = @{ $hash{$size} };

	if ($#values > 0){
	    say "Dupe files size: $size";
	    foreach (@values) {
        	say "\t", $_->filename;
            }
	    print "\n";
	}
    }
}



sub dup_md5 {
    my $self = shift( @_);
    my %hash = %{$self->md5_hash};

    foreach my $md5  (sort keys %hash){
	my @values = @{ $hash{$md5} };

	if ($#values > 0){
	    say "Dupe files md5: $md5";
	    foreach (@values) {
        	say "\t", $_->filename;
            }
	    print "\n";
	}
    }
}

#
# Consider rework to use lock_nstore - the locking version
#
sub save {
    my ($self, $filepath) = @_;
    my $obj_store_file = $filepath;
    
    nstore($self, $obj_store_file);
    # sysopen(my $df, $obj_store_file, O_RDWR|O_CREAT, 0666);
    # flock($df, LOCK_EX)                             or die "can't lock $obj_store_file: $!";
    # nstore_fd($self, $df)                            or die "can't store hash\n";
    # truncate($df, tell($df));	# Why?
    # close($df);


}


sub restore {
    my ($self, $filepath) = @_;
    my $obj_store_file = $filepath;

    open(my $fh, "<", $obj_store_file)      or die "can't open $obj_store_file: $!";
    flock($fh, LOCK_SH)                           or die "can't lock $obj_store_file: $!";
    $self = fd_retrieve($fh);
    close($fh);
}





__PACKAGE__->meta->make_immutable;
1;
