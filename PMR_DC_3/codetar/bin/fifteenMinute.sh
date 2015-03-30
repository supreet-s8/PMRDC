#!/bin/bash

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg
if [[ `am_i_master` -eq 0 ]] ; then exit 0; fi

# DC Node Status.
${BASEPATH}/DC/getDCNodesStatus.sh | ${BASEPATH}/bin/pmfile_writer.sh 15m
# DC to SAP connectivity. 
${BASEPATH}/DC/getConnectivityStatus.sh | ${BASEPATH}/bin/pmfile_writer.sh 15m 60

exit 0
