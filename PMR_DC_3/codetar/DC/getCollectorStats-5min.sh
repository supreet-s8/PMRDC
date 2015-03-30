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


TIMESTAMP=`date "+%Y%m%d-%H%M"`

H=`date -d "1 hours ago" +"%Y/%m/%d %H"`

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

#ENTITY='SAP'

write_log "Starting Collector Stats Collection."

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

MASTER=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster master'" 2>/dev/null | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${MASTER} ]] ; then write_log "Could not determine master namenode, exiting"; exit 127 ; fi

hostn='';hostn=`/bin/grep -w "$MASTER" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$CNP0 "hostname"`; fi
if [[ ! ${hostn} ]]; then hostn="$MASTER"; fi

NNVIP="$NETWORK.$CNP0"
HDFSCMD="$HADOOP dfs -ls "

# -------------------------------------------------------------------------------------------------------


ADAPTORS_NN=''; ADAPTORS_NN=`$SSH $STANDBY "/opt/tms/bin/cli -t 'en' 'internal query iterate subtree /nr/collector/instance/1/adaptor'" 2>/dev/null | awk -F/ '{print $7"\n"}' | awk '{print $1}' | sort -u`

for ADAPTOR in ${ADAPTORS_NN}; do

# --------- Collector Stats Dropped Flow, hourly.
  stamp=''
  for collectorStatsDroppedFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR dropped-flow interval-type 5-min interval-count 12' 2>/dev/null | grep -v ^[A-Z] " 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null` ; do
  ds1='';ds1=`echo "$collectorStatsDroppedFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds1 ]]; then
    stamp=`date -d "$ds1" "+%Y%m%d-%H%M"`
  else 
    stamp=$TIMESTAMP
  fi
  collectorStatsDroppedFlow=`echo "$collectorStatsDroppedFlow" | awk -F '_'  '{print $NF}'`

  if [[ $collectorStatsDroppedFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,$collectorStatsDroppedFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
  fi
  done 2>/dev/null

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_dropped_record_data_volume,0"
    done
  fi

# --------- Collector Stats Total Flow, hourly.

  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR total-flow interval-type 5-min interval-count 12' 2>/dev/null | grep -v ^[A-Z]" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_record_data_volume,0"
    done
  fi

# --------- Collector Stats Files Processed, hourly.

   stamp=''
   for collectorStatsTotalFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-processed interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,0"
    write_log "Unable to calculate num-files-processed for $ADAPTOR"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_processed,0"
    done
  fi

# --------- Collector Stats Files Dropped, hourly.


  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-dropped interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,0"
    write_log "Unable to calculate num-files-dropped for $ADAPTOR"
  fi
  done
 
  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_dropped,0"
    done
  fi

# --------- Collector Stats Files With Errors, hourly.

  stamp=''
  for collectorStatsTotalFlow in `$SSH $NETWORK.$CNP0 "${CLI} 'collector stats instance-id 1 adaptor-stats $ADAPTOR num-files-with-errors interval-type 5-min interval-count 12' 2>/dev/null | /bin/grep -v ^[A-Z] 2>/dev/null" 2>/dev/null | awk '{print $2"_"$3"_"$NF}' 2>/dev/null`; do

  ds2='';ds2=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $1" "$2}'`
  if [[ $ds2 ]]; then
    stamp=`date -d "$ds2" "+%Y%m%d-%H%M"`
  else
    stamp=$TIMESTAMP
  fi
  collectorStatsTotalFlow=`echo "$collectorStatsTotalFlow" | awk -F '_' '{print $NF}'`
  if [[ $collectorStatsTotalFlow ]]; then
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,$collectorStatsTotalFlow"
  else
    echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,0"
    write_log "Unable to calculate num-files-with-errors for $ADAPTOR"
  fi
  done

  if [[ ! $stamp ]]; then
    epo=`date -d "1 hour ago" +"%s"`; epo=`echo "$epo - \`echo \"$epo % 300\" | bc \`" | bc`
    for i in `seq 0 300 3300`; do
      stamp=`echo "$epo + $i" | bc`
      stamp=`date -d \@${stamp} +%Y%m%d-%H%M`
      echo "$stamp,$ENTITY/${hostn},,${ADAPTOR}_files_with_errors,0"
   done
  fi

done

write_log "Completed calculating collector stats."

exit 0

