#!/usr/bin/env perl

#
# Test Scan dir
#
use Modern::Perl 2016; 		# Implies strict, warnings
use autodie;			        # Easier write open  /close code
use Data::Dumper;           # Debug print

# use Storable qw(nstore_fd);
# use Fcntl qw(:DEFAULT :flock);


# My Modules
use lib '.';
use MooNode;
use MooDir;
use MooFile;
use NodeCollection;

my $collection = NodeCollection->new;



my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $test_dir;
$test_dir = "$ebook_base_dir/_Zeppelins_testing";
# $test_dir = $ebook_base_dir;

#
# Create list of files & insert in collection
#
my $dir = MooDir->new(filepath => $test_dir);

foreach my $filepath ($dir->list_files){
    my $opt_update_md5 = -r $filepath;                              # Don't calc md5 on unreadable files 
    $opt_update_md5 = 0;
    my $node = MooFile->new(filepath => $filepath, opt_update_md5 => $opt_update_md5);

    # Check dupe inode in collection
    my $inode = $node->inode;
    my $dupes = $collection->search_inode($inode);
    if ($dupes > 0){
	warn "Tried to insert dupe inode: $inode filename: ".$node->filename;
    } else {
	$collection->insert($node);
    }
}

foreach my $filepath ($dir->list_files){
    my $opt_update_md5 = -r $filepath;                              # Don't calc md5 on unreadable files 
    $opt_update_md5 = 0;
    my $node = MooFile->new(filepath => $filepath, opt_update_md5 => $opt_update_md5);

    # Check dupe inode in collection
    my $inode = $node->inode;
    my $dupes = $collection->search_inode($inode);
    if ($dupes > 0){
	warn "Tried to insert dupe inode: $inode filename: ".$node->filename;
    } else {
	$collection->insert($node);
    }
}

#
# List Files
#
my @objs = @{ $collection->nodes};
foreach (@objs){
    my $dir = $_->isdir ? "Dir" : "No ";
    say $_->size, " - $dir - ", $_->filename;
}

#
# List Hashes
#

my %hash;

say "\nList size hash";
%hash = %{$collection->size_hash};
foreach my $key (sort { $a <=> $b } keys %hash){
    say "key: $key";
    foreach ( @{ $hash{$key} } ){
	say "\t", $_->filename;
    }
}
say "\n\n";


# say "List inode hash";
# my %hash = %{$collection->inode_hash};
# foreach my $key (sort { $a <=> $b } keys %hash){
#     say "key: $key";
#     foreach ( @{ %hash{$key} } ){
# 	say "\t", $_->filename;
#     }
# }

# say "\nList md5 hash";
# my %hash = %{$collection->md5_hash};
# foreach my $key (sort keys %hash){
#     say "key: $key";
#     foreach ( @{ %hash{$key} } ){
# 	say "\t", $_->filename;
#     }
# }
# say "\n\n";


my $obj = $collection->pop;

say "Pop ", $obj->filename, " from collection, size=", $obj->size;

say "\nList size hash";
%hash = %{$collection->size_hash};
foreach my $key (sort { $a <=> $b } keys %hash){
    say "key: $key";
    foreach ( @{ $hash{$key} } ){
	say "\t", $_->filename;
    }
}
say "\n\n";

say "Search for Airship";

@objs = $collection->search_filepath("Airship");
@objs = $collection->search_filepath("Navy");
@objs = $collection->search_filepath("bob");
foreach (@objs){
    my $dir = $_->isdir ? "Dir" : "No ";
    say $_->size, " - $dir - ", $_->filename;
}


#
# Test Store Data
#
my $db_filepath = $test_dir."/.Collection.db";
$collection->save($db_filepath);

