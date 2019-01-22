#!/usr/bin/env perl
#
# Convert list of files with ghostscript to "standard" files
# Based upon convert5.sh
#
#

# ToDo

use Modern::Perl; 		# Implies strict, warnings
use autodie;			# Easier write open  /close code

#
# Read args and check files exisit
#
# my $file_path = shift(@ARGV);

foreach my $file_path (@ARGV){
    # say "Converting: $file_path";
    my $status = convert_v28($file_path);
    my $status = convert_v29($file_path);
}


#
# Loop though files
#


# Check converted file does not exist


# Convert with ghostscript


# Done
exit;



#
# Convert file with ghostcript
#
use File::Basename;

sub convert_v28 {
    my $file_path = shift(@_);
    my $cmd = "ps2pdf";

    # Check file exisits
    if (!-e $file_path){
	die ("File does not exist $file_path");
    }
    my $size_start = -s $file_path;
    my  ($basename, $path, $ext) = File::Basename::fileparse($file_path, qr/\.[^.]*/);
    if ($ext ne ".pdf"){	
	warn "WARN: Can not convert non-pdf file $file_path";
	return;
    }


    my $file_temp = $path.$basename.".tmp";

    my $file_convert = $path.$basename."_v28e".$ext;
    
    # Make sure new filename does not exists
    if (-e $file_convert){
	# warn "WARN: Converted file $file_convert already exists";
	return;
    }
	
    say "Converting v28: ",$basename.$ext;

    my @cmd_options = ("-dPDFSETTINGS=/ebook");
    # Big Difference on some files
    # push(@cmd_options, "-dColorConversionStrategy=/LeaveColorUnchanged");

    # Standard settings for color generate can't initalize downsample errors. Failed: /Subsample /Average 
    push(@cmd_options, "-dDownsampleColorImages=true",  "-dColorImageDownsampleThreshold=1.1", "-dColorImageDownsampleType=/Bicubic");
    push(@cmd_options, "-dDownsampleGrayImages=true",    "-dGrayImageDownsampleThreshold=1.1" );
    push(@cmd_options, "-dDownsampleMonoImages=true",  "-dMonoImagesDownsampleThreshold=1.1");

    push(@cmd_options, "-dMaxInlineImageSize=0");
    
    
    my $status = system($cmd, @cmd_options, $file_path, $file_temp);
    # say "System status: $status";
    if ($status == 0){
	my $size_end = -s $file_temp;
	if ($size_end > 1.20 * $size_start){
	    say "WARN: New file > 120% initial file ", int($size_end/$size_start * 100 + 0.5), "%";
	} 
	rename($file_temp, $file_convert);
    } else {
	say "Command failed $!";
    }

    return $status;

}

sub convert_v29 {
    my $file_path = shift(@_);
    my $cmd = "pdftocairo";



    # Check file exisits
    if (!-e $file_path){
	die ("File does not exist $file_path");
    }
    my $size_start = -s $file_path;
    my  ($basename, $path, $ext) = File::Basename::fileparse($file_path, qr/\.[^.]*/);
    if ($ext ne ".pdf"){	
	warn "WARN: Can not convert non-pdf file $file_path";
	return;
    }


    my $file_temp = $path.$basename.".tmp";
    my $file_convert = $path.$basename."_v29".$ext;
    
    # Make sure new filename does not exists
    if (-e $file_convert){
	# warn "WARN: Converted file $file_convert already exists";
	return;
    }
	
    say "Converting v29: ",$basename.$ext;

    my @cmd_options = ("-pdf");
    
    my $status = system($cmd, @cmd_options, $file_path, $file_temp);
    # say "System status: $status";
    if ($status == 0){
	my $size_end = -s $file_temp;
	if ($size_end > 1.20 * $size_start){
	    say "WARN: New file > 120% initial file ", int($size_end/$size_start * 100 + 0.5), "%";
	} 
	rename($file_temp, $file_convert);
    } else {
	say "Command failed $!";
    }

    return $status;

}

