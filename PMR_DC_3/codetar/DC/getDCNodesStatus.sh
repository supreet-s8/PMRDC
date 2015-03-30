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

write_log "Starting DC Node status check"

DFSUSED='-1'

# Get Hadoop Status from Master Name node
SUBENTITY=`$SSH $NETWORK.$CNP0 'hostname'`
if [[ $? -eq '0' ]] 
then 
  # Ok to start  
  HADOOPSTATUS=0 
  # Get list of processes
  $SSH $NETWORK.$CNP0 'ps -ef' > $TMPFILE
  # Check Namenode process
  if ! egrep -q "org.apache.hadoop.hdfs.server.namenode.NameNode" $TMPFILE ; then let HADOOPSTATUS+=$NAMENODE ; fi
  # Check Datanode process
  if ! egrep -q "org.apache.hadoop.hdfs.server.datanode.DataNode" $TMPFILE ; then let HADOOPSTATUS+=$DATANODE ; fi
  # Check Jobtracker process
  if ! egrep -q "org.apache.hadoop.mapred.JobTracker" $TMPFILE ; then let HADOOPSTATUS+=$JOBTRACKER ; fi
  # Check oozie server process
  if ! egrep -q "org.apache.catalina.startup.Bootstrap start" $TMPFILE ; then let HADOOPSTATUS+=$CATALINA ; fi
  # HDFS Utilization
  $SSH $NETWORK.$CNP0 "$HADOOP dfsadmin -report" 2>/dev/null > $TMPFILE.dfsreport
  DFSUSED=`cat $TMPFILE.dfsreport | grep "DFS Used%" |head -1 | sed -e 's/DFS Used\%: //' | sed -e 's/\%//'`
else 
  HADOOPSTATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$CNP0 /etc/hosts | awk '{print $2}'`
fi

# Cleanup
rm -f $TMPFILE
rm -f $TMPFILE.dfsreport
# Write Data
printf "%s,%s,%s,Hadoop_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$HADOOPSTATUS" 
printf "%s,%s,%s,HDFS_utilization,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$DFSUSED" 

# Get Collector Status
for node in $CNP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  # Check Collector process
    $SSH $NETWORK.$node '/opt/tms/bin/cli -t "en" "show pm process collector"' > $TMPFILE
    if ! egrep -q "Current status:  running" $TMPFILE ; then let STATUS+=$COLLECTOR ; fi

  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write Data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done


# Get Compute Nodes status 
for node in $CMP ; do
  SUBENTITY=`$SSH $NETWORK.$node 'hostname'`
  if [[ $? -eq '0' ]] 
  then 
  STATUS=0
  $SSH $NETWORK.$node 'ps -ef' > $TMPFILE

  # Check Datanode and Tasktracker processes
    #if ! egrep -q "org.apache.hadoop.hdfs.server.datanode.DataNode" $TMPFILE ; then let STATUS+=$DATANODE ; fi
    if ! egrep -q "org.apache.hadoop.hdfs.server.datanode" $TMPFILE ; then let STATUS+=$DATANODE ; fi
    if ! egrep -q "org.apache.hadoop.mapred.TaskTracker" $TMPFILE ; then let STATUS+=$TASKTRACKER ; fi
  else 
  # Not reachable
  STATUS=1
  SUBENTITY=`/bin/grep $NETWORK.$node /etc/hosts | awk '{print $2}'`
  fi

  # Write Data
    printf "%s,%s,%s,Node_status,%s\n" "$TIMESTAMP" "$ENTITY" "$SUBENTITY" "$STATUS" 
  # Clean up
    rm -f $TMPFILE
done


# Clean up
  rm -f $TMPFILE

write_log "Completed DC Node status check"
write_log "Starting DC Nodes disk stats"

# Get Disk Stats - DC PMR V2
#-----
# Disk Monitoring
for node in $CNP $CMP; do
  #-----
  hostn='';hostn=`/bin/grep -w "$NETWORK.$node" /etc/hosts | awk '{print $2}' | sed 's/ //g'`
  if [[ ! ${hostn} ]]; then hostn=`$SSH $NETWORK.$node "hostname"`; fi
  if [[ ! ${hostn} ]]; then hostn="$NETWORK.$node"; fi
  #-----
  val='';
  for value in `$SSH $NETWORK.$node "/bin/df -P | tail -n+3 | tr -s ' ' | sed 's/%//g'" | awk '{print $6";"$2*1024";"$5}'`; do
     #disk='';disk=`echo $value | awk -F ";" '{print $1}' | sed 's/\//_/g'`
     disk='';disk=`echo $value | awk -F ";" '{print $1}'`
     valSize=`echo $value | awk -F ";" '{print $2}'`
     val=`echo $value | awk -F ";" '{print $3}'`
    if [[ $val && $disk && $valSize ]]; then
     echo "$TIMESTAMP,$ENTITY/$hostn://$disk,,Disk_partition_size,$valSize"
     echo "$TIMESTAMP,$ENTITY/$hostn://$disk,,Disk_partition_utilization,$val"
    else
     echo "$TIMESTAMP,$ENTITY/$hostn://$disk,,Disk_partition_size,0"
     echo "$TIMESTAMP,$ENTITY/$hostn://$disk,,Disk_partition_utilization,0"
    fi
  done 2>/dev/null
done 2>/dev/null

write_log "Completed DC Nodes disk stats"
exit 0

