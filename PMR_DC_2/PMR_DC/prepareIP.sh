#!/bin/bash

function identifyClients {
mount -o remount,rw / 2>/dev/null
PREFIX=''; PREFIX=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | awk -F. '{print $1"."$2"."$3"."}' | sort -u`
CLIENTS=''; CLIENTS=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | awk -F. '{print $4}' | sort -r`

col=''
for i in $CLIENTS; do
   if [[ $col ]]; then
   col="$i $col"
   else 
   col="${i}"
   fi
done

cnp=''; cnp=`echo "$col" | awk '{print $1 " " $2}'`
col1=''; col1=`echo "$col" | awk '{if ( $1 != "" || $2 != "" ) print $1" "$2; fi}'`
col2=''; col2=`echo "$col" | awk '{if ( $3 != "" || $4 != "" ) print $3" "$4; fi}'`

#>IP.sh
echo "prefix=\"$PREFIX\"" >> IP.sh
echo "col=\"$col\"" >> IP.sh
echo "cnp=\"$cnp\"" >> IP.sh
echo "col1=\"$col1\"" >> IP.sh
if [[ $col2 ]]; then
echo "col2=\"$col2\"" >> IP.sh
fi 
}

function identifyComputes {
SLAVES=''
SLAVES=`/opt/tps/bin/pmx.py show hadoop | egrep "slave" | awk '{print $NF}' | awk -F. '{print $4}' | sort -r`
map=''
for i in $SLAVES; do
   if [[ $map ]]; then
   map="$i $map"
   else
   map="${i}"
   fi
done
echo "map=\"$map\"" >> IP.sh
echo "cmp=\"$map\"" >> IP.sh
}


function identifyVIPs {
MASTER=''
MASTER=`/opt/tms/bin/cli -t 'en' 'sho clus global' | grep -A2 master | grep address | awk {'print $4'} | sed -e 's/\,//' | awk -F. '{print $4}'`
if [[ ${MASTER} == '' ]]; then ${MASTER}="3"; fi
if [[ $cnp ]]; then echo "cnp0=\"${MASTER}\"" >> IP.sh; fi
if [[ $cnp ]]; then echo "col0=\"${MASTER}\"" >> IP.sh; fi
if [[ $col1 ]]; then echo "col10=\"${MASTER}\"" >> IP.sh; fi
if [[ $col2 ]]; then echo "col20=\"4\"" >> IP.sh; fi
}

#-------------------------#
identifyClients
identifyComputes
identifyVIPs
#-------------------------#

