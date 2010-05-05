#!/usr/bin/env python
#-*- coding:utf-8 -*-

"""
    PROJECT - GammaScripts

    DESCRIPTION - This is a module in the GammaScripts collection.
    Here we take a L1.0 and process it to L1.1 and L1.5 with Gamma

    @copyright: 2010 by rayjan <rayjan.wilson@alaska.edu>
    @license: GNU GPL, see COPYING for details.
"""

import os, sys, re
import subprocess

def runCommand(command):
    #simple use of subprocess to run an os command
    #you'll need to import:
    #from subprocess import *
    try:
        retcode = subprocess.call(command, shell=True)
        if retcode < 0:
            print >>sys.stderr, "Child was terminated by signal", -retcode
        else:
            print >>sys.stderr, "Child returned", retcode
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e


# gamma needs these files to be "local" to the working directory. Don't ask why. 
# instead of copying the files, we'll just make symbolic links'
try:
    subprocess.call("ln -s ${GAMMA_HOME}/MSP_v11.5/sensors/constant_antenna.gain constant_antenna.gain", shell=True)
except OSError, e:
    print >>sys.stderr, "Execution failed:", e

try:
    subprocess.call("ln -s ${GAMMA_HOME}/MSP_v11.5/sensors/palsar_ant_20061024.dat palsar_ant_20061024.dat", shell=True)
except OSError, e:
    print >>sys.stderr, "Execution failed:", e

n = "22202"     #orbit number
fr = "6470"     #frame number


#echo $n
#echo $fr

print "########### running PALSAR_proc... ###########"
CEOS_SAR_leader = "LED-ALPSRP"+n+fr+"-H1.0__A"
SAR_par = "palsar_"+fr+".par"
PROC_par = "p"+n+"_"+fr+".slc.par"
CEOS_raw_data = "IMG-HH-ALPSRP"+n+fr+"-H1.0__A"
raw_out = n+"_"+fr+".raw"
TX_POL = "0"
RX_POL = "0"

command = ["PALSAR_proc", CEOS_SAR_leader, SAR_par, PROC_par, CEOS_raw_data, raw_out, TX_POL, RX_POL]
try:
    subprocess.check_call(command)
except OSError, e:
    print >>sys.stderr, "Execution failed:", e
#runCommand("PALSAR_proc LED-ALPSRP"+n+fr+"-H1.0__A palsar_"+fr+".par p"+n+"_"+fr+".slc.par IMG-HH-ALPSRP"+n+fr+"-H1.0__A "+n+"_"+fr+".raw 0 0")
#PALSAR_proc LED-ALPSRP222026460-H1.0__A palsar_6460.par p22202_6460.slc.par IMG-HH-ALPSRP222026460-H1.0__A 22202_6460.raw 0 0

print "########### running PALSAR_antpat... ###########  "
PALSAR_ANT = "palsar_ant_20061024.dat"
ant_file = "palsar_antpat_msp.dat"
lk_ang = "-" #it's a default

command = ["PALSAR_antpat", SAR_par, PROC_par, PALSAR_ANT, ant_file, lk_ang, TX_POL, RX_POL]
try:
    subprocess.check_call(command)
except OSError, e:
    print >>sys.stderr, "Execution failed:", e
#PALSAR_antpat palsar_6460.par p22202_6460.slc.par palsar_ant_20100430.dat palsar_antpat_msp.dat - 0 0

print "########### running dop_mlcc... ###########  "
runCommand("dop_mlcc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.mlcc - - 1 -")
#dop_mlcc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.mlcc - - 1 -

print "########### running doppler... ###########  "
runCommand("doppler palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.dop - - -")
#doppler palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.dop - - -

print "########### running rspec_JERS... ###########  "
runCommand("rspec_JERS palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rspec - - - - -")
#rspec_JERS palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rspec - - - - -

print "########### running pre_rc... ###########  "
runCommand("pre_rc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rc - - - - - - - -")
#pre_rc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rc - - - - - - - -

print "########### running autof... ###########  "
runCommand("autof palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.autof 2.5 - 4096 - 1024 1")
#autof palsar_6460.par p22202_6460.slc.par 22202_6460.rc 22202_6460.autof 2.5 - 4096 - 1024 1

print "########### running az_proc... ###########  "
runCommand("az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12")
#az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12

print "########### running rasslc... ###########  "
runCommand("rasSLC ${n}_${fr}.slc 4920 - - 2 6 - - -1 0 - ${n}_${fr}.bmp")
