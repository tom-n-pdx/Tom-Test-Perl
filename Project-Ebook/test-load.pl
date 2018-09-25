#!/usr/bin/env perl


#
#ToDo
# * fix - new list needs to not include read only or dirs
#

#
# Test Scan dir
#
use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /clogoto-lise code

#
# ToDo - expand ~ in dir path
#

use Number::Bytes::Human qw(format_bytes);
use List::Util qw[min];	# Import min()
use Data::Dumper;           # Debug print

use Storable qw(fd_retrieve);
use Fcntl qw(:DEFAULT :flock);

# My Modules
use lib '.';
use Ebook_Files ;

#
# Main
#

my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins";
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_ships";
#my $test1_dir = "/Users/tshott/Downloads/_ebook";
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_bob";               # Fail
#my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology_test.gif";               # Fail
# my $test1_dir = "/Users/tshott/Downloads/_ebook/_Zeppelins/Airship technology.gif";               # Fail

#
# Create list of files in dir
#
opendir(my $dh, $test1_dir);
my @newfiles = readdir $dh;
closedir $dh;

@newfiles = grep($_ !~ /^\./, @newfiles);		    # remove . files from last
@newfiles = map($test1_dir.'/'.$_, @newfiles);	    # make into absoule path         
#print "Start New Filepath: ", join("\n", @newfiles), "\n";
print "New Fileslist Length: ", $#newfiles,"\n";


# Load objs via storable into file in dir
my @files;
my $obj_store_file = $test1_dir."/.ebook_files.dbj";
#my @files = @{ retrieve($obj_store_file) };

open(my $fh, "<", $obj_store_file)      or die "can't open $obj_store_file: $!";
flock($fh, LOCK_SH)                          or die "can't lock $obj_store_file: $!";
#my $files_ref = retrieve(*DF);
@files = @{ fd_retrieve($fh) };
close($fh);


#
# Test Print Info 
#
my $end = min(9, scalar(@files));

print "\n\nDebug Print - Loaded Objects\n";
foreach (@files[0..$end]){

    my($basename, $path, $ext) = $_->fileparse();

    # print "$basename ", $_->size, "\n";
    my $size = format_bytes($_->size);
    # print "$size\t$basename\n";
    printf "%5s %s\n", $size, $basename;
}

#print "Data Dump #4\n";
#print Dumper($files[4]);

#
# compare to files in dir?
#

#
# Run through list - make sure none changed
#





foreach (@files){

    my $filepath = $_->filepath();
    my($basename, $path, $ext) = $_->fileparse();

    # print "Check:  $basename$ext\n";
    if (!-e $filepath){
	print "$basename$ext\n\tFile missing from dir\n";
	next;
    }
    
    #
    # Create lightweight file object and compare
    # 
    # I'm assumng it's unlikely MD5 will change withoutsomething else changing
    #
    my $obj = Ebook_Files->new("filepath"=>$filepath, "calc-md5"=> 0);
    my @differences = $_->is_equal($_, $obj);
    if ($#differences > 0) {
	print "$basename$ext\n\tDifffereences: ", join(", ", @differences), "\n";

	# Now need to check md5 - need calc for new obj
	$obj->update_md5;
	@differences = $_->is_equal($_, $obj);
	print "\tMD5  ", join(", ", @differences), "\n";
    }

    # Delete from new list of files

    @newfiles = grep($_ ne $filepath, @newfiles);

   # print "New Fileslist Length: ", $#newfiles,"\n";


}

print "New files not in loaded list: ", join(", ", @newfiles), "\n";
