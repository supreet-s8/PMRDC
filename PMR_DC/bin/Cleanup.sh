#!/bin/bash

# Rread Configuration and quit if not Master 
. /data/scripts/PMR/PNSA/etc/PMRConfig.cfg

find ${DATAPATH} -mindepth 2 -type d -mtime +${CLEANDATE} -exec rm -fr {} \;

exit 0
