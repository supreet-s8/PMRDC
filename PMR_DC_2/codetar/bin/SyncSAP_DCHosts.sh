#!/bin/bash

# Read Configuration and quit if not standby
. /data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg

HOSTNAME=`hostname`

export CLI SSH BASEPATH DATAPATH
#if [[ `$BASEPATH/bin/checkStandby.pl` -ne 0 ]] ; then exit 0; fi

for iREMOTEHOST in $REMOTEHOST
do
  write_log "Syncing scripts from $iREMOTEHOST to $HOSTNAME"
  OUT="`$RSYNC -v $RSYNCOPT $RSYNCEXCLUDEPMR --delete root@${iREMOTEHOST}:$SAPSCRIPTPATH/ $BASEPATH/ 2>&1`"
  if [[ $? -eq 0 ]] ;
  then
    write_log "`echo $OUT | perl -e 'print $1 if(<> =~ /.*law enforcement officials\. (.*)/);'`";
    write_log "Sync Complete";
    exit 0

  else
    write_log "Sync failed" ;
  fi
done

