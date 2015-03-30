#!/bin/bash
# -----------------------------------------------------------------------------------------------------
ENVF="/data/scripts/PMR/insertdcvalue/etc/PMRConfig.cfg"
if [[ -s $ENVF ]]; then
  source $ENVF 2>/dev/null
  if [[ $? -ne '0' ]]; then echo "Unable to load the environment file. Committing Exit!!!"; exit 127; fi
else
  echo "Unable to locate the environment file: $ENVF"; exit 127
fi
mount -o remount,rw / 2>/dev/null
# -----------------------------------------------------------------------------------------------------
CLI="/opt/tms/bin/cli -t 'en' 'conf t'"

function identifyClients {
PREFIX=''; PREFIX=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | sed 's/ //g' | awk -F. '{print $1"."$2"."$3}' | sort -u`
CLIENTS=''; CLIENTS=`/opt/tps/bin/pmx.py show hadoop | egrep "client" | awk '{print $NF}' | sed 's/ //g' | awk -F. '{print $4}' | sort -ru`

col=''
# Parent Control Statement.
if [[ $CLIENTS ]]; then
for i in $CLIENTS; do
   if [[ $col ]]; then
   col="$i $col"
   else
   col="${i}"
   fi
done

# Check cluster enabled or not #
enabled=''; enabled=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep 'Cluster enabled' | awk -F ':' '{print $NF}' | sed 's/ //g'`

if [[ "${enabled}" == 'yes' ]]; then  
   col11=''; col11=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster global brief' | grep ^[0-9] | grep master | awk -F "." '{print $NF}'` | sed 's/ //g'
   col12=''; col12=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster global brief' | grep ^[0-9] | grep standby | awk -F "." '{print $NF}'` | sed 's/ //g'
   cnp=''; col1=''; 

   if [[ $col11 && $col12 ]]; then 
      cnp="$col11 $col12"; col1="$col11 $col12"; 
      for i in $col; do
         if [[ "${i}" == "${col11}" || "${i}" == "${col12}" ]]; then continue; 
         elif [[ $col2 ]]; then
            col2="$col2 $i"
         else
            col2="${i}"
         fi
      done
   else 
      cnp=''; col1='';
      cnp="$col"; col1="$col";
   fi

else
   cnp=''; col1='';
   cnp="$col"; col1="$col"; 
fi

>${IP}
echo "ENTITY=\"${ENTITY}\"" >> ${IP} 
if [[ $SITENAME ]]; then echo "SITENAME=\"${SITENAME}\"" >> ${IP}; else echo "SITENAME=\'\'" >> ${IP}; fi
echo "NETWORK=\"$PREFIX\"" >> ${IP}
echo "COL=\"$col\"" >> ${IP}
echo "CNP=\"$cnp\"" >> ${IP}
echo "COL1=\"$col1\"" >> ${IP}
if [[ $col2 ]]; then
echo "COL2=\"$col2\"" >> ${IP}
fi

else
   exit 0
fi
}

function identifyComputes {
SLAVES=''
SLAVES=`/opt/tps/bin/pmx.py show hadoop | egrep "slave" | awk '{print $NF}' | awk -F. '{print $4}' | sort -ru`
map=''
# Parent Control Statement.
if [[ $SLAVES ]]; then
for i in $SLAVES; do
   if [[ $map ]]; then
   map="$i $map"
   else
   map="${i}"
   fi
done
echo "MAP=\"$map\"" >> ${IP}
echo "CMP=\"$map\"" >> ${IP}
else 
   exit 0
fi
}


function identifyVIPs {

# Check cluster enabled or not #
enabled=''; enabled=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep 'Cluster enabled' | awk -F ':' '{print $NF}' | sed 's/ //g'`

if [[ "${enabled}" == 'yes' ]]; then
   cnp0vip='';cnp0vip=`/opt/tms/bin/cli -t 'en' 'conf t' 'show cluster configured' | grep "master virtual IP address" | awk '{print $NF}' | awk -F/ '{print $1}'`
   cnp0='';cnp0=`/opt/tms/bin/cli -t 'en' 'sho clus global' | grep -A2 master | grep address | awk {'print $4'} | sed -e 's/\,//' | awk -F. '{print $4}'`
else
   cnp0vip=''
   count=0
   for i in $col; do
	cnp0vip="${PREFIX}.${i}"
	cnp0="${i}"
        count=`expr $count + 1`
	if [[ $count -eq '1' ]]; then break; fi
   done
fi

if [[ $cnp0vip ]]; then echo "CNP0VIP=\"${cnp0vip}\"" >> ${IP}; fi
if [[ $cnp0 ]]; then echo "CNP0=\"$cnp0\"" >> ${IP}; fi
}

function identifyBkpDir {
COLBKPDIR='';COLBKPDIR=`${CLI} "show run full" | grep collector | grep backup-directory | awk '{print $NF}'`
if [[ $COLBKPDIR ]]; then echo "COLBKPDIR=\"${COLBKPDIR}\"" >> ${IP}; else echo "COLBKPDIR=\"/data/collector/edrAsn_backup\"" >> ${IP}; fi
}

function identifySiteName {
SITENAME='';SITENAME=`/opt/tms/bin/cli -t 'en' 'conf t' 'show run full' | grep "collector" | grep "output-directory" | head -1 | awk -F "/" '{print $NF}' | awk -F "." '{print $1}' 2>/dev/null`
ENTITY=''; ENTITY=`hostname | awk -F- '{print $1}' | sed -e 's/NSA$//' 2>/dev/null`
}

function identifyAdaptors {
ADAPTORS='';LIST='';LIST=`/opt/tms/bin/cli -t 'en' 'internal query iterate subtree /nr/collector/instance/1/adaptor' | awk -F/ '{print $7"\n"}' | awk '{print $1}' | sort -u`

for i in ${LIST}; do
   if [[ $ADAPTORS ]]; then
   ADAPTORS="$i $ADAPTORS"
   else
   ADAPTORS="${i}"
   fi
done
if [[ $ADAPTORS ]]; then echo "ADAPTORS=\"${ADAPTORS}\"" >> ${IP}; else echo "ADAPTORS=\"edrAsn\"" >> ${IP}; fi

}

#-------------------------#
identifySiteName

if [[ $ENTITY ]]; then 
   IP="${BASEPATH}/DC/${ENTITY}/site.cfg"
else 
   exit 0
fi

identifyClients
identifyComputes
identifyVIPs
#identifyBkpDir
identifyAdaptors
#-------------------------#
