#!/usr/bin/env perl -CA
#

#
# Update Dupes and other standard datfiles
#

use Modern::Perl; 		         # Implies strict, warnings
use autodie;
use Number::Bytes::Human qw(format_bytes);
use open ':encoding(UTF-8)';
binmode(STDOUT, ":utf8");
use Encode qw(decode_utf8);

# use Getopt::Long;

use lib '.';
use ScanDirMD5;
use NodeTree;
use NodeHeap;
use FileUtility qw(osx_check_flags_binary osx_flags_binary_string %osx_flags 
		   dir_list 
		   stats_delta_binary %stats_names
	           media_type);

use lib 'MooNode';
use MooDir;
use MooFile;
use MooNode;


#
# Performace
# 
# 23.687u 1.543s 0:25.95 97.1%	0+0k 0+322io 1pf+0w     start, dumb load, dumb insert
# 19.159u 1.398s 0:21.03 97.6%	0+0k 0+693io 0pf+0w     merge both all and ebook
# 20.939u 1.233s 0:22.65 97.8%	0+0k 0+490io 0pf+0w     use each to process nodes


our $verbose = 0;
my $data_dir = "/Users/tshott/Downloads/Lists_Disks/.moo";


# Mime Typs
use MIME::Types;
my $Mime = MIME::Types->new; 


# my %size;

# Store as Heap - but later will load into Tree
# my $Files = NodeHeap->new;
# my $Ebook = NodeHeap->new;

my $Files = NodeTree->new;
my $Ebook = NodeHeap->new;
my $Video = NodeHeap->new;

my @names = dir_list(dir => $data_dir);

my %ebook_ext = (".pdf" => 1, ".chm" => 1, ".epub" => 1, ".mobi" => 1, ".djvu" => 1, ".azw3" => 1);
my %video_ext = (".mkv" => 1, ".mp4" => 1, );
# my %type_def  = (csv  => 'doc',       txt  => 'doc',      docx => 'doc',     pptx => 'doc',    xlsx => 'doc',   log  => 'doc',
#                                       nfo  => 'doc',      xml  => 'doc',     doc  => 'doc',    ppt  => 'doc',   rtf  => 'doc', 
#                                       torrent => 'doc',   xls  => 'doc',     isi  => 'doc',    opf  => 'doc',   dat  => 'doc',
#                                       bib  => 'doc',      gdoc => 'doc',     accdb => 'doc',   pdat => 'doc',   xlsb => 'doc', 
#                                       dea  => 'doc',      
# 		 pdf  => 'ebook',     epub => 'ebook',    chm  => 'ebook',   mht  => 'ebook',  html => 'ebook', azw3 => 'ebook',   
# 		                      mobi => 'ebook',    djvu => 'ebook',   htm  => 'ebook',  azw4 => 'ebook', azw  => 'ebook', 
#                                       djv  => 'ebook',    
# 		 r    => 'code',      rd   => 'code',     c    => 'code',    js   => 'code',   h    => 'code', 
# 		 jpg  => 'image',     png  => 'image',    gif  => 'image',   bmp  => 'image',  jpeg => 'image',  tif => 'image',
#                                       ico  => 'image',    
# 		 mp3  => 'audio',     flac => 'audio',    asf  => 'audio',   m4a  => 'audio',  cbr  => 'audio', 
# 		 srt  => 'subtitle',  cue  => 'subtitle', sub  => 'image',   idx  => 'subtitle', 
# 		 mp4  => 'video',     avi  => 'video',    mkv  => 'video',   wmv  => 'video',  mpg => 'video',  rmvb => 'video', 
# 		                      ogm => 'video',     vob  => 'video',   divx => 'video',  ogg => 'video',  mov  => 'video', 
# 		                      flv  => 'video',    m4v  => 'video',   rm   => 'video',  '3gp' => 'video',  m2ts => 'video', 
# 	         zip  => 'archive',   rar  => 'archive',  gz   => 'archive', iso  => 'archive', tgz  => 'archive', 
# 	         dmg  => 'binary',    exe  => 'binary',   pkg  => 'binary');

my $count_total = 0;
my %types;
my %media;
my %unknown_ext;

foreach (@names){
    next unless /\.tree\.moo\.db$/;

    my $Tree = dbfile_load_md5(dir => $data_dir, name => $_);

    my $count = $Tree->count;
    say "Datafile: $_ Loaded $count records";
    


    while (my $Node = $Tree->Each){
	$count_total += 1;
	# Debug code
	# last if ($count_total > 800);

	next unless $Node->isfile;
	$Files->merge($Node);

	# Sum media size
	my $media = $Node->media;
	$types{$media} += $Node->size;

	# my $ext = lc($Node->ext);
	# $ext = substr($ext, 1) if ($ext);
	$unknown_ext{$Node->ext} += $Node->size if ($Node->media eq 'unknown' && $Node->ext);

	# Add to book list
	if ($media eq 'ebook' || $Node->filename =~ /\(ebook/i){
	    $Ebook->merge($Node);
	}

	# Add to video list
	if ($media eq 'video'){
	    $Video->merge($Node);
	}


    }
}

say " ";
say "Total Records: $count_total";


# Summerize Media
my @type_keys = sort( { $types{$b} <=> $types{$a} } keys %types);

say "\nTypes: ";
foreach my $type (@type_keys[0..9]){
    printf "%-8s %6s\n", $type, format_bytes($types{$type});
}

# Sumerize unknown ext
my @ext_keys = sort( { $unknown_ext{$b} <=> $unknown_ext{$a} } keys %unknown_ext);

say "\nUnknown Extensions: ";
foreach my $ext (@ext_keys[0..9]){
    printf "%-8s %6s\n", $ext, format_bytes($unknown_ext{$ext});
}






say "\n";
# Save Ebooks
say "Saving ", $Ebook->count, " Ebook Records";
dbfile_save_md5(List => $Ebook, dir => $data_dir, name => "ebook.moo.db");

# Save Video
say "Saving ", $Video->count, " Video Records";
dbfile_save_md5(List => $Video, dir => $data_dir, name => "video.moo.db");

# Save Files
say "Saving ", $Files->count, " All Files Records";
dbfile_save_md5(List => $Files, dir => $data_dir, name => "file.moo.db");

my $Dupes = NodeHeap->new;
my $i = 0;

# 
# Includes files with size match, may not be md5 match
#
foreach my $size (keys %{$Files->size_HoA}){
    my @Nodes = @{${$Files->size_HoA}{$size}};
    next if (@Nodes <= 1);
    
    $i++;
    $ScanDirMD5::size_count{$size} = scalar(@Nodes);
    $Dupes->insert(@Nodes);
}

say "Dupe Size Number: $i Files: ", $Dupes->count;
dbfile_save_md5(List => $Dupes, dir => $data_dir, name => "dupes.moo.db");

save_dupes(verbose => 3); 
