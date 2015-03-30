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

TMPFILE=/tmp/pmr_tmp_$TIMESTAMP

#ENTITY='SAP'

write_log "Starting ByteVolumeCounters"

STANDBY=`$SSH $NETWORK.$CNP0 "$CLI 'show cluster standby'" | grep internal | awk '{print $4}' | sed 's/,//g'`
if [[ -z ${STANDBY} ]] ; then write_log "Could not determine standby namenode, exiting"; exit 127 ; fi

HDFSCMD="$HADOOP dfs -ls "

# FILE SIZE STATS
#myda=`date "+%d" --date="1 days ago"`;
#mymo=`date "+%m" --date="1 days ago"`;
#myyr=`date "+%Y" --date="1 days ago"`;

myda=`date "+%d" --date="1 hour ago"`;
mymo=`date "+%m" --date="1 hour ago"`;
myyr=`date "+%Y" --date="1 hour ago"`;
myhr=`date "+%H" --date="1 hour ago"`;

# IPFIX
write_log "  -- IPFIX Records"
val1='0';val1=`$SSH $STANDBY "$HDFSCMD /data/output/pnsa/ipfix/$myyr/$mymo/$myda/$myhr/*/*IPFIX*.? 2>/dev/null" | awk 'BEGIN {SUM=0} {SUM += $5} END {printf "%s\n", SUM}'`
val2='0';val2=`$SSH $STANDBY "$HDFSCMD /data/output/pnsa/{1,2,3,4}/ipfix/$myyr/$mymo/$myda/$myhr/*/*IPFIX*.? 2>/dev/null" | awk 'BEGIN {SUM=0} {SUM += $5} END {printf "%s\n", SUM}'`
totalIpfix='0';totalIpfix=`echo "$val1 + $val2" | bc`

echo "$TIMESTAMP,$ENTITY,,IPFIX_DC_volume,$totalIpfix"

# PILOTPACKET
write_log "  -- RADIUS Records"
val1='0';val1=`$SSH $STANDBY "$HDFSCMD /data/output/pnsa/pilotPacket/$myyr/$mymo/$myda/$myhr/*/*RADIUS*.? 2>/dev/null" | awk 'BEGIN {SUM=0} {SUM += $5} END {printf "%s\n", SUM}'`
val2='0';val2=`$SSH $STANDBY "$HDFSCMD /data/output/pnsa/{1,2,3,4}/pilotPacket/$myyr/$mymo/$myda/$myhr/*/*RADIUS*.? 2>/dev/null" | awk 'BEGIN {SUM=0} {SUM += $5} END {printf "%s\n", SUM}'`
totalPilot='0';totalPilot=`echo "$val1 + $val2" | bc`

echo "$TIMESTAMP,$ENTITY,,PilotPacket_DC_volume,$totalPilot"

# SUBSCRIBER IB
write_log "  -- SUBIB Records"
val1='0';val1=`$SSH $STANDBY "$HDFSCMD /data/output/SubscriberIB/$myyr/$mymo/$myda/$myhr/*MAPREDUCE* 2>/dev/null" | awk 'BEGIN {SUM=0} {SUM += $5} END {printf "%s\n", SUM}'`

echo "$TIMESTAMP,$ENTITY,,SubscriberIB_DC_volume,$val1"

write_log "Done getting Volume Stats"

exit 0

