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

function restoreLocal {
	echo "---Backout PMR V2 Install"
	for host in ${NN}; do
	   ${SSH} $host '/bin/mount -o remount,rw /'
	   echo "---Restoring PMR-V1 on $host"
	   if [[ `${SSH} $host "/bin/ls ${INSTALLPATH}-V1-obsolete 2>/dev/null"` ]]; then
	        ${SSH} $host "/bin/rm -rf ${INSTALLPATH} 2>/dev/null"
		${SSH} $host "/bin/mv ${INSTALLPATH}-V1-obsolete ${INSTALLPATH} 2>/dev/null"
	   	if [[ $? -eq '0' ]]; then
			echo "---Success!" 
	   		${SSH} $host "/bin/chmod -R 755 ${INSTALLPATH}/*"
		else 
			echo "---FAILED to restore PMR-V1 on $host! Skipping..."
		fi
	   else 
		echo "---No PMR V1 backup found to be restored! Probably, already backed out. Skipping..."
	   fi
	done
}

function restoreSAN {
	for mgt in ${mgmt0}; do 
	   ${SSH} ${prefix1}${mgt} "/bin/mount -o remount,rw /"
	   echo "---Restoring PMR-V1 at SAN Repository ${prefix1}${mgt}"
	   if [[ `${SSH} ${prefix1}${mgt} "/bin/ls ${REMOTESANREPO}-V1-obsolete 2>/dev/null"` ]]; then
		${SSH} ${prefix1}${mgt} "/bin/rm -rf ${REMOTESANREPO} 2>/dev/null"
	        ${SSH} ${prefix1}${mgt} "/bin/mv ${REMOTESANREPO}-V1-obsolete ${REMOTESANREPO} 2>/dev/null"
	   	if [[ $? -eq '0' ]]; then
			echo "---Success!"
			${SSH} ${prefix1}${mgt} "/bin/chmod -R 755 ${REMOTESANREPO}/*"
		else
                	echo "---FAILED to restore PMR-V1 on ${prefix1}${mgt}! Skipping..."
           	fi
           else
		echo "---No PMR V1 backup found to be restored! Probably, already backed out. Skipping..."
	   fi
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

# MAIN

if [[ ${DC} == 'PNSA' || ${DC} == 'VISP' || ${DC} == 'CMDS' ]]; then
	identifyNN
	restoreLocal
	# Ask for backout from SAP SAN Repository.
        echo "---Backout VISP PMR V2 code from SAN repository."; echo; 
        echo -en '\E[1;37;41m'"WARNING:"; tput sgr0; echo -en '\E[31;40m'" Following steps will ensure VISP repository PMR code at management nodes be backed out to V1 hence, it will get replicated to all the DCs which are already on V2. Steps are actually meant to be executed for LAB environments to assist re-testing the tool install and uninstall again and again in labs. Be careful proceeding, if you are executing in production environment..."; tput sgr0; echo
        echo; ans=''
        while [[ $ans != 'y' && $ans != 'n' ]]; do
                read -p "Are you sure that you want to pursue VISP PMR V2 Code backout at SAN repository? (y/n) : " ans
        done
	#----------------------------------------
        if [[ $ans == 'y' ]]; then 
	   restoreSAN
        fi 

	symLink
	echo "---Done!"

else
	usage
fi

