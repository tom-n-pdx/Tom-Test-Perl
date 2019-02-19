#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * Add search
# !! Make remove work on Objects
# * add a insert tree for inserting into tree
# * add make sure insert, delete work both for single or list
# * find way to pass no md5 or no dtime to insert
# * look for dupes in size, md5
# * itterator method to cycle over whole tree
# * Need update if re-calc MD5 for file gets added, fixup HoA's
# * write pack / unpack save & restore
# * add index by filename
# * Move HoA to seperate utility file
# * add search methods. by size, md5, name, mtime, 
# * lock save / rstore file?
# * add a dump method for debug
# * add a pop / shift method.


# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


package NodeTree;
use Moose;
use namespace::autoclean;
use Carp;


use Data::Dumper qw(Dumper);           # Debug print

# Default save file name
our $db_name        =  ".moo.db";
our $db_name_packed =  ".moo.pdb";
use constant MD5_BAD => "x" x 32;

#
# Has optional Dir name
#
has 'name',
    is  => 'rw',
    isa => 'Str';

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
	    # if ($obj->isfile && defined $obj->md5) {
	    #	my $md5 = $obj->md5;
	    #	&HoA_push($self->md5_HoA , $md5, $hash);
	    # }

	}
    }
    return;
}

# Uses inodes - fix to use objects
sub Delete {
   my $self   = shift( @_);
   my @hashs = @_;
   my @Deleted;

   foreach my $hash (@hashs){
       my $hash_value = $hash->isa('MooNode') ?  $hash = $hash->hash : $hash;
       my $obj = delete ${$self->nodes}{$hash_value};

       if (! defined $obj){
	   carp "Trying to delete value not in Tree Hash: $hash Value: $hash-value"  if ($main::verbose >= 2);
	   next;
       }
       push(@Deleted, $obj);

       # Delete from size_HoA
       &HoA_remove($self->size_HoA , $obj->size, $hash) if defined $obj->size;       

       # If obj has MD5 value - remove from MD5_HoA
       # if ($obj->can('md5') && defined $obj->md5){
       #	   &HoA_remove($self->md5_HoA , $obj->md5, $hash);
       # }
       
   }
   
   return(@Deleted);
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
# Generic seach - implement default which is by hash
# * By hash - pass a hash value in
#
sub Search {
    my $self   = shift(@_);
    my %opt = @_;

    my $search_hash = delete $opt{hash}    // 0;
    my $search_dir  = delete $opt{dir}     // 0;
    my $search_file = delete $opt{file}    // 0;
    my $search_path = delete $opt{path}    // 0;
    my $verbose     = delete $opt{verbose} // $main::verbose;
    croak "Unknown params:", join ", ", keys %opt if %opt;

    if ( ! $search_hash && ! $search_dir && ! $search_file && ! $search_path){
	croak ("Illegal set of search options: By_Hash: $search_hash Dir: $search_dir File: $search_file Path: $search_path");
    }

    my @Nodes;

    # Search By Hash
    if ( $search_hash->isa('MooNode') ){
	$search_hash = $search_hash->hash;
    }
    say ("DEBUG: Searching by hash value = ", $search_hash) if ($verbose >= 3 && $search_hash);
    
    # Search By Dir
    say ("DEBUG: Searching by dir value = ", $search_dir) if ($verbose >= 3 && $search_dir);
    
    # Search By File
    say ("DEBUG: Searching by file value = ", $search_file) if ($verbose >= 3 && $search_file);
    
    # Search By Path
    say ("DEBUG: Searching by path value = ", $search_path) if ($verbose >= 3 && $search_path);

    my @keys = sort keys %{$self->nodes};
    foreach my $key (@keys){
	my $Node =  ${$self->nodes}{$key};
	next if ($search_hash && $Node->hash ne $search_hash);
	next if ($search_path && $Node->path ne $search_path);

	# Bug
	next if ($search_dir  && ! $Node->isdir);
	next if ($search_file && ! $Node->isfile);
	
	push(@Nodes, $Node);
    }

    say ("DEBUG: Searching matched ", scalar(@Nodes), " keys") if ($verbose >= 3);

    return(@Nodes);
}


#
# Need a check and summary function to detect errors
#
sub summerize {
    my $self   = shift(@_);


    # first - just count how many items in hash
    my $count = $self->count;
    my @List = $self->List;
    say "DEBUG Summerize: $count records and List has ", scalar(@List), " records";

    foreach my $hash (sort keys %{$self->nodes}){
	my $obj = ${$self->nodes}{$hash};

	if ($obj->hash ne $hash){
	    say "Node hash not equal to stored in %nodes ", $obj->hash, " != ", $hash;
	}
	# Check if in size
	

    }

}

#
# Save & restore functions for Tree
# Need to solve the problems with nesting too deep
# * Consider deleting HoA before save, rebuild after load
# * Consider using text based save

use Storable;
#
# Save Obj to file. Use Perl Storable format 
# Do not use rotate file since it will change mtime for the dir.
#
sub save {
    my $self = shift(@_);
 
    my %opt = @_;   
    # my $dir   =  delete $opt{dir} or croak("Missing 'dir' param nor does Tree have name");
    my $dir     =  delete $opt{dir} // $self->name or croak("Missing 'dir' param nor does Tree have name");
    my $name    =  delete $opt{name} // $db_name;
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    

    my $filepath = $dir.'/'.$name;
    say("Debug: Store Tree Name: ", $filepath) if ($main::verbose >= 3);

    store($self, $filepath);

    my $count = $self->count;
    say "Saved $count records" if ($main::verbose >= 2);

}

#
# Save method using packed fixed record data
# * Must add flags
# * Consider moving create the str to the individual object methods
#

# every size one larger then needed so leave human readable spalce
# 4    data type 4 chars
# 2    extended  1 chars
# 33   MD5 32 chars
# 143  13 x Long Unsigned Ints 10 characters - stats
# ===
# 183
# 
# 329  Filename - 329
# ===
# 512
# Filename - up to 256 - using 200
my $dbtree_template1 = "A4 A2 A33 (A11)13 A441";         # length 512

#
# Do not rotate files - but for debug  -rotate
# If we saved on a per dir bases as we loaded dir files, then we'd generate less cwd records for tree
sub save_packed {
    my $self = shift(@_);
 
    my %opt = @_;   
    my $dir     =  delete $opt{dir}  // $self->name or croak("Missing 'dir' param nor does Tree have name");
    my $name    =  delete $opt{name} // $db_name_packed;
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    
    my $filepath = $dir.'/'.$name;
    say("Debug: Store Packed Tree Name: ", $filepath) if ($main::verbose >= 3);

    rename($filepath, "$filepath.old") if (-e $filepath);
    open(my $fh, ">", $filepath);
    print $fh "# moo.tree.pdb version 1.2\n";

    my $str;
    my @Nodes = $self->List;
    my $old_path = "";

    # Need to sort @Nodes by Dir to minimize the number of cwd records wrote. Will work fine without
    # Need better sort - this one is wrong
    # @Nodes = sort({$a->path cmp $b->path} @Nodes);


    foreach my $Node (@Nodes) {
	# If this record is different path from the current path - need to write an extra cwd dir to change
	# assumed dir. Unless this IS a dir record. Means we'll print two lines on this itteration of loop.
	# If we are lucky and Nodes ordered in right order - we will never issue a cwd record
	#
	if (! $Node->isa('MooDir') && $Node->path ne $old_path){
	    $str = _packed_cwd_str($Node);
	    print $fh "$str\n";
	    $old_path = $Node->path;
	}


	if ($Node->isa('MooDir')){
	    $str = _packed_dir_str($Node);
	    $old_path = $Node->filepath;
	} else {
	    $str = _packed_file_str($Node);
	}

    	print $fh "$str\n";
    }

    close($fh);
    return;
}

sub _packed_file_str {
    my $Node = shift(@_);
    
    my $type    = "File";
    my $extend  = " ";
    my $md5     = $Node->md5 // MD5_BAD;
    my @stats   = @{$Node->stat};
    my $name    = $Node->filename;
    warn("Name > space 329 $name") if (length($name) > 329);

    my $str = pack($dbtree_template1, $type, $extend, $md5, @stats, $name);

    return($str);
}

sub _packed_cwd_str {
    my $Node = shift(@_);
    
    my $type    = "Cwd";
    my $extend  = " ";
    my $md5     = MD5_BAD;
    my @stats   = @{$Node->stat};
    my $name    = $Node->path;
    warn("Name > space 329 $name") if (length($name) > 329);

    my $str = pack($dbtree_template1, $type, $extend, $md5, @stats, $name);

    return($str);
}
sub _packed_dir_str {
    my $Node = shift(@_);
    
    my $type    = "Dir";
    my $extend  = " ";
    my $md5     = MD5_BAD;
    my @stats   = @{$Node->stat};
    my $name    = $Node->filepath.'/';
    warn("Name > space 329 $name") if (length($name) > 329);

    my $str = pack($dbtree_template1, $type, $extend, $md5, @stats, $name);

    return($str);
}



#
# ToDo
# * If named when enter method  -should have same name after load?
#
sub load {
    my $self = shift(@_);

    my %opt = @_;
    my $dir     =  delete $opt{dir} // $self->name or croak("Missing 'dir' param nor does Tree have name");
    my $name    =  delete $opt{name} // $db_name;
    die "Unknown params:", join ", ", keys %opt if %opt;

    # my $dbfile_mtime = 0;
    my $filepath = $dir.'/'.$name;

    if (-e $filepath) {
	# Need to use eval becuase read errors are fatal
	eval { $self = retrieve($filepath)} ;

	# If error not because of bad file, die
	# perl storable
	if ($@ && $@ !~ /Magic number checking/){
	    die "Error on load Tree retrieve failed. $@ File: $filepath";
	}

	if ($@ or !blessed($self)){
	    carp "Bad db_file File: $filepath";
	    rename($filepath, "$filepath.old");
	    
	    $self = NodeTree->new();
	    return($self);
	}

	my $count = $self->count;
	say "\tLoaded $count records" if ($main::verbose >= 2);

	# $dbfile_mtime = (stat(_))[9];
    } else {
	$self = NodeTree->new();
    }

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
	carp "HOA_remove Tried to remove non-existent value hash: $hash value: $value";
    }

    return;
}



__PACKAGE__->meta->make_immutable;
1;
