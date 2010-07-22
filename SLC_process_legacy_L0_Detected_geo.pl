#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use File::Copy;

my $man = 0;
my $help = 0;
my $debug = 0;
my $clean = 0;

## Parse options and print usage if there is a syntax error,
## or if usage was explicitly requested.
GetOptions('help|?|h' => \$help, 
        'man|m' => \$man,
        'clean|c' => \$clean,
        'debug|d' => \$debug) or pod2usage(2);
pod2usage(-verbose => 1) if $help;
pod2usage(-verbose => 2) if $man;
pod2usage(-verbose => 2, -msg => "$0: Too many files given.\n") if (@ARGV > 1);

## If no arguments were given, then allow STDIN to be used only
## if it's not connected to a terminal (otherwise print usage)
pod2usage(-verbose => 2, -msg => "$0: No files given.\n") if ((@ARGV == 0) && (-t STDIN));

my ($filename, $dir) = fileparse($ARGV[0]);

sub clean{
    #clean the working directory if the option is given
    print "\nCleaning...\n";
    #clean RSAT_raw output files
    `rm *.fix *.par`;
    #clean dop_mlcc output files
    `rm *.mlcc`;
    #clean doppler output files
    `rm *.dop`;
    #clean rspec_IQ output files
    `rm *.rspec`;
    #clean pre_rc_RSAT output files
    `rm *.rc`;
    #clean autof output files
    `rm *.autof`;
    #clean az_proc output files
    `rm *.slc`;
    print "Ready to process\n";
}

sub check_files{
    #this function makes sure the given folder has the files we need for legacy L0 processing
    my $directory = $_[0];
    print "I want to open $directory\n" if($debug);
    
    opendir(DIR, $directory) or die "Cant open $directory: $!\n";
    my @files = grep {!/^\.+$/} readdir(DIR);
    close(DIR);
    
    if ($debug){
        print "\n\n$directory contains:\n";
        foreach (@files){
            print "$_\n";
        }
        print "\n";
    }
    
    #check for the required extensions
    my @required_ext = ('ldr', 'raw', 'pi');
    my %has_ext;
    foreach my $file (@files){
        $file =~ /\..*\.(.*)$/;
        my $ext = $1;
        if($ext eq 'ldr'){
            $has_ext{'ldr'} = 1;
        }elsif($ext eq 'raw'){
            $has_ext{'raw'} = 1;
        }elsif($ext eq 'pi'){
            $has_ext{'pi'} = 1;
        }
    }
    if($has_ext{'ldr'} != 1 or $has_ext{'raw'} != 1 or $has_ext{'pi'} != 1){
        die "$directory doesnt contain the right filetypes.\n.ldr .raw and .pi are required\n";
    }else{
        print "we have all our files\n";

        return 1;
    }
}

sub ripLeader{
    my $leader = $_[0];
    my $info = {};
    #production: J1_24495_STD_F0468_01.3744.ldr
    #scaleup: R1_52109_ST3_L0_F297.000.ldr
    if($leader =~ /(..)_(\d{5})_(...)_(L0)_(\w\d{3})\.(\d{3})\.ldr/){
        #scaleup leader file
        $info->{'plat'} = $1;
        $info->{'rev'} = $2;
        $info->{'mode'} = $3;
        $info->{'proc_level'} = $4;
        $info->{'frame'} = $5;
        if($leader =~ /(.*)\.ldr/){
            $info->{'granule'} = $1;
        }
        print "plat: $info->{'plat'}\trev: $info->{'rev'}\tmode: $info->{'mode'}\tproc_level: $info->{'proc_level'}\tframe: $info->{'frame'}\n" if($debug);
    }elsif($leader =~ /(..)_(\d{5})_(...)_(\w\d*)_(.*)\.(\d*)\.ldr/){
        #production leader file
        $info->{'plat'} = $1;
        $info->{'rev'} = $2;
        $info->{'mode'} = $3;
        $info->{'frame'} = $4;
        if($leader =~ /(.*)\.ldr/){
            $info->{'granule'} = $1;
        }
        print "plat: $info->{'plat'}\trev: $info->{'rev'}\tmode: $info->{'mode'}\tframe: $info->{'frame'}\n" if($debug);
    }else{
        die "this leader file is not recognized at this time:\n$leader";
    }
    return $info;
}

sub run_RSAT_raw{
    # RADARSAT raw data reformatting + generation of MSP processing parameter file
    #rsat_raw %n%.ldr rsat.par p%n%.slc.par %n%.raw %n%.fix
    #usage: rsat_raw <CEOS_leader> <SAR_par> <PROC_par> <raw_data_files...> <raw_out>

    #input parameters:
    #   CEOS_ldr        (input) CEOS leader file
    #   SAR_par         (output) MSP SAR sensor parameter file
    #   PROC_par        (output) MSP processing parameter file
    #   raw_data_files  (input) Radarsat raw data file(s) to condition and concatenate
    #   raw_out         (output) Radarsat conditioned raw output data file
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $CEOS_ldr = "$granule.ldr";
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $raw_data_file = "$granule.raw";
    my $raw_out = "$granule.fix";
    
    print "RSAT_raw...\n";
    print "CEOS_ldr:\t $CEOS_ldr\n" if($debug);
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "raw_data_file:\t $raw_data_file\n" if($debug);
    print "raw_out:\t $raw_out\n" if($debug);
    print "\n";
    
    `RSAT_raw $CEOS_ldr $SAR_par $PROC_par $raw_data_file $raw_out`;
}

sub run_dop_mlcc{
    # Doppler ambiguity estimation for IQ SAR data MLCC algorithm
    #dop_mlcc rsat.par p%n%.slc.par %n%.fix %n%.mlcc

    #usage: dop_mlcc <SAR_par> <PROC_par> <signal_data> [output_plot] [loff] [nlines]

    #input parameters:
    #   SAR_par      (input) MSP SAR sensor parameter file
    #   PROC_par     (input) MSP processing parameter file
    #   signal_data  (input) uncompressed raw SAR signal data (I/Q complex)
    #   output_plot  (output) plot file, correlation phase for MLCC
    #   loff         number of lines offset (enter - for default=parameter file value)
    #   nlines       number of range lines to process (default=proc. parameters)
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $signal_data = "$granule.fix";
    my $output_plot = "$granule.mlcc";
    #my $loff = "-";
    #my $nlines 
    
    print "\ndop_mlcc...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "signal_data:\t $signal_data\n" if($debug);
    print "output_plot:\t $output_plot\n" if($debug);
    print "\n";
    
    `dop_mlcc $SAR_par $PROC_par $signal_data $output_plot`;
}

sub run_doppler{
    # Doppler centroid estimation across track for IQ SAR data  ***
    # doppler rsat.par p%n%.slc.par %n%.fix %n%.dop - 24

    # usage: doppler <SAR_par> <PROC_par> <signal_data> <doppler> [loff] [nsub] [ambig_flag] [namb]

    # input parameters:
    #   SAR_par      (input) SAR sensor parameter file
    #   PROC_par     (input) processing parameter file
    #   signal_data  (input) input uncompressed IQ raw SAR data file
    #   doppler      (output) Doppler as a function of slant range
    #   loff         number of lines offset (enter - for default=parameter file value)
    #   nsub         number of azimuth subapertures (default = 12)
    #   ambig_flag   Doppler ambiguity resolution flag
    #                 0 = use unambiguous Doppler Ambiguity Resolver (DAR) estimate (default)
    #                 1 = estimate Doppler ambiguity number from the Doppler slope
    #                 2 = command line entry for the Doppler ambiguity number
    #   namb         user defined number of Doppler ambiguities to add to the Doppler function
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $signal_data = "$granule.fix";
    my $doppler = "$granule.dop";
    my $loff = "-";
    my $nsub = "24";
    
    print "doppler...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "signal_data:\t $signal_data\n" if($debug);
    print "doppler:\t $doppler\n" if($debug);
    print "loff:\t $loff\n" if($debug);
    print "nsub:\t $nsub\n" if($debug);
    print "\n";
    
    `doppler $SAR_par $PROC_par $signal_data $doppler $loff $nsub`;
}

sub run_rspec_IQ{
    # *** Range spectrum estimation for IQ raw SAR data ***
    #rspec_iq rsat.par p%n%.slc.par %n%.fix %n%.rspec

    # usage: rspec_iq <SAR_par> <PROC_par> <signal_data> <range_spec> [loff] [nlspec] [nrfft]

    # input parameters:
    #   SAR_par      (input) MSP SAR sensor parameter file
    #   PROC_par     (input) MSP processing parameter file
    #   signal_data  (input) uncompressed raw SAR signal data
    #   range_spec   (output) range spectrum plot file (text)
    #   loff         offset echoes from start of raw data file (default from PROC_par file)
    #   nlspec       number of lines to estimate spectrum (default: 1024)
    #   nrfft        range FFT size (default: 4096)
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $signal_data = "$granule.fix";
    my $range_spec = "$granule.rspec";    
    
    print "rspec_IQ...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "signal_data:\t $signal_data\n" if($debug);
    print "range_spec:\t $range_spec\n" if($debug);    
    print "\n";
    
    `rspec_IQ $SAR_par $PROC_par $signal_data $range_spec`;
}

sub run_pre_rc_RSAT{
    # prefilter/SAR range compression for Radarsat-1 raw data ***
    # pre_rc_RSAT rsat.par p%n%.slc.par %n%.fix %n%.rc

    # usage: pre_rc_rsat <SAR_par> <PROC_par> <signal_data> <rc_data> [prefilt_dec] [loff] [nl] [nr_samp] [kaiser] [filt_lm] [nr_ext] [fr_ext]

    # input parameters:
    #   SAR_par      (input) MSP SAR sensor parameter file
    #   PROC_par     (input) MSP processing parameter file
    #   signal_data  (input) uncompressed raw SAR signal data filename
    #   rc_data      (output) range compressed data filename
    #   prefilt_dec  prefilter decimation factor (default from PROC_par)
    #   loff         number of lines offset (enter - for default=parameter file value)
    #   nl           number of lines filter/range compress (enter - for default=parameter file value)
    #   nr_samp      number of range samples (enter - for default from PROC_par)
    #   kaiser       range chirp Kaiser window parameter beta (default=2.120, -30 dB sidelobes)
    #   filt_lm      filter length multiplier, FIR length = FIR_lm * prefilt_dec + 1 (default=8)
    #   nr_ext       near range swath extension in samples (default from PROC_par)pixels
    #   fr_ext       far range swath extension in samples (default from PROC_par)
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $signal_data = "$granule.fix";
    my $rc_data = "$granule.rc";
    
    print "pre_rc_RSAT...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "signal_data:\t $signal_data\n" if($debug);
    print "rc_data:\t $rc_data\n" if($debug);    
    print "\n";
    
    `pre_rc_RSAT $SAR_par $PROC_par $signal_data $rc_data`;
}

sub run_autof{
    # Autofocus for range/Doppler processing ***
    #autof rsat.par p%n%.slc.par %n%.rc %n%.autof 1 1 2048 0 2048

    # usage: autof <SAR_par> <PROC_par> <rc_data> <autofocus> [SNR_min] [prefilter] [auto_az] [az_offset] [auto_bins] [dop_ambig]

    # input parameters:
    #   SAR_par    (input) MSP SAR sensor parameter file
    #   PROC_par   (input) MSP processing parameter file
    #   rc_data    (input) range compressed data file
    #   autofocus  (output) autofocus correlation function file (text format)
    #   SNR_min    minimum autofocus SNR to accept velocity estimate (default=5.0)
    #   prefilter  prefilter decimation factor (default from PROC_par)
    #   auto_az    autofocus azimuth correlation patch size (2**N, default = 2048)
    #   az_offset  offset in prefiltered lines from start of file (default=0)
    #   auto_bins  number of range bins to use for autofocus (2**N, default=1024)
    #   dop_ambig  Doppler ambiguity correction flag
    #       0: Doppler centroid remains unchanged
    #       1: Doppler centroid ambiguity corrected (default)
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $rc_data = "$granule.rc";
    my $autofocus = "$granule.autof";
    my $SNR_min = "1";
    my $prefilter = "1";
    my $auto_az = "2048";
    my $az_offset = "0";
    my $auto_bins = "2048";
    
    print "autof...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "rc_data:\t $rc_data\n" if($debug);
    print "autofocus:\t $autofocus\n" if($debug);
    print "SNR_min:\t $SNR_min\n" if($debug);
    print "prefilter:\t $prefilter\n" if($debug);
    print "az_offset:\t $az_offset\n" if($debug);
    print "auto_bins:\t $auto_bins\n" if($debug);    
    print "\n";
    
    `autof $SAR_par $PROC_par $rc_data $autofocus $SNR_min $prefilter $auto_az $az_offset $auto_bins`;
}

sub run_az_proc{
    # SAR range + Doppler azimuth processor (2D-Doppler variation) ***
    # az_proc rsat.par p%n%.slc.par %n%.rc %n%.slc 8192 0 0 0 2.12

    # usage: az_proc <SAR_par> <PROC_par> <rc_data> <SLC> [az_patch] [SLC_format] [cal_fact] [SLC_type] [kaiser] [npatch]

    # input parameters:
    #   SAR_par     (input) MSP SAR sensor parameter file
    #   PROC_par    (input) MSP processing parameter file
    #   rc_data     (input) input range compressed data file
    #   SLC         (output) Single Look Complex image (FCOMPLEX or SCOMPLEX format)
    #   az_patch    along-track azimuth patch size (range lines): (2**N 2048, 4096, 8192..)
    #   SLC_format  SLC output format (default: MSP PROC_par file)
    #               0: FCOMPLEX (pairs of 4-byte float)
    #               1: SCOMPLEX (pairs of 2-byte short integer)
    #   cal_fact    radiometric calibration factor [dB] (default=0.0)
    #               proposed factors [dB] for absolute calibration factors [dB]:
    #                 ERS1 1991-1996: -10.3 dB (49.7 dB for SCOMPLEX output format)
    #                 ERS1 1997-2000: -12.5 dB (47.5 dB for SCOMPLEX output format)
    #                 ERS2:            -2.8 dB (57.2 dB for SCOMPLEX output format)
    #                 JERS:           -22.1 dB (37.9 dB for SCOMPLEX output format)
    #   SLC_type    output data type
    #                 0: sigma0 (SQR(re) + SQR(im) => sigma0)
    #                 1: gamma0 = sigma0/cos(inc) (SQR(re) + SQR(im) => gamma0)
    #   kaiser      Kaiser window parameter for azimuth reference function weighting (default: 2.120)
    #   npatch      number of along-track patches to process
    
    my $info = $_[0];
    my $granule = $info->{'granule'};
    my $SAR_par = "$granule.par";
    my $PROC_par = "$granule.slc.par";
    my $rc_data = "$granule.rc";
    my $SLC = "$granule.slc";
    my $az_patch = "8192";
    my $SLC_format = "0";
    my $cal_fact = "0";
    my $SLC_type = "0";
    my $kaiser = "2.12";
    
    print "autof...\n";
    print "SAR_par:\t $SAR_par\n" if($debug);
    print "PROC_par:\t $PROC_par\n" if($debug);
    print "rc_data:\t $rc_data\n" if($debug);
    print "SLC:\t $SLC\n" if($debug);
    print "az_patch:\t $az_patch\n" if($debug);
    print "SLC_format:\t $SLC_format\n" if($debug);
    print "cal_fact:\t $cal_fact\n" if($debug);
    print "SLC_type:\t $SLC_type\n" if($debug);
    print "kaiser:\t $kaiser\n" if($debug);
    print "\n";
    
    #link the antennae pattern file
    `ln -s \$MSP_HOME/sensors/RSAT_S3_antenna.gain RSAT_S3_antenna.gain`;
    `az_proc $SAR_par $PROC_par $rc_data $SLC $az_patch $SLC_format $cal_fact $SLC_type $kaiser`;
}

sub gamma{
    my $info = $_[0];
    print "Running gamma\n";
    clean() if($clean);
    run_RSAT_raw($info);
    run_dop_mlcc($info);
    run_doppler($info);
    run_rspec_IQ($info);
    run_pre_rc_RSAT($info);
    run_autof($info);
    run_autof($info); #yes we do it twice =P maybe franz had a typo =P
    run_az_proc($info);
}
    
print "filename:\t$filename\n" if($debug);
print "directory:\t$dir\n" if($debug);

#check that we are starting with a .ldr file
if($filename =~ /\..*\.(.*)$/){
    print "ext: $1\n" if($debug);
    pod2usage(-verbose => 1, -msg => "$0 requires a .ldr file\n") if($1 ne 'ldr');
}else{
    pod2usage(-verbose =>1, -msg => "unrecognized file $filename!\n$0 requires a .ldr file\n");
}

print "continue processing...\n" if(check_files($dir));
chdir($dir);

my $info = {};
$info = ripLeader($filename);

gamma($info);

print "directory contents...\n" if($debug);
print `ls` if($debug);

__END__

=head1 NAME

SLC_process_legacy_L0_Detected_geo.pl

=head1 SYNOPSIS

B<NAME> [options] [leader file]

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-debug>

Prints additional info while processing

=back

=head1 DESCRIPTION

B<This program> takes a legacy L0 product from ASF, uses Gamma to process it to L1.1,
and then uses Mapready to process it to Detected Georeferenced

=cut



