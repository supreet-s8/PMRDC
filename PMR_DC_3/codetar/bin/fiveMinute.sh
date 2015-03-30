#!/bin/bash

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg
if [[ `am_i_master` -eq 0 ]] ; then exit 0; fi

# Calculating 5 minute system stats.
${BASEPATH}/DC/getSystemsUtilization.sh | ${BASEPATH}/bin/pmfile_writer.sh 05m 60

exit 0
