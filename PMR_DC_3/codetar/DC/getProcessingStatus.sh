#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR/insertdcvalue

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Read Site Configuration file
source ${BASEPATH}/DC/${ENTITY}/site.cfg

clone=`basename $0`
if [[ -f ${BASEPATH}/DC/${ENTITY}/$clone ]]; then
  ${BASEPATH}/DC/${ENTITY}/$clone
  exit 0
fi

# -------------------------------------------------------------------------------------------------------

# To be run at hour boundary or 1 minute befoe the hour boundary.
# hadoop dfs -cat /data/PnsaSubscriberIb/done.txt 2>/dev/null
# 2015-01-30T00:00Z
# Shift validation hour as this script will be run at every 59th minute of hour (say 19:59), hence we expect subib job to get completed by this time upto this hour.i.e. done.txt should read 19:00.
#valid=`date -d "1 hour ago" "+%Y-%m-%dT%H:00Z"`
valid=`date "+%Y-%m-%dT%H:00Z"`
TIMESTAMP=`date "+%Y%m%d-%H%M"`

# We 'll check if Subib bin for 19th hour has formed or not yet.
#myda=`date "+%d" --date="1 hour ago"`;
#mymo=`date "+%m" --date="1 hour ago"`;
#myyr=`date "+%Y" --date="1 hour ago"`;
#myhr=`date "+%H" --date="1 hour ago"`;
myda=`date "+%d"`;
mymo=`date "+%m"`;
myyr=`date "+%Y"`;
myhr=`date "+%H"`;

write_log "Starting subscriberib processing status."

KPISTATUS='0'

# Verify job done.
val1=''; val1=`$SSH $NETWORK.$CNP0 "/opt/hadoop/bin/hadoop dfs -cat /data/PnsaSubscriberIb/done.txt 2>/dev/null"`
#val1=''; val1=`/opt/hadoop/bin/hadoop dfs -cat /data/PnsaSubscriberIb/done.txt 2>/dev/null`
if [[ $? -eq '0' && $val1 ]]; then
  if [[ "${val1}" != "${valid}" ]]; then
     KPISTATUS=`echo "$KPISTATUS + 1" | bc` 
  fi
else
     KPISTATUS=`echo "$KPISTATUS + 1" | bc`  
fi

# Verify subscriberib job output.
val2=''; val2=`$SSH $NETWORK.$CNP0 "/opt/hadoop/bin/hadoop dfs -ls /data/output/SubscriberIB/$myyr/$mymo/$myda/$myhr/_DONE 2>/dev/null"`
#val2=''; val2=`/opt/hadoop/bin/hadoop dfs -ls /data/output/SubscriberIB/$myyr/$mymo/$myda/$myhr/_DONE 2>/dev/null`
if [[ $? -ne '0' ]]; then 
   KPISTATUS=`echo "$KPISTATUS + 2" | bc`
fi

echo "$TIMESTAMP,$ENTITY,,Processing_status,$KPISTATUS"

write_log "Completed processing status check."
exit 0
