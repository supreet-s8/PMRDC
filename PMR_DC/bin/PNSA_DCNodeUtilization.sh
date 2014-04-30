#!/bin/bash

# Wrapper for PNSA_DC Node Utilization script 5 minute interval

# Read Configuration and quit if not standby
. /data/scripts/PMR/PNSA/etc/PMRConfig.cfg

export BASEPATH DATAPATH CLI SSH HOSTNAME SKIPCLLI
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

write_log "Starting PNSA_DC Node utilization check"

CLLI=`hostname | sed -e 's/NSA-A.*//g'`

export DATE AWK SADF CLLI VERSION LOGFILE
$BASEPATH/PNSA_DC/getPNSA_DCNodeUtilization.pl | $BASEPATH/bin/pmfile_writer.sh 05m $CLLI

write_log "Completed PNSA_DC Node utilization Check"

exit 0
