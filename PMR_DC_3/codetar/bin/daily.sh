#!/bin/bash

# Read Configuration and quit if not Master 
cd /data/scripts/PMR
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg
if [[ `am_i_master` -eq 0 ]] ; then exit 0; fi

# DC Version, Patches.
${BASEPATH}/DC/getDCVersion.sh | ${BASEPATH}/bin/pmfile_writer.sh 01d

# DC daily KPI Scripts. - stands N/A, as we keep 12 hours of IPfix & PilotP and 18 hours of SubIBs.
# ${BASEPATH}/DC/getDCBinStats.sh | ${BASEPATH}/bin/pmfile_writer.sh 01d


exit 0
