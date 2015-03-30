#!/bin/bash

# Fetch SAR data for CPU and Memory utilization for the current hour at 5 minute interval

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

write_log "Starting Poller for detailed CPU & Mem Utilization and Disk IO stats"

# Poll ALL nodes in DC for detailed CPU and Memory Stats
# ---------------------

for element in $CNP $CMP
do

  hostn='';hostn=`/bin/grep -w "$NETWORK.${element}" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.${element} "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.${element}"; fi

  # Detailed CPU and Memory stats.

  val1='';val1=`${SSH} ${NETWORK}.${element} "/usr/bin/free -o 2>/dev/null | tail -n+2 | egrep ^'Mem' 2>/dev/null; /usr/bin/free -o 2>/dev/null | tail -n+2 | egrep ^'Swap' 2>/dev/null; echo -n 'CPU:'; /usr/bin/iostat -c 2>/dev/null | egrep -A1 avg-cpu 2>/dev/null | tail -1;  echo -e '\n'" 2>/dev/null`
  bk=$IFS; IFS="`echo ''`";

  if [[ $val1 ]]; then
  echo $val1 | egrep ^'Mem' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_total,%d\n", stamp, en, host, $2}'
  echo $val1 | egrep ^'Mem' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_free,%d\n", stamp, en, host, $4}'
  echo $val1 | egrep ^'Mem' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_share,%d\n", stamp, en, host, $5}'
  echo $val1 | egrep ^'Mem' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_buffer,%d\n", stamp, en, host, $6}'
  echo $val1 | egrep ^'Mem' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_cache,%d\n", stamp, en, host, $7}'
  echo $val1 | egrep ^'Swap' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,Memory_swap,%d\n", stamp, en, host, $3}'
  echo $val1 | egrep ^'CPU' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,CPU_user_percentage,%.2f\n", stamp, en, host, $2}'
  echo $val1 | egrep ^'CPU' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,CPU_nice_percentage,%.2f\n", stamp, en, host, $3}'
  echo $val1 | egrep ^'CPU' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,CPU_system_percentage,%.2f\n", stamp, en, host, $4}'
  echo $val1 | egrep ^'CPU' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,CPU_wait_percentage,%.2f\n", stamp, en, host, $5}'
  echo $val1 | egrep ^'CPU' | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s,,CPU_idle_percentage,%.2f\n", stamp, en, host, $7}'
  else 
    write_log "----- Unable to calculate detailed CPU & Mem Utilization."
  fi
  
  # Disk IO operations stats.

  val1=''; val1=`/usr/bin/ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root ${NETWORK}.${element} "/usr/bin/iostat -x -d 1 1  2>/dev/null | tail -n+4 | sed 's/ +/ /g' 2>/dev/null" 2>/dev/null`
  if [[ $val1 ]];  then
  for line in $val1; do
    echo $line | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s/%s,,IO_read_req_per_second,%.2f\n", stamp, en, host, $1, $4}' 
    echo $line | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s/%s,,IO_write_req_per_second,%.2f\n", stamp, en, host, $1, $5}'
    echo $line | awk -v "host=$hostn" -v "stamp=$TIMESTAMP" -v "en=$ENTITY" '{printf "%s,%s/%s/%s,,IO_svctm,%.2f\n", stamp, en, host, $1, $11}'
  done
  else
    write_log "----- Unable to calculate Disk IO stats."
  fi
  IFS=$bk;

  # SNMP systemUptime and interface stats.
  snmpNames="/tmp/snmp-if-names.${element}"
  snmpValues="/tmp/snmp-if-values.${element}"

  /usr/bin/snmpwalk -c ${COMMUNITY} -v2c ${NETWORK}.${element} -m IF-MIB ifName -OQ 2>/dev/null | awk -F '.' '{print $NF}' | sed 's/ //g' 2>/dev/null >${snmpNames}
  if [[ -s $snmpNames && $? -eq '0' ]]; then

    #for COUNTERS in "IF-MIB::ifInOctets" "IF-MIB::ifInOctets" "IF-MIB::ifInOctets" "IF-MIB::ifInOctets"; do

    /usr/bin/snmpwalk -c ${COMMUNITY} -v2c ${NETWORK}.${element} -m IF-MIB -OQ 2>/dev/null | egrep 'ifHCInOctets|ifInErrors|ifInDiscards|ifHCOutOctets|ifOutErrors|ifOutDiscards' | grep -v "ifHCInOctets|ifInErrors|ifInDiscards|ifHCOutOctets|ifOutErrors|ifOutDiscards" | awk -F ':' '{print $NF}' | sed 's/ //g' 2>/dev/null >${snmpValues}

    for interface in `/bin/cat $snmpNames`; do
       ifId=''; ifId=`echo $interface | awk -F '=' '{print $1}'`; 
       ifName=''; ifName=`echo $interface | awk -F '=' '{print $2}'`
       for COUNTERS in `/bin/egrep "*\.${ifId}" ${snmpValues} 2>/dev/null`; do
         index='';index=`echo $COUNTERS | awk -F '.' '{print $1}' 2>/dev/null`;
         value='';value=`echo $COUNTERS | awk -F '=' '{print $NF}' 2>/dev/null`;
         echo "$TIMESTAMP,${ENTITY}/$hostn/${ifName},,${index},${value}"
       done
    done

  else
    write_log "----- Unable to determine the host interface list." 
  fi
  /bin/rm -f ${snmpNames} ${snmpValues} 2>/dev/null

  # Poll System Uptime 
  value=`/usr/bin/snmpget -c ${COMMUNITY} -v2c ${NETWORK}.${element} hrSystemUptime.0 -Otv 2>/dev/null`
  if [[ $? -eq '0' ]]; then
  echo "$TIMESTAMP,${ENTITY}/$hostn,,hrSystemUptime,${value%??}"
  fi
done

# Compute CPU Util average.
write_log "----- Calculate compute CPU average."
count='0'; sum='0'
for element in $CMP 
do
  hostn='';hostn=`/bin/grep -w "$NETWORK.${element}" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.${element} "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.${element}"; fi

  # Detailed CPU.
  val1='';val1=`${SSH} ${NETWORK}.${element} "/usr/bin/iostat -c 2>/dev/null | egrep -A1 avg-cpu 2>/dev/null | tail -1 2>/dev/null" | awk '{print $6}' 2>/dev/null `

  if [[ $val1 ]]; then
  count=`echo "$count + 1" | bc`
  val1=`echo "scale=2;(100 - $val1)" | bc`
  sum=`echo "scale=2;($sum + $val1)" | bc`
  else
    write_log "----- Unable to calculate aggregated compute CPU for $hostn."
  fi

done

avg=`echo "scale=2;($sum/$count)" | bc 2>/dev/null`
printf "%s,%s,,Aggregated_compute_CPU_utilization,%.2f\n" "$TIMESTAMP" "$ENTITY" "$avg"

write_log "Completed Poller for detailed CPU & Mem Utilization and Disk IO stats"

# Calculate percentage map slots occupied.
#write_log "Calculating compute cluster load."
#ssh -q root@172.30.5.61 "/usr/bin/curl http://localhost:50030/jobtracker.jsp 2>/dev/null | grep -A1 'Occupied Map Slots'" 2>/dev/null >test
#cat test | awk -F '<th>' '{print $10}' | awk -F '</th>' '{print $1}'
#val=`cat test | awk -F '<td>' '{print $10}' | awk -F '</td>' '{print $1}' | grep ^[0-9]`; echo $val
#cat test | awk -F '<th>' '{print $11}' | awk -F '</th>' '{print $1}'
#cat test | awk -F '<td>' '{print $11}' | awk -F '</td>' '{print $1}' | grep ^[0-9]
#write_log "Done calculating compute cluster load."

exit 0
