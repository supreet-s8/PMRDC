#!/bin/bash

source IP.sh
if [[ $? -ne 0 ]]
  then
    printf "Unable to read source for IP Address List\nCannot continue.\n"
    exit 255
fi
SSH='ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -l root '
DC=${1}

#===========
INSTALLPATH="/data/scripts/PMR/${DC}"
CLLI=`hostname | awk -F- '{print $1}' | sed -e 's/NSA$//'`
TOOL="pmr-code-v06.tar.gz"
SOURCE="/tmp/PMR_DC"
DEST="/tmp"
REMOTESANREPO="/data/mgmt/pmr/scripts/pm/${DC}"
#===========

function usage {
	echo -e "\nUsage Example : $0 VISP\n"
	echo -e "Use following arguments - PNSA, VISP or CMDS\n"

}

function identifyNN {
	echo "---Calibrating Namenode IPs"
	NN=`/opt/tps/bin/pmx.py show hadoop | grep -i client | awk '{print $NF}'`

}

function issueCommands {
	echo "---Installing PMR"
	for host in ${NN}; do
	   ${SSH} $host '/bin/mount -o remount,rw /'
           #${SSH} $host "/bin/rm -rf ${SOURCE}/PMR_DC"
	   ${SSH} $host "/bin/mkdir -p ${INSTALLPATH}/var"
	   /usr/bin/scp -q ${SOURCE}/${TOOL} root@${host}:${DEST}
	   ${SSH} $host "/bin/tar zxvf ${DEST}/${TOOL} -C ${INSTALLPATH}" 1>/dev/null
	   ${SSH} $host "/bin/chmod -R 755 ${INSTALLPATH}/*"
	done

}

function createSAN {
	echo "---Creating SAN Repository"
	for mgt in ${mgmt0}; do 
	   echo "---Transferring toolset to management node : ${prefix1}${mgt}"
	   ${SSH} ${prefix1}${mgt} "/bin/mount -o remount,rw /"
	   /usr/bin/scp -q ${SOURCE}/${TOOL} root@${prefix1}${mgt}:${DEST}
	   ${SSH} ${prefix1}${mgt} "/bin/mkdir -p ${REMOTESANREPO}/DC/${CLLI}/"
	   ${SSH} ${prefix1}${mgt} "/bin/tar zxvf ${DEST}/${TOOL} -C ${REMOTESANREPO}" 1>/dev/null
	   ${SSH} ${prefix1}${mgt} "/bin/chmod -R 755 ${REMOTESANREPO}/*"
	done

}

function symLink {
	if [[ ${SETUP} == 'SMLAB' ]]; then
	echo "---Performing SMLAB specific operations"
	   for host in ${NN}; do
	      ${SSH} $host "/bin/rm -rf ${INSTALLPATH}/etc/PMRConfig.cfg"
	      sleep 1
	      ${SSH} $host "cd ${INSTALLPATH}/etc/ ; /bin/ln -s PMRConfig.smlab ./PMRConfig.cfg"
	   done
	   ${SSH} ${prefix1}${mgmt0} "/bin/rm -rf ${REMOTESANREPO}/etc/PMRConfig.cfg"
	   sleep 1
	   ${SSH} ${prefix1}${mgmt0} "cd ${REMOTESANREPO}/etc/ ; /bin/ln -s PMRConfig.smlab ./PMRConfig.cfg"
	fi

	if [[ ${SETUP} == 'NORSE' ]]; then
        echo "---Performing Norse LAB specific operations"
           for host in ${NN}; do
              ${SSH} $host "/bin/rm -rf ${INSTALLPATH}/etc/PMRConfig.cfg"
              sleep 1
              ${SSH} $host "cd ${INSTALLPATH}/etc/ ; /bin/ln -s PMRConfig.norselab ./PMRConfig.cfg"
           done
           ${SSH} ${prefix1}${mgmt0} "/bin/rm -rf ${REMOTESANREPO}/etc/PMRConfig.cfg"
           sleep 1
           ${SSH} ${prefix1}${mgmt0} "cd ${REMOTESANREPO}/etc/ ; /bin/ln -s PMRConfig.norselab ./PMRConfig.cfg"
        fi


	echo "---Scheduling PMR jobs"
	for host in ${NN}; do
	   ${SSH} $host "/bin/rm -rf /etc/cron.d/PMR_DC.cron"
	   ${SSH} $host "cd /etc/cron.d/ ; /bin/ln -s ${INSTALLPATH}/etc/PMR_DC.cron ./PMR_DC.cron"
	   ${SSH} $host "/opt/tms/bin/cli -t 'en' 'conf t' 'pm process crond restart'"
	   ${SSH} $host "/opt/tms/bin/cli -t 'en' 'conf t' 'logging file pmr path /var/log/PMRLogger.log'"
	   ${SSH} $host "/opt/tms/bin/cli -t 'en' 'conf t' 'logging file pmr rotation criteria size 200' 'wr mem'"
	done 
}

function insertDCValue {
	echo "---Updating install type to be : \"$DC\""
	for host in ${NN}; do
	   ${SSH} $host "perl -pi -e 's/insertdcvalue/$DC/g' ${INSTALLPATH}/etc/*"
	   ${SSH} $host "perl -pi -e 's/insertdcvalue/$DC/g' ${INSTALLPATH}/bin/*"
	   ${SSH} $host "perl -pi -e 's/insertdcvalue/$DC/g' ${INSTALLPATH}/DC/*" 2>/dev/null
	   if [[ ${DC} == 'VISP' ]] ; then
        	${SSH} ${host} "perl -pi -e 's/^DATAPATH=.*$/DATAPATH=\"\/data\/gms\/pmr\/data\"/' ${INSTALLPATH}/etc/*" 2>/dev/null
           fi
	done	
	${SSH} ${prefix1}${mgmt0} "perl -pi -e 's/insertdcvalue/$DC/g' ${REMOTESANREPO}/etc/*"
	${SSH} ${prefix1}${mgmt0} "perl -pi -e 's/insertdcvalue/$DC/g' ${REMOTESANREPO}/bin/*"
	${SSH} ${prefix1}${mgmt0} "perl -pi -e 's/insertdcvalue/$DC/g' ${REMOTESANREPO}/DC/*" 2>/dev/null
	if [[ ${DC} == 'VISP' ]] ; then
	   ${SSH} ${prefix1}${mgmt0} "perl -pi -e 's/^DATAPATH=.*$/DATAPATH=\"\/data\/gms\/pmr\/data\"/' ${REMOTESANREPO}/etc/*" 2>/dev/null
	fi
}

if [[ ${DC} == 'PNSA' || ${DC} == 'VISP' || ${DC} == 'CMDS' ]]; then
	identifyNN
	issueCommands
	createSAN
	insertDCValue
	symLink
	echo "---Done!"
else
	usage
fi

