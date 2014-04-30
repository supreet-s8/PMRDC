#!/bin/bash

# Wrapper for DC Node Version script  1 day interval

# Read Configuration and quit if not standby
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg

export BASEPATH DATAPATH CLI SSH HOSTNAME SKIPCLLI PMX
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

write_log "Starting DC Node version checks"

CLLI=`hostname | awk -F- '{print $1}' | sed -e 's/NSA$//'`

export DATE AWK SADF CLLI VERSION LOGFILE
$BASEPATH/DC/getDCNodeVersion.pl | $BASEPATH/bin/pmfile_writer.sh 24h $CLLI

write_log "Completed DC Node Version Checks"

exit 0
