#!/bin/bash

# -------------------------------------------------------------------------------------------------------
BASEPATH=/data/scripts/PMR/insertdcvalue

# Read main configuration file
source ${BASEPATH}/etc/PMRConfig.cfg

# Source variables in site.cfg
source ${BASEPATH}/DC/${ENTITY}/site.cfg

clone=`basename $0`
if [[ -f ${BASEPATH}/DC/${ENTITY}/$clone ]]; then
  ${BASEPATH}/DC/${ENTITY}/$clone
  exit 0
fi

# -------------------------------------------------------------------------------------------------------

TIMESTAMP=`date "+%Y%m%d-%H%M"`

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

#ENTITY='SAP'

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -ls "

# Software Version and patches.
write_log "Starting software patches, version collection, Configured FD Limit."
for node in $CNP $CMP; do
  #-----
  hostn='';hostn=`/bin/grep -w "$NETWORK.$node" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$node "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.$node"; fi
  #-----

  #----- version
  val='';
  val=`$SSH $NETWORK.$node "${CLI} 'show version' 2>/dev/null | grep 'Product release'" 2>/dev/null | $AWK '{print $NF}' | sed 's/ //g'`
    if [[ $val && $? -eq '0' ]]; then
     echo "$TIMESTAMP,${ENTITY}/$hostn,,SW_version,${val:0:50}"
    else
     echo "$TIMESTAMP,${ENTITY}/$hostn,,SW_version,${val:0:50}"
    fi

  #----- patch
  val='';
  patches=''
  val=`$SSH $NETWORK.$node "${PMX} subshell patch show all patches 2>/dev/null | egrep -vi 'Already|No' | sort | grep [^A-Za-z] | sed 's/ //g'" 2>/dev/null`
  if [[ $val && $? -eq '0' ]]; then 
  for pat in $val; do
    patches="$pat $patches"
  done
  fi
  echo "$TIMESTAMP,${ENTITY}/$hostn,,SW_patches,${patches:0:200}"

  #----- FD Limit Counter

  val='';
  patches=''
  val=`$SSH $NETWORK.$node "/bin/cat /proc/sys/fs/file-max" 2>/dev/null`
  if [[ $val && $? -eq '0' ]]; then
   echo "$TIMESTAMP,${ENTITY}/$hostn,,file_descriptors_max,$val"
  else
   echo "$TIMESTAMP,${ENTITY}/$hostn,,file_descriptors_max,0"
   write_log "----- Unable to calculate configured FD limit for node $hostn"
  fi


done 2>/dev/null

write_log "Completed software patches, version collection, Configured FD Limit."

exit 0

