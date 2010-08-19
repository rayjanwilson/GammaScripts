#!/bin/bash

#try to get the enter thing working

legacy_SLC_processor=$1;
ldrname=$2;

echo -e \\n | $legacy_SLC_processor -c -d $ldrname
