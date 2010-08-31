#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;

my ($HEAD) = <<"#END";
################################################################################
# 
#   SLC_process_L0_L1.5g
#
#   This program takes a L1.0 product from ASF, uses Gamma to process it to L1.1,
#   and then uses mapredy to process it to L1.5 georeferenced
#
#   Options:
#       -h  print this message.
#       -d  debug mode. will not print to file
#
###############################################################################
#END

my ($base, $dir) = fileparse($ARGV[0]);
my ($help, $debug);
GetOptions( "help|h"    => \$help,
            "debug|d" => \$debug) 
        or do {
            print $HEAD;
            exit;
            };

if($help) {
    print $HEAD;
    exit;
}

sub ripLeader{
    my $leader = $_[1];
}


print "basename:\t$base\n";
print "directory:\t$dir\n";
