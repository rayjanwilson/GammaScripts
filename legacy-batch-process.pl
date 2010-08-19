#!/usr/bin/perl -w

use strict;
use File::Basename;

# this is a quick script to process a bunch of L0 products to L1 SLC with gamma, generate brose images with gamma and create_thumbs,
# generate a kml of the resulting L1 SLC, and a text file of the dopplers.

# it can be cleaned up a lot, but this works for now.

# you'll need gamma and create_thumbs installed, and the script SLC_process_legacy_L0_Detected_geo.pl which manages the gamma processing.

# usage: legacy-batch-process.pl /path/to/L0s/directory

use Getopt::Long;
use Pod::Usage;

my $man = 0;
my $help = 0;
my $debug = 0;
my $gamma = 0;

## Parse options and print usage if there is a syntax error,
## or if usage was explicitly requested.
GetOptions('help|?|h' => \$help, 
        'man|m' => \$man,
        'gamma|g' => \$gamma,
        'debug|d' => \$debug) or pod2usage(2);
pod2usage(-verbose => 1) if $help;
pod2usage(-verbose => 2) if $man;
pod2usage(-verbose => 2, -msg => "$0: Too many folders given.\n") if (@ARGV > 1);

## If no arguments were given, then allow STDIN to be used only
## if it's not connected to a terminal (otherwise print usage)
pod2usage(-verbose => 2, -msg => "$0: No folders given.\n") if ((@ARGV == 0) && (-t STDIN));

my $process_directory;
my $home_directory;

my $legacy_SLC_processor = "~/dev/git/GammaScripts/SLC_process_legacy_L0_Detected_geo.pl";

if(-d $ARGV[0]){
    print "you want me to work on directory $ARGV[0]\n";

    $process_directory=$ARGV[0];
    $home_directory = `pwd`;
    chomp($home_directory);
    print "Process directory = $process_directory\n";
    print 
    print "Home directory = $home_directory\n";

    my @ldrFiles = `find $process_directory -name "*.ldr"`;
    my $size = @ldrFiles;
    my $i=1;
    my $meta_hash = {};
    for my $ldr (@ldrFiles){
        my ($ldrname, $ldrdir) = fileparse($ldr);
        my $granule;
        my $slc;
        if($ldrname =~ /(.*)\.ldr/){
            $granule = $1;
            print "granule: $granule\n";
            $slc = "$granule.slc";
        }
        chdir($ldrdir) or die "Cant chdir to $ldrdir $!";
        print "\n($i\/$size)ldrname: $ldrname\tdir:$ldrdir\n";
        #my $whereami = `pwd`;
        #chomp($whereami);
        #print "\tim at:\t$whereami\n";
        if($gamma){
            #qx(echo -e \\n | $legacy_SLC_processor -c -d $ldrname) unless(-e $slc);
            my $cmd = "~/dev/git/GammaScripts/run_legacy.sh $legacy_SLC_processor $ldrname";
            system($cmd);
            
            #range_pixels:                         4912   image output samples
            my $width_grep = `grep -i range_pixels $granule.slc.par`;
            chomp($width_grep);
            my $width;
            if ($width_grep =~ /range_pixels:\s*(\d*).*/){
                $width = $1;
            }
            print "making image...\n";
            `rasSLC $granule.slc $width 1 0 1 4 1.0 .5 1 1 0 $granule.bmp` unless (-e "$granule.bmp");            
        }else{
            my $command = "create_thumbs -log $granule.browse.log -browse -output-format jpg -scale 8 -L0 ceos -out-dir . -save-metadata $granule.raw";
            system($command) unless (-e "$granule.jpg");
        }
        #`metadata -save -meta $granule`;
        #`convert2vector $granule.ldr $granule.kml`;
        
        my @meta = `ls *.meta`;
        chomp($meta[0]);
        my $info = getMetaData($meta[0], $granule);
        $meta_hash->{$granule} = $info;
        makeKML($granule);
        
        chdir($home_directory) or die "Cant chdir to $home_directory $!";
        $i=$i+1;
    }
    saveMetaData($meta_hash, $process_directory);
}else{
    die "you need to give me a directory of L0 images to work on\n";
}

sub getMetaData{
    my $metadata_file = $_[0];
    chomp($metadata_file);
    my $granule = $_[1];
    
    my $info = {};
    $info->{'granule'} = $granule;
    open(META, $metadata_file) or die "cant open $metadata_file\n $1\n";
    my @metadata = <META>;
    close(META);
    
    foreach my $line (@metadata){
        if($line =~ /\s{4}dopRangeCen:\s(.*)\s*\#.*/){
            $info->{'dopRangeCen'} = $1;
        }elsif($line =~ /\s{4}dopRangeLin:\s(.*)\s*\#.*/){
            $info->{'dopRangeLin'} = $1;
        }elsif($line =~ /\s{4}dopRangeQuad:\s(.*)\s*\#.*/){
            $info->{'dopRangeQuad'} = $1;
        }elsif($line =~ /\s{4}dopAzCen:\s(.*)\s*\#.*/){
            $info->{'dopAzCen'} = $1;
        }elsif($line =~ /\s{4}dopAzLin:\s(.*)\s*\#.*/){
            $info->{'dopAzLin'} = $1;
        }elsif($line =~ /\s{4}dopAzQuad:\s(.*)\s*\#.*/){
            $info->{'dopAzQuad'} = $1;
        }elsif($line =~ /\s{4}line_count:\s(.*)\s*\#.*/){
            $info->{'line_count'} = $1;
        }elsif($line =~ /\s{4}prf:\s(.*)\s*\#.*/){
            $info->{'prf'} = $1;
        }
    }
    
    return $info;
}

sub makeKML{
    my $granule = $_[0];
    my $slc_par = "$granule.slc.par";
    open(SLCPAR, $slc_par);
    my @slc_par_lines = <SLCPAR>;
    close(SLCPAR);
    my ($corner1, $corner2, $corner3, $corner4, $lookat_long, $lookat_lat);
    foreach my $line (@slc_par_lines){
        if($line =~/map_coordinate_1:\s*([\d|-]\d*\.\d*)\s*([\d|-]\d*\.\d*)\s*.*/){
            $corner1 = "$2,$1,200";
            $lookat_long = "$2";
            $lookat_lat = "$1";
            print "corner1:\t$corner1\n";
        }elsif($line =~/map_coordinate_2:\s*([\d|-]\d*\.\d*)\s*([\d|-]\d*\.\d*)\s*.*/){
            $corner2 = "$2,$1,200";
        }elsif($line =~/map_coordinate_3:\s*([\d|-]\d*\.\d*)\s*([\d|-]\d*\.\d*)\s*.*/){
            $corner3 = "$2,$1,200";
        }elsif($line =~/map_coordinate_4:\s*([\d|-]\d*\.\d*)\s*([\d|-]\d*\.\d*)\s*.*/){
            $corner4 = "$2,$1,200";
        }
    }
    open(KML, ">$granule.L0.kml");
    print KML "<\?xml version\=\"1.0\" encoding=\"UTF\-8\"\?>
        <kml xmlns=\"http://earth.google.com/kml/2.2\">;
        <Document>
        <Placemark>
            <description></description>
            <name>$granule</name>
            <LookAt>
                <longitude>$lookat_long</longitude>
                <latitude>$lookat_lat</latitude>
                <range>400000</range>
            </LookAt>
            <visibility>1</visibility>
            <open>1</open>
            <Style>
                <LineStyle>
                    <color>ffff9900</color>
                    <width>2</width>
                </LineStyle>
                <PolyStyle>
                    <color>1fff5500</color>
                </PolyStyle>
            </Style>
            <Polygon>
                <extrude>1</extrude>
                <altitudeMode>absolute</altitudeMode>
                <outerBoundaryIs>
                    <LinearRing>
                        <coordinates>";
                            print KML "\n$corner1";
                            print KML "\n$corner2";
                            print KML "\n$corner4";
                            print KML "\n$corner3";
                            print KML "\n$corner1\n";
                        print KML "</coordinates>
                    </LinearRing>
                </outerBoundaryIs>
            </Polygon>
        </Placemark>
        </Document>
        </kml>";
    close(KML);
}

sub saveMetaData{
    my $hash = $_[0];
    my $proc_dir = $_[1];
    my $savefile;
    if($proc_dir =~ /(.*)\//){
        $savefile = "$1.dopplers";
    }elsif($proc_dir =~ /(.*)/){ #sometimes forget to add the trailing / when calling this script
        $savefile = "$1.dopplers";
    }
    print "doppler savefile:\t$savefile\n";
    open(SAVE, ">$savefile");
    #print SAVE "$info->{'granule'}\t$info->{'dopRangeCen'}\t$info->{'dopRangeLin'}\t$info->{'dopRangeQuad'}\t$info->{'dopAzCen'}\t$info->{'dopAzLin'}\t$info->{'dopAzQuad'}\t$info->{'line_count'}\n";
    print SAVE "granule\tdopRangeCen\tdopRangeLin\tdopRangeQuad\tdopAzCen\tdopAzLin\tdopAzQuad\tline_count\tprf\n";
    foreach my $granule (sort keys %$hash){
        print SAVE "$granule\t$hash->{$granule}->{'dopRangeCen'}\t$hash->{$granule}->{'dopRangeLin'}\t$hash->{$granule}->{'dopRangeQuad'}\t$hash->{$granule}->{'dopAzCen'}\t$hash->{$granule}->{'dopAzLin'}\t$hash->{$granule}->{'dopAzQuad'}\t$hash->{$granule}->{'line_count'}\t$hash->{$granule}->{'prf'}\n";
    }
    close(SAVE);
}

#    line_count: 28840                          # Number of lines in image
#    dopRangeCen: -292.74726                    # Range doppler centroid [Hz]
#    dopRangeLin: 0.0072110037                  # Range doppler per range pixel [Hz/pixel]
#    dopRangeQuad: -3.5472225e-19               # Range doppler per range pixel sq. [Hz/(pixel^2)]
#    dopAzCen: -292.74726                       # Azimuth doppler centroid [Hz]
#    dopAzLin: 9.5013259e-05                    # Azimuth doppler per azimuth pixel [Hz/pixel]
#    dopAzQuad: -4.4105974e-18                  # Azimuth doppler per azimuth pixel sq. [Hz/(pixel^2)]
