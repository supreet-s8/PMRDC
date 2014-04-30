#!/bin/bash

# Read Configuration and quit if not standby
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg

HOSTNAME=`hostname`

export CLI SSH BASEPATH DATAPATH HOSTNAME SKIPCLLI
if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

# Since all DC sites will start rsync at the same time, we randomly sleep from 1 to 240 secs.
# So that there is some random distribution of rsync event.
`perl -e 'sleep(int(rand(240)));'`

for iREMOTEHOST in $REMOTEHOST
do
  write_log "Syncing from $HOSTNAME to $iREMOTEHOST"
  OUT="`$RSYNC -v $RSYNCOPT $DATAPATH/${CLLI} root@${iREMOTEHOST}:$REMOTEDATAPATH/ 2>&1`"
  if [[ $? -eq 0 ]] ;
  then
    write_log "`echo $OUT | perl -e 'print $1 if(<> =~ /.*law enforcement officials\. (.*)/);'`";
    write_log "Sync Complete";
    exit 0

  else
    write_log "Sync failed" ;
  fi
done
