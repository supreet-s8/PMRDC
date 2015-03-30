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

write_log "Starting connectivity test between standby namenode and SAP management nodes."

# IPFIX
for i in $REMOTEHOST $SAPNODES; do

/bin/ping -c 5 $i 2>/dev/null | grep "packets transmitted" | awk -F ',' '{print $(NF-1)}' | sed 's/ //g' | awk -F '%' -v "entity=$ENTITY" -v "stamp=$TIMESTAMP" -v "target=$i" '{printf "%s,%s,,Connectivity_status,%s|%d\n", stamp, entity, target, 100-$1}'

done

write_log "Completed network connectivity test."
exit 0
