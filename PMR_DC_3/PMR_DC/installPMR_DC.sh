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
TOOL="pmr-code-v01.tar.gz"
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
	   echo "---Backing up PMR-V1 on $host"
	   if [[ ! `${SSH} $host "/bin/ls ${INSTALLPATH}-V1-obsolete 2>/dev/null"` ]]; then
	        ${SSH} $host "/bin/mv ${INSTALLPATH} ${INSTALLPATH}-V1-obsolete 2>/dev/null"
	   	if [[ $? -ne '0' ]]; then
			if [[ `${SSH} $host "/bin/ls ${INSTALLPATH} 2>/dev/null"` ]]; then
			    echo "---FAILED to backup PMR-V1 on $host Try re-running the install. Committing Exit!"
			    exit 0
			else 
			    echo "---WARNING: PMR-V1 install not found on the system $host"
			    ack=''
			    while [[ $ack != "y" && $ack != "n" ]]; do
				read -p "Do you want to install the PMR-V2 directly (if yes, then backout will not be supported!)? (y/n) : " ack
			    done
			    if [[ $ack == 'n' ]]; then echo "---You chose to install PMR-V1 first. Thank you!"; exit; fi
			fi
		else 
			echo "---Success!"
		fi
	   else 
		echo "---Already backed up!"
	   fi
	   ${SSH} $host "/bin/mkdir -p ${INSTALLPATH}/DC/${CLLI}/"
	   /usr/bin/scp -q ${SOURCE}/${TOOL} root@${host}:${DEST} 
	   if [[ $? -ne '0' ]]; then 
		echo "---Unable to transfer toolset ${TOOL} to host ${host}! Skipping..."; 
	   else 
		${SSH} $host "/bin/tar zxvf ${DEST}/${TOOL} -C ${INSTALLPATH}" 1>/dev/null
                ${SSH} $host "/bin/chmod -R 755 ${INSTALLPATH}/*"
	   fi
	done
}

function createSAN {
	echo "---Creating SAN Repository"
	for mgt in ${mgmt0}; do 
	   echo "---Transferring toolset to management node : ${prefix1}${mgt}"
	   ${SSH} ${prefix1}${mgt} "/bin/mount -o remount,rw /"
	   /usr/bin/scp -q ${SOURCE}/${TOOL} root@${prefix1}${mgt}:${DEST}
	   echo "---Backing up PMR-V1 at SAN Repository"
	   if [[ ! `${SSH} ${prefix1}${mgt} "/bin/ls ${REMOTESANREPO}-V1-obsolete 2>/dev/null"` ]]; then
	        ${SSH} ${prefix1}${mgt} "/bin/mv ${REMOTESANREPO} ${REMOTESANREPO}-V1-obsolete 2>/dev/null"
	   	if [[ $? -ne '0' ]]; then
			if [[ `${SSH} ${prefix1}${mgt} "/bin/ls ${REMOTESANREPO} 2>/dev/null"` ]]; then
                	    echo "---FAILED to backup PMR-V1 on ${prefix1}${mgt}! Try re-running the install. Committing Exit!"
                	    exit 0
			else
			    echo "---WARNING: PMR-V1 install not found at repository ${prefix1}${mgt}"
			    ack=''
                            while [[ $ack != 'y' && $ack != 'n' ]]; do
                                read -p "Do you want to install the PMR-V2 directly at repository (if yes, then backout will not be supported!)? (y/n) : " ack
                            done
                            if [[ $ack == 'n' ]]; then echo "---You chose to install PMR-V1 first. Thank you!"; exit; fi
                        fi
		else
			echo "---Success!"
           	fi
           else
		echo "---Already backed up!"
	   fi
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

	if [[ ${SETUP} == 'PDI' ]]; then
        echo "---Performing PDI LAB specific operations"
           for host in ${NN}; do
              ${SSH} $host "/bin/rm -rf ${INSTALLPATH}/etc/PMRConfig.cfg"
              sleep 1
              ${SSH} $host "cd ${INSTALLPATH}/etc/ ; /bin/ln -s PMRConfig.pdilab ./PMRConfig.cfg"
           done
           ${SSH} ${prefix1}${mgmt0} "/bin/rm -rf ${REMOTESANREPO}/etc/PMRConfig.cfg"
           sleep 1
           ${SSH} ${prefix1}${mgmt0} "cd ${REMOTESANREPO}/etc/ ; /bin/ln -s PMRConfig.pdilab ./PMRConfig.cfg"
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
	# Prepare site architecture.
	   echo "---Creating site architecture at $host."
           ${SSH} $host "cd ${INSTALLPATH}/bin; ${INSTALLPATH}/bin/prepare_site.sh "
	   if [[ $? -ne '0' ]]; then echo "---WARNING: Contact Guavus Support."; else echo "---Success!"; fi
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

