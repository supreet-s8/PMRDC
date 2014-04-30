#!/bin/bash

# Wrapper for PNSA_DC Node status script 15 minute interval

# Read Configuration and quit if not standby 
. /data/scripts/PMR/PNSA/etc/PMRConfig.cfg

HOSTNAME=`hostname`

export CLI SSH BASEPATH DATAPATH HOSTNAME SKIPCLLI
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

write_log "Starting PNSA_DC Node status check"

CLLI=`hostname | sed -e 's/NSA-A.*//g'`

export PMX NAMENODE SECONDARYNN DATANODE JOBTRACKER CATALINA TASKTRACKER HOSTNAME CLIRAW DATE HADOOP COLLECTOR S_NAMENODE S_DATANODE S_SECONDARYNN S_JOBTRACKER S_CATALINA CLLI VERSION LOGFILE
$BASEPATH/PNSA_DC/getPNSA_DCNodesStatus.pl | $BASEPATH/bin/pmfile_writer.sh 15m $CLLI

write_log "Completed PNSA_DC Node status Check"

exit 0
