#
# A collection of Nodes
#
# Base file subclase for files.
# 
# ToDo
# * Make exist work on objects
# !! Make remove work on Objects
# * itterator method to cycle over whole tree
# * add a pop / shift method.
# * each
# * Insert work on heap too - merge?
# * push / pop
# * exisit work w/o hash
# * Keep state var - keys?
#
# Load/Save
# * lock save / rstore file?
# * Better save format
# * Make load more robust
# * Better sorage for items.
# * add a dump method for debug
# * iterator load
# * make work older objs loaded

# Standard uses's
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code


package NodeHeap;
use Moose;
use MooseX::Storage;
with Storage('format' => 'JSON', 'io' => 'File');
use namespace::autoclean;
use Carp;


use Exporter qw(import);
# our @EXPORT = qw(load_iter);

# use open qw(:std :utf8);

# use Data::Dumper qw(Dumper);           # Debug print

# Default save file name
our $db_name        =  ".moo.yaml";
our $db_name_packed =  ".moo.dbp";
use constant MD5_BAD => "x" x 32;

#
# Has optional name
#
has 'name',
    is  => 'rw',
    isa => 'Str';

# A hash of the objs in collection. Hashed by hash method of object. 
# Will work on any datatype that can generate a hash and has a size
#
has 'nodes',
    is => 'rw',
    isa => 'HashRef',
    default => sub { { } };
    
    
#
# Insert Node Obj(s) into tree
# ToDo
# * Make work with a heap object
#
sub insert {
    my $self = shift( @_);
    my @Objs = @_;
    
    foreach my $Obj (@Objs){
	croak "not a node object" if (! $Obj->isa('MooNode'));

	my $hash = $Obj->hash;
	if (defined ${$self->nodes}{$hash} ){
	    carp "WARN: Inserting dupe node. hash=$hash";
	} else {
	    ${$self->nodes}{$hash} = $Obj;
	}
    }
    return;
}


#
# Merge node object into tree
# If new item does not exisit, just insert.
# If does exist, insert if time newer.
#
sub merge {
    my $self = shift( @_);
    my @Objs = @_;
    my $verbose = $main::verbose;
    my %obj_count = (new => 0, update => 0, old => 0);
    
    foreach my $Obj_new (@Objs){
	croak "not a node object" if (! $Obj_new->isa('MooNode'));

	my $hash = $Obj_new->hash;
	my $Obj_old = $self->Exist(hash => $hash);

	if (! defined $Obj_old){
	    # If not in existing tree, just insert
	    ${$self->nodes}{$hash} = $Obj_new;
	    $obj_count{new}++;

	} else {
	    # If exisist & newer, insert
	    if ($Obj_new->time_max > $Obj_old->time_max){
		${$self->nodes}{$hash} = $Obj_new;
		$obj_count{update}++;
	    } else {
		$obj_count{old}++;
	    }
	}
    }

    
    if ($verbose >= 2 || ( ($obj_count{new} + $obj_count{update}) >= 1 && $verbose >= 1)){
	print "\tMerged Data: ";

	foreach (sort keys %obj_count){
	    print "$_: $obj_count{$_} ";
	}
	print "\n";
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
       my $Obj = delete ${$self->nodes}{$hash_value};

       if (! defined $Obj){
	   carp "Trying to delete value not in Heap Hash: $hash Value: $hash-value"  if ($main::verbose >= 2);
	   next;
       }
       push(@Deleted, $Obj);
       
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

#    my $search_hash = delete $opt{hash}    // 0;
    my $search_dir  = delete $opt{dir}     // 0;
    my $search_file = delete $opt{file}    // 0;
    my $search_path = delete $opt{path}    // 0;
    my $verbose     = delete $opt{verbose} // $main::verbose;
    croak "Unknown params:", join ", ", keys %opt if %opt;

    if ( ! $search_dir && ! $search_file && ! $search_path){
	croak ("Illegal set of search options: Dir: $search_dir File: $search_file Path: $search_path");
    }

    my @Nodes;

    # Search By Hash
    # if ( $search_hash->isa('MooNode') ){
    # 	$search_hash = $search_hash->hash;
    # }
    #say ("DEBUG: Searching by hash value = ", $search_hash) if ($verbose >= 3 && $search_hash);
    
    # Search By Dir
    say ("DEBUG: Searching by dir value = ", $search_dir) if ($verbose >= 3 && $search_dir);
    
    # Search By File
    say ("DEBUG: Searching by file value = ", $search_file) if ($verbose >= 3 && $search_file);
    
    # Search By Path
    say ("DEBUG: Searching by path value = ", $search_path) if ($verbose >= 3 && $search_path);

    my @keys = sort keys %{$self->nodes};
    foreach my $key (@keys){
	my $Node =  ${$self->nodes}{$key};
	# next if ($search_hash && $Node->hash ne $search_hash);
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
# For Search by hash - no need to search - just lookup!
#
sub Exist {
    my $self   = shift(@_);
    my %opt = @_;
    my $Node;

    my $search_hash = delete $opt{hash}    // croak "Required parm 'hash' mising";
    my $verbose     = delete $opt{verbose} // $main::verbose;
    croak "Unknown params:", join ", ", keys %opt if %opt;

    $Node = ${$self->nodes}{$search_hash};
    
    return($Node);
}


#
# Return one Obj
# OK if delete just returned item, otherwise screws up iterator
sub Each {
    my $self   = shift(@_);
    my %opt = @_;

    my $verbose     = delete $opt{verbose} // $main::verbose;
    croak "Unknown params:", join ", ", keys %opt if %opt;

    my ($hash, $Node) = each(  %{$self->nodes}  );
    
    return($Node);
}



#
# Need a check and summary function to detect errors
#
sub summerize {
    my $self   = shift(@_);

    # first - just count how many items in hash
    my $count = $self->count;
    my @List = $self->List;
    say "INFO: Summerize: $count records and List has ", scalar(@List), " records";

    foreach my $hash (sort keys %{$self->nodes}){
	my $obj = ${$self->nodes}{$hash};

	if ($obj->hash ne $hash){
	    say "Node hash not equal to stored in node var ", $obj->hash, " != ", $hash;
	}
	# Check if in size
	

    }

}

#
# Save & restore functions for Tree
# Need to solve the problems with nesting too deep
# * Consider deleting HoA before save, rebuild after load
# * Consider using text based save

use Storable qw(store_fd fd_retrieve);
#
# Save Obj to file. Use Perl Storable format 
# Do not use rotate file since it will change mtime for the dir.
# Do not save whole structure - save each object


sub save {
    my $self = shift(@_);
 
    my %opt = @_;   
    my $dir     =  delete $opt{dir} // $self->name or croak("Missing 'dir' param nor does Heap have name");
    my $name    =  delete $opt{name} // $db_name;
    croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    
    my $filepath = $dir.'/'.$name;

    # Dump Individual Objs all at once
    my @List = $self->List;
    say("DEBUG: Store Heap Records: ", scalar(@List), " Name: ", $filepath) if ($main::verbose >= 3);


    open(my $fh, ">:utf8", $filepath);
    # binmode $fh;

    foreach my $Obj (@List){
	store_fd($Obj, $fh);
    }
    # Hack - bug when readng, need to write end of file mark
    my $sentinel = "EOF"; 
    store_fd(\$sentinel, $fh);
    # print $fh, "\n";

    close($fh);

    my $count = $self->count;
    say "    Saved $count records" if ($main::verbose >= 3);

}

#
#
#
sub load {
    my $self = shift(@_);

    my %opt = @_;
    my $dir     =  delete $opt{dir}  // croak("Missing 'dir' param");
    my $name    =  delete $opt{name} // $db_name;
    die "Unknown params:", join ", ", keys %opt if %opt;


    $self = NodeHeap->new;
    # my $dbfile_mtime = 0;
    my $filepath = "$dir/$name";
    # my $i = 1;


    if (-e $filepath) {
	# say "DEBUG: Open $filepath";

	open(my $fh, "<", $filepath);
	# # binmode $fh;
	while ( my $Node = fd_retrieve($fh)) {
	    last if (ref($Node) eq 'SCALAR');
	    $self->insert($Node);
	}

	my $count = $self->count;
	say "    Loaded $count records" if ($main::verbose >= 3);

	# $dbfile_mtime = (stat(_))[9];
    } else {
	$self = NodeHeap->new();
    }

    return ($self);
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
# 9    Flags 8 bits
# 143  13 x Long Unsigned Ints 10 characters - stats
# ===
# 191
# 
# 321  Filename - 321
# ===
# 512
#
my $dbtree_template1 = "A4 A2 A33 A9 (A11)13 A312";         # length 512


# #
# # Do not rotate files - but for debug  -rotate
# # If we saved on a per dir bases as we loaded dir files, then we'd generate less cwd records for tree

# sub save_packed {
#     my $self = shift(@_);
 
#     my %opt = @_;   
#     my $dir     =  delete $opt{dir}  // $self->name or croak("Missing 'dir' param nor does Heap have name");
#     my $name    =  delete $opt{name} // $db_name_packed;
#     croak("Unknown params:".join( ", ", keys %opt)) if %opt;
    
#     my $filepath = $dir.'/'.$name;
#     say("Debug: Store Packed Heap Name: ", $filepath) if ($main::verbose >= 3);

#     # Do not rotate Files, cause Dir mtime to change
#     #rename($filepath, "$filepath.old") if (-e $filepath);
#     open(my $fh, ">", $filepath);
#     print $fh "# moo.tree.pdb version 1.2\n";

#     my $str;
#     my @Nodes = $self->List;

#     # Need to sort @Nodes by diectory path to minimize the number of cwd records wrote. Will work fine without
#     # Need better sort - this one is wrong


#     # By sorting by full filepath, end up with dir's before files in dir
#     @Nodes = sort({$a->filepath cmp $b->filepath} @Nodes);

#     my $old_path = "";
#     foreach my $Node (@Nodes) {
# 	# If this record  path is different from the current path - need to write an extra cwd record to change
# 	# assumed dir. Unless this IS a dir record. Means we'll print two lines on this itteration of loop.
# 	# If we are lucky and Nodes ordered in right order - we will never issue a cwd record
# 	#

# 	if ($Node->isa('MooDir')){
# 	    $old_path = $Node->filepath;
# 	} else {
# 	    if ($Node->path ne $old_path){
# 		$str = _packed_cwd_str($Node);
# 		print $fh "$str\n";
# 		$old_path = $Node->path;
# 	    }
# 	}

# 	$str = $Node->packed_str;
#     	print $fh "$str\n";
#     }

#     close($fh);
#     return;
# }

# sub _packed_cwd_str {
#     my $Node = shift(@_);
    
#     my $type    = "Cwd";
#     my $extend  = " ";
#     my $md5     = MD5_BAD;
#     my $flags   = $Node->flags;
#     my @stats   = @{$Node->stats};
#     my $name    = $Node->path;
#     warn("Name > space 329 $name") if (length($name) > 329);

#     my $str = pack($dbtree_template1, $type, $extend, $md5, $flags, @stats, $name);

#     return($str);
# }

# sub load_packed {
#     my $self = shift(@_);
 
#     my %opt = @_;   
#     my $dir     =  delete $opt{dir}     // $self->name or croak("Missing 'dir' param nor does Heap have name");
#     my $name    =  delete $opt{name}    // $db_name_packed;
#     my $verbose =  delete $opt{verbose} // $main::verbose;
#     croak("Unknown params:".join( ", ", keys %opt)) if %opt;

#     # Check file exists
#     my $filepath = $dir.'/'.$name;
#     say("Debug: Load Packed Heap Name: ", $filepath) if ($main::verbose >= 3);
#     if (! -e $filepath){
# 	croak("Tried to load non-existent packed db file $filepath");
#     }

#     $self = NodeHeap->new();


#     # Open file, loop read
#     open(my $fh, "<", $filepath);
 
#     $_ = <$fh>;
#     say "Reading lines from packed db file: $_" if ($verbose >= 3);
    

#     my $cwd = "";
#     while (<$fh>){
# 	my ($type, $extend, $md5, $flags, @stats) = unpack($dbtree_template1, $_);
# 	my $name = pop(@stats);

# 	my $Node;
# 	my $null;

# 	# say "$type $extend $md5 $flags ", join(";", @stats), "  - $name";

#       SWITCH: 
#       	for ($type) {
#       	    if (/^File/) { $Node = MooFile->new(filepath => "$cwd/$name", 
#       						stats => \@stats, update_stats => 0, 
#       						flags => $flags,  update_flags => 0,
# 					        update_md5 => 0);

# 			   $Node->md5($md5) if ($md5 ne MD5_BAD);

#      			   last SWITCH; }

#       	    if (/^Node/) { $Node = MooNode->new(filepath  => "$cwd/$name", 
#       						stats => \@stats, update_stats => 0, 
#       						flags => $flags,  update_flags => 0);
#       			   last SWITCH; }

#       	    if (/^Dir/)  { $cwd = $name; 
#       			   $Node = MooDir->new(filepath  => "$cwd",
#       			   		       stats => \@stats, update_stats => 0, 
#       			   		       flags => $flags,  update_flags => 0,
#       			   		       update_dtime => 0);

#       			   last SWITCH; }

#       	    if (/^Cwd/) { $cwd = $name;
#       			  last SWITCH; }	
	    
#        	    croak("Unnown type: $type");
#       	}
# 	$self->insert($Node) if (defined $Node);

#     }

#     # Close file
#     close($fh);

#     # Return data
#     return($self);
# }


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
