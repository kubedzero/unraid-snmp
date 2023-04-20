#!/bin/sh

# Configure the SNMP plugin files for use


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

directory="/usr/local/emhttp/plugins/snmp"
echo "Set permissions and move into dir $directory"
chmod a+r "$directory"
cd "$directory"

echo "Set shell script executable permissions"
chmod a+x cpu_mhz.sh
chmod a+x disk_free_space.sh
chmod a+x disk_temps.sh
chmod a+x mem_info.sh
chmod a+x share_free_space.sh

echo "Set read only permissions for other files"
chmod a+r snmpd.conf
chmod a+r snmp.page
chmod a+r snmp.png
chmod a+r README.md

echo "Checking if /etc/rc.d/rc.snmpd exists before editing"
# Only run modifications if snmpd startup/shutdown file exists
# https://linuxize.com/post/bash-check-if-file-exists/
if [[ -f /etc/rc.d/rc.snmpd ]]; then

    echo "Stop SNMP daemon if it is currently running"
    bash /etc/rc.d/rc.snmpd stop 2>&1

    
    # Check if a UI/user-defined snmpd.conf exists on the USB disk, 
    # copying that over the default snmpd.conf. Otherwise use the 
    # bundled, Unraid-customized snmpd.conf unzipped as part of the .txz.
    # NOTE: Plugin 2020.04.01 and earlier use the .conf under 
    # /usr/local/emhttp/plugins/, so leave it by using cp instead of mv.
    custom_snmpd="/boot/config/plugins/snmp/snmpd.conf"
    original_snmpd="/etc/snmp/snmpd.conf"
    plugin_default_snmpd="$directory/snmpd.conf"
    if [[ -f $custom_snmpd ]]; then
        echo "Using the user-defined config $custom_snmpd, backing up the original"
        cp --backup "$custom_snmpd" "$original_snmpd"
    elif [[ -f $plugin_default_snmpd ]]; then
        echo "Using the Unraid default config $plugin_default_snmpd, backing up the original"
        cp --backup "$plugin_default_snmpd" "$original_snmpd"
    else
        echo "Could not find user-defined or Unraid-customized snmpd.conf! Using default $original_snmpd"
    fi


    echo "Writing extra SNMPD_OPTIONS into /etc/default/snmpd to configure logging"
    # Define the additional flags to be added into the SNMP daemon startup
    # 1=a=alert, 2=c=crit, 3=e=err, 4=w=warn, 5=n=notice, 6=i=info, 7=d=debug
    # Write these flags into /etc/default/snmpd. As of SNMP 5.9.3, this file
    # is sourced and merged with the default flags inside /etc/rc.d/rc.snmpd upon startup.
    # https://tldp.org/LDP/abs/html/internal.html#SOURCEREF
    # https://stackoverflow.com/questions/6697753/difference-between-single-and-double-quotes-in-bash
    echo 'SNMPD_OPTIONS="-LF 0-5 /var/log/snmpd.log"' > /etc/default/snmpd

    echo "Start SNMP daemon back up now that snmpd.conf and /etc/default/snmpd modifications are done"
    # Make sure error logging is going to STDOUT so it prints in install logs
    bash /etc/rc.d/rc.snmpd start 2>&1

    # Wait for daemon startup to complete by watching for PID file
    # Send error output of "No such file or directory" to /dev/null
    # NOTE: ps -ef | grep snmp can be used to confirm the flags were set correctly
    count=0
    sleep 2
    while [[ -z "$(cat /var/run/snmpd 2> /dev/null)" ]]; do
        printf "."
        sleep 1
        count=$((count+1))
        if [ $count -ge 10 ]; then
            echo "SNMP may be having troubles starting, check arguments"
            exit 1
        fi
    done
    echo "PID of started SNMP daemon is $(cat /var/run/snmpd)"

    exit 0
else
    echo "Exiting: /etc/rc.d/rc.snmpd did not exist. Is net-snmp installed?"
    exit 1
fi
