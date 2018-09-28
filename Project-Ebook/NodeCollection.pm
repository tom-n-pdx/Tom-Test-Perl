#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * need way to update item after md5 added
# * add pop, push?, shit, unshift?
# * finish pop 
# search by md5, size, filename, filepath, 


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


use File::Basename;         # Manipulate file paths
use Time::localtime;        # Printing stat values in human readable time

package NodeCollection;
use Moose;
use namespace::autoclean;
use Data::Dumper qw(Dumper);           # Debug print

has 'files',
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [ ] };
    
has 'size_hash',
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


# Move hookinto size & md5 hash into a function

# hash by filename

sub insert_hash {
    my ($hash_ref, $value, $obj) = splice(@_, 0, 3);
    push( @{$$hash_ref{$value}}, $obj );
};


sub push {
    my $self = shift( @_);
    my $obj = shift(@_);
    
    die "not a node object" if ! $obj->isa('MooNode');
    
    # add Obj to list
    push( @{$self->files}, $obj );
    
    # Insert into size hash
    my $size = $obj->size;
    if ($size){
	insert_hash($self->size_hash, $size, $obj); 
    }

    # Insert into md5 hash
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
    foreach (@array){
	say "before: ", $_->filename;
    }
    print "Before: Size $value ", join(', ', @array), "\n";
    @array = grep {$_->filepath ne $obj->filepath} @array;
    foreach (@array){
	say "after: ", $_->filename;
    }

    @{$$hash_ref{$value}} = @array;
    print "After: Size $value ", join(', ', @{$$hash_ref{$value}}), "\n";
};

#
# Pop item from list
#

sub pop {
    my $self = shift( @_);
    
    # pop file Obj off list
    my $obj = pop( @{$self->files});
    
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


__PACKAGE__->meta->make_immutable;
1;
