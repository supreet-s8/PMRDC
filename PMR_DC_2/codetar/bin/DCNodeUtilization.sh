#!/bin/bash

# Wrapper for DC Node Utilization script 5 minute interval

# Read Configuration and quit if not standby
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg

export BASEPATH DATAPATH CLI SSH HOSTNAME SKIPCLLI
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

write_log "Starting DC Node utilization check"

CLLI=`hostname | awk -F- '{print $1}' | sed -e 's/NSA$//'`

export DATE AWK SADF CLLI VERSION LOGFILE
$BASEPATH/DC/getDCNodeUtilization.pl | $BASEPATH/bin/pmfile_writer.sh 05m $CLLI

write_log "Completed DC Node utilization Check"

exit 0
