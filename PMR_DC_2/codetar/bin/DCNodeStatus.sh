#!/bin/bash

# Wrapper for DC Node status script 15 minute interval

# Read Configuration and quit if not standby 
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg

HOSTNAME=`hostname`

export CLI SSH BASEPATH DATAPATH HOSTNAME SKIPCLLI
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

write_log "Starting DC Node status check"

CLLI=`hostname | awk -F- '{print $1}' | sed -e 's/NSA$//'`

export PMX NAMENODE SECONDARYNN DATANODE JOBTRACKER CATALINA TASKTRACKER HOSTNAME CLIRAW DATE HADOOP COLLECTOR S_NAMENODE S_DATANODE S_SECONDARYNN S_JOBTRACKER S_CATALINA CLLI VERSION LOGFILE
$BASEPATH/DC/getDCNodesStatus.pl | $BASEPATH/bin/pmfile_writer.sh 15m $CLLI

write_log "Completed DC Node status Check"

exit 0
