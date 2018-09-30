#!/usr/bin/env perl

#
# Scan a directory and search for dupe files. Take list of file names - either relative or full  - dirs to scan. Valid argum is a dir & readable.
#
# prevent dupe if scan dr & sub dir - file:find will prevent symbolic links from being searched twice but not normal dirs if in list twice
#
# ugly
# * consider rewrite using find to scan every file
# * cleanup the record size, find dupe md5 code
# * prevent file being checked twice  -prevent dupe file insert
#
use Modern::Perl 2016; 		    # Implies strict, warnings
use autodie;			           # Easier write open  /close code
use experimental 'signatures';

use lib '.';
use MooDir;
use MooFile;

my @file_list;


#
# Scan tree
# * use find::file and call scan dir for each dir found
#
sub scan_tree(@dirpath){
    use File::Find;
    #my $calc_md5 = 0;

    sub find_sub {
	return if /^\../;
	return if !-r;
	return if !-d;
	print " Scan Dir: $_\n";

	my @files_add  = scan_dir($File::Find::name, 0);
	push(@file_list, @files_add);

	# $File::Find::prune = 1;
    }

    my $opt_ref = {
	wanted => \&find_sub,
	no_chdir => 1,
    };

    find($opt_ref, @dirpath);

    return @file_list;
}

#
# sub scan_dir - scan a full dir path and return list file objects
#
sub scan_dir($dirpath, $calc_md5){
    my @files;
    
    die "Dir Does not exisit or is not readable: $dirpath" if (! -r -d $dirpath);

    #
    # Build Dir Object & generat a list of files to check.
    #
    my $dir_obj = MooDir->new(filepath => $dirpath);
    my @file_names = $dir_obj -> list_files;

    #
    # Iterate throug files, create objects for each file. 
    # Check if reable - If unreable  - do not calc md5
    #
    my @file_objs;
    foreach(@file_names){
	my $file_readable = $calc_md5 // -r $_;             # Use // - if first arg defeined - uses it  -otherwise 2nd 
	my $file_obj = MooFile->new(filepath => $_, opt_update_md5 => $file_readable);
	push(@file_objs, $file_obj);
    }

    return(@file_objs);
}

#
# Main - Validate args dir list. Then create list of objects from each dir. After all inseterted into list - check
#

# test dirs
my $ebook_base_dir = "/Users/tshott/Downloads/_ebook";
my $filepath;
$filepath = "$ebook_base_dir/_Zeppelins_testing";

my @filepaths;

# @filepaths = @ARGV;
#@filepaths = ($filepath);
#@filepaths = ($filepath, $ebook_base_dir);
#@filepaths = ($ebook_base_dir);
@filepaths = qw(/Users/tshott/Downloads);

#
# Validate Args  -is dir & is readable  -check before scan any dirs
#
foreach (@filepaths){
    die "Dir does not exist: $_" if ! ! !-e;
    die "Dir does not readable: $_" if ! ! !-r;
    die "Dir does not dir: $_" if ! ! !-d;
}


#
# Foreach arg - generate file objects
#
my @file_objs;
my %size_hash;

#
# Create object and count how many each size created
#
# foreach my $dir (@filepaths){
#     # say "Scanning tree $dir";
#     foreach my $file (scan_tree($dir)){
# 	push(@file_objs, $file);
# 	$size_hash{$file->size}++;
#     }

# }

#foreach my $dir (@filepaths){
# say "Scanning tree $dir";
foreach my $file (scan_tree(@filepaths)){
    push(@file_objs, $file);
    $size_hash{$file->size}++;
}


#
# Check for dupes
# 1. Find files with same size
# 2. check if same md5
#
while( my ($key, $value) = each(%size_hash)) {
    if ($value > 1) {
	my @dupe_files;
	my %md5_hash;

	@dupe_files = grep($_->size == $key, @file_objs);
	
	foreach (@dupe_files){
	    my $md5;
	    if (! $_->isreadable){
		say "Can't check unreadable file md5 - maybe dupe: ", $_->filename;
	    } else {
		$md5 = $_->md5 // $_->update_md5;
		$md5_hash{$md5}++;
	    }
	}	

	while( my ($key, $value) = each(%md5_hash)) {
	    if ($value > 1) {
		say "Dupe md5: $key";
		my @dupe_files = grep(defined $_->md5 && $_->md5 eq $key, @file_objs);
		foreach (@dupe_files){
		    say "\t", $_->filename;
		    say "\t\t", $_->path;
		}
		say "\n";
	    }
	}
    }
}



# debug print

# say " dubug";
#$file_objs[0]->dump_raw;

# foreach (@file_objs){
#     say $_->filename;
# }
