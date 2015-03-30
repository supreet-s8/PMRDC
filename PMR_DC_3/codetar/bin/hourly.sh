#!/bin/bash

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg
if [[ `am_i_master` -eq 0 ]] ; then exit 0; fi

# Running every hour, calculating 5 minute stats. Was already running at 55th minute in V1. Now 59th minute.
${BASEPATH}/DC/getCollectorStats-5min.sh | ${BASEPATH}/bin/pmfile_writer.sh 05m 60
# FD Utilization 
${BASEPATH}/DC/getFDUtilization.sh | ${BASEPATH}/bin/pmfile_writer.sh 1h 60
# DC Nodes Utilization - V1. Was running at 57th minute to cover
${BASEPATH}/DC/getDCNodeUtilization.sh | ${BASEPATH}/bin/pmfile_writer.sh 05m
# DC SubIB Processing Status. Running at 59th minute.
${BASEPATH}/DC/getProcessingStatus.sh | ${BASEPATH}/bin/pmfile_writer.sh 1h 60
# Collect Ipfix/Pilot records volume. Running at 59th minute of current hour, calculating for last full hour.
${BASEPATH}/DC/getVolumeStats.sh | ${BASEPATH}/bin/pmfile_writer.sh 01h 60

exit 0
