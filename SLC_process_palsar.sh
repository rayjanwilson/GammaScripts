#!/bin/bash

# a port of franz's gamma batch processing on the windows platform to linux
#if [ -d $1 ]
#then
#	results=`ls ${1}`
#	for i in $results
#	do
#		echo $i
		
#	done
#fi
#exit 0

#function

ln -s ${GAMMA_HOME}/MSP_v11.5/sensors/constant_antenna.gain constant_antenna.gain


n=22202     #orbit number
fr=6470   #frame number

palsar_ant=${GAMMA_HOME}/MSP_v11.5/sensors/palsar_ant_20061024.dat

echo $n
echo $fr

echo "########### running PALSAR_proc... ###########"
PALSAR_proc LED-ALPSRP${n}${fr}-H1.0__A palsar_${fr}.par p${n}_${fr}.slc.par IMG-HH-ALPSRP${n}${fr}-H1.0__A ${n}_${fr}.raw 0 0
#PALSAR_proc LED-ALPSRP222026460-H1.0__A palsar_6460.par p22202_6460.slc.par IMG-HH-ALPSRP222026460-H1.0__A 22202_6460.raw 0 0

echo "########### running Palsar_antpat... ###########  "
Palsar_antpat palsar_${fr}.par p${n}_${fr}.slc.par $palsar_ant palsar_antpat_msp.dat - 0 0
#PALSAR_antpat palsar_6460.par p22202_6460.slc.par palsar_ant_20100430.dat palsar_antpat_msp.dat - 0 0

echo "########### running dop_mlcc... ###########  "
dop_mlcc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.mlcc - - 1 -
#dop_mlcc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.mlcc - - 1 -

echo "########### running doppler... ###########  "
doppler palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.dop - - -
#doppler palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.dop - - -

echo "########### running rspec_JERS... ###########  "
rspec_JERS palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rspec - - - - -
#rspec_JERS palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rspec - - - - -

echo "########### running pre_rc... ###########  "
pre_rc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.raw ${n}_${fr}.rc - - - - - - - -
#pre_rc palsar_6460.par p22202_6460.slc.par 22202_6460.raw 22202_6460.rc - - - - - - - -

echo "########### running autof... ###########  "
autof palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.autof 2.5 - 4096 - 1024 1
#autof palsar_6460.par p22202_6460.slc.par 22202_6460.rc 22202_6460.autof 2.5 - 4096 - 1024 1

echo "########### running az_proc... ###########  "
az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12
#az_proc palsar_${fr}.par p${n}_${fr}.slc.par ${n}_${fr}.rc ${n}_${fr}.slc 16284 0 0 0 2.12

echo "########### running rasslc... ###########  "
rasSLC ${n}_${fr}.slc 4920 - - 2 6 - - -1 0 - ${n}_${fr}.bmp
