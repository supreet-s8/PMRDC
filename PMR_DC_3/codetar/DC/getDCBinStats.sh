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

write_log "Calculating missing DC bins."

# Calculate missing bins. Once a day for 1 day ago.

y=`date -d "1 days ago" +%Y/%m/%d`
yMissedKpi=`date -d "1 days ago" +%Y%m%d`

# IPFIX Bins
write_log "----- IPFIX Bins"
maxBinsInDay='288'
#for dc in $cmdsDC; do
#  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
#  if [[ $str ]]; then dcClli=`echo $dc | sed $str`; else dcClli=$dc; fi
  for chassis in 1 2 3 4; do
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/output/pnsa/$chassis 2>/dev/null"` ]]; then
      #outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      outFile="/tmp/binList-ipfix-${chassis}"
      #$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis/ipfix/${y}/*/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      $SSH $STANDBY "$HDFSCMD /data/output/pnsa/$chassis/ipfix/${y}/*/*/*_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then 
         echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,SET"
      else 
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount. 
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/output/$chassis/pnsa/ipfix/${y}/$hour/$minute/*_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,$binList"
      fi
      /bin/rm -f $outFile 
    fi
  done
#done  


maxBinsInDay='288'
#for dc in $pnsaDC; do
  #str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  #if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 0; do
    ##Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    ##if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      #outFile="/tmp/binList-ipfix-${chassis}-${dc}"
      outFile="/tmp/binList-ipfix-${chassis}"
      $SSH $STANDBY "$HDFSCMD /data/output/pnsa/ipfix/${y}/*/*/*_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/output/pnsa/ipfix/${y}/$hour/$minute/*_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_IPFIX_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
#done 

# PILOTPACKET
write_log "----- RADIUS Bins"

maxBinsInDay='288'
#for dc in $cmdsDC; do
#  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
#  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 1 2 3 4; do
    # Skip if chassis does not exist.
    if [[ `$SSH $STANDBY "$HDFSCMD /data/output/pnsa/$chassis 2>/dev/null"` ]]; then
      #outFile="/tmp/binList-pilot-${chassis}-${dc}"
      outFile="/tmp/binList-pilot-${chassis}"
      $SSH $STANDBY "$HDFSCMD /data/output/pnsa/$chassis/pilotPacket/${y}/*/*/*_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'` 
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/output/pnsa/$chassis/pilotPacket/${y}/$hour/$minute/*_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,$binList"
      fi
      /bin/rm -f $outFile
    fi
  done
#done


maxBinsInDay='288'
#for dc in $pnsaDC; do
  #str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
  #if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 0; do
    ##Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    ##if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      #outFile="/tmp/binList-pilot-${chassis}-${dc}"
      outFile="/tmp/binList-pilot-${chassis}"
      $SSH $STANDBY "$HDFSCMD /data/output/pnsa/pilotPacket/${y}/*/*/*_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
	    for minute in `seq -w 00 05 55`; do
		if [[ `/bin/grep "/data/output/pnsa/pilotPacket/${y}/$hour/$minute/*_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:${minute}"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break 2; fi
	    done
	 done
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_PilotPacket_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
#done

# SUBSCRIBER IB 
write_log "----- SUBIB Bins"

maxBinsInDay='24'
#for dc in $allDC; do
#  str='';str=`/bin/grep $dc ${BASEPATH}/etc/nameCLLI.sed 2>/dev/null`
#  if [[ $str ]]; then dcClli=`echo $dc | sed $str`;  else dcClli=$dc; fi
  for chassis in 0; do
    #Skip if chassis does not exist.	- skipped as it is PNSA/VISP
    #if [[ `$SSH $STANDBY "$HDFSCMD /data/$dc/$chassis 2>/dev/null"` ]]; then
      #outFile="/tmp/binList-subib-${chassis}-${dc}"
      outFile="/tmp/binList-subib-${chassis}"
      $SSH $STANDBY "$HDFSCMD /data/output/SubscriberIB/${y}/*/_DONE 2>/dev/null" | awk '{print $NF}' >$outFile
      if [[ -s $outFile && $? -eq '0' ]]; then
         cmdsIpfixCount=`wc -l $outFile 2>/dev/null | awk '{print $1}' | sed 's/ //g'`
      else
	 cmdsIpfixCount='0';
      fi
      cmdsIpfixMissedBinCount='-1';cmdsIpfixMissedBinCount=`echo "$maxBinsInDay - $cmdsIpfixCount" | bc`
      echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bin_count,$cmdsIpfixMissedBinCount"
      # Practically, following condition will never meet. If the magic happens, keep the KPI value empty since it is a string.
      if [[ `echo "$cmdsIpfixMissedBinCount == -1" | bc` -eq '1' ]]; then
         echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bins,"
      elif [[ `echo "$cmdsIpfixMissedBinCount == $maxBinsInDay" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bins,ALL"
      elif [[ `echo "$cmdsIpfixMissedBinCount == 0" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bins,NONE"
      elif [[ `echo "$cmdsIpfixMissedBinCount > 12" | bc` -eq '1' ]]; then
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bins,SET"
      else
      # Iterate through all the bins in a day to find misng bins until the count of misng bins being recorded matches $cmdsIpfixMissedBinCount.
         binCount='0';binList='';
	 for hour in `seq -w 00 24`; do
		if [[ `/bin/grep "/data/output/SubscriberIB/${y}/$hour/_DONE" $outFile 2>/dev/null` ]]; then
		   continue
		else
		   missedBin='';missedBin="${yMissedKpi}-${hour}:00"
		   if [[ $binList ]]; then
			# PIPE separated, we can change to [][,][,] ... etc., here.
			binList="${binList}|${missedBin}"
		   else
			binList="${missedBin}"
		   fi
		   binCount=`expr $binCount + 1`
		fi
		if [[ $binCount -eq "$cmdsIpfixMissedBinCount" ]]; then break; fi
	 done
	 echo "$TIMESTAMP,${ENTITY}/$chassis,,DC_missing_SubscriberIB_bins,$binList"
      fi
      /bin/rm -f $outFile
    #fi
  done
#done 

write_log "Done calculating missing DC bins."

exit 0

