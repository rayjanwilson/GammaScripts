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

def ripInfo(leader):
    p = re.compile('LED-\w*(\d\d\d\d\d)(\d\d\d\d)-*')
    orbit = p.match(leader).group(1)
    frame = p.match(leader).group(2)    
    return orbit, frame

def doit(leader, ceos_raw):
    n, fr = ripInfo(leader)
    print "orbit: ", n
    print "frame: ", fr
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

    #n = "22202"     #orbit number
    #fr = "6470"     #frame number

    print "########### running PALSAR_proc... ###########"
    CEOS_SAR_leader = leader
    SAR_par = "palsar_"+fr+".par"
    PROC_par = "p"+n+"_"+fr+".slc.par"
    CEOS_raw_data = ceos_raw
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
    signal_data = n+"_"+fr+".raw"
    output_plot = n+"_"+fr+".mlcc"
    loff = "-"
    nlines = "-"
    unknown_extra_1 = "1"
    unknown_extra_2 = "-"
    command = ["dop_mlcc", SAR_par, PROC_par, signal_data, output_plot, loff, nlines, unknown_extra_1, unknown_extra_2]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #dop_mlcc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.mlcc - - 1 -


    print "########### running doppler... ###########  "
    doppler = n+"_"+fr+".dop"
    nsub = "-"
    ambig_flag = "-"
    command = ["doppler", SAR_par, PROC_par, signal_data, doppler, loff, nsub, ambig_flag]
    #doesn't have namb or order
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #doppler palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.dop - - -

    print "########### running rspec_JERS... ###########  "
    range_spec = n+"_"+fr+".rspec"
    nr_samp = "-"
    nl_spec = "-"
    nr_ext = "-"
    fr_ext = "-"
    command = ["rspec_JERS", SAR_par, PROC_par, signal_data, range_spec, nr_samp, nl_spec, loff, nlines, nr_ext, fr_ext]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #runCommand("rspec_JERS palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rspec - - - - -")
    #rspec_JERS palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rspec - - - - -

    print "########### running pre_rc... ###########  "
    rc_data = n+"_"+fr+".rc"
    prefilt_dec = "-"
    nl = "-"
    kaiser = "-"
    filt_lm = "-"
    RFI_filt = "-"
    RFI_thres = "-"
    command = ["pre_rc", SAR_par, PROC_par, signal_data, rc_data, prefilt_dec, loff, nl, nr_samp, kaiser, filt_lm, nr_ext, fr_ext, RFI_filt, RFI_thres]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #runCommand("pre_rc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rc - - - - - - - -")
    #pre_rc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rc - - - - - - - -

    print "########### running autof... ###########  "
    autofocus = n+"_"+fr+".autof"
    SNR_min = "2.5"
    prefilter = "-"
    auto_az = "4096" #default = 2048
    az_offset = "-"
    auto_bins = "1024" #default = 1024
    dop_ambig = "1"
    command = ["autof", SAR_par, PROC_par, rc_data, autofocus, SNR_min, prefilter, auto_az, az_offset, auto_bins, dop_ambig]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #runCommand("autof palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.autof 2.5 - 4096 - 1024 1")
    #autof palsar_6460.par p22202_6460.slc.par 22202_6460.rc 22202_6460.autof 2.5 - 4096 - 1024 1

    print "########### running az_proc... ###########  "
    SLC = n+"_"+fr+".slc"
    az_patch = "16284"
    SLC_format = "0"
    cal_fact = "0"
    SLC_type = "0"
    #missing npatch
    command = ["az_proc", SAR_par, PROC_par, rc_data, SLC, az_patch, SLC_format, cal_fact, SLC_type, kaiser]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #runCommand("az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12")
    #az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12

    print "########### running rasslc... ###########  "
    width = "4920"
    start = "-"
    pixavr = "2"
    pixavaz = "6"
    scale = "-"
    exp = "-"
    LR = "-1"
    data_type = "0"
    hdrsz = "-"
    rasf = n+"_"+fr+".bmp"
    command = ["rasSLC", SLC, width, start, nlines, pixavr, pixavaz, scale, exp, LR, data_type, hdrsz, rasf]
    try:
        subprocess.check_call(command)
    except OSError, e:
        print >>sys.stderr, "Execution failed:", e
    #runCommand("rasSLC ${n}_${fr}.slc 4920 - - 2 6 - - -1 0 - ${n}_${fr}.bmp")


if __name__ == '__main__':
    import optparse
    usage = "usage: %prog [options] LED-file IMG-file"
    
    optp = optparse.OptionParser(usage=usage)
    
    (opts, args) = optp.parse_args()
    
    if len(args) >= 2:
        doit(args[0], args[1])
        
    else:
        print "fail"
    
    
