#!/bin/sh

# Configure the SNMP plugin files for use


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

directory="/usr/local/emhttp/plugins/snmp/"
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

    echo "Replace default snmpd.conf with our own, backing up the original"
    # NOTE: Use cp, not mv. Plugin 2020.04.01 and earlier use the .conf
    # under /usr/local and updating will fail if SNMP can't start.

    # See if we have custom settings to restore
    if [[ -f /boot/config/plugins/snmp/snmpd.conf ]]; then
        cp --backup /boot/config/plugins/snmp/snmpd.conf /etc/snmp/snmpd.conf
      else
        # If not: use the default file included with this plugin
        cp --backup /usr/local/emhttp/plugins/snmp/snmpd.conf /etc/snmp/snmpd.conf
    fi


    # Define the additional flags we want to add into the SNMP daemon startup
    # Spaces at end of string to separate from other flags
    # 1=a=alert, 2=c=crit, 3=e=err, 4=w=warn, 5=n=notice, 6=i=info, 7=d=debug
    new_flags="-LF 0-5 /var/log/snmpd.log "

    # Get existing OPTIONS from file, keeping only what's in double quotes
    # https://stackoverflow.com/questions/35636323/extracting-a-string-between-two-quotes-in-bash
    options=$(grep "OPTIONS=" /etc/rc.d/rc.snmpd | cut -d'"' -f 2)
    # Check that new flags haven't already been added
    if [[ $options != *"-L"* ]]; then
        # Concatenate the new flags with the old
        options=$new_flags$options
        echo "Editing SNMP startup options in rc.snmpd to be [$options]"
        # Replace the line beginning with OPTIONS= with a custom set
        # Use a custom delimiter | to avoid collisions of sed and variable use of /
        # Escape the start quote and end quote when we recreate the line
        # https://stackoverflow.com/questions/9366816/sed-fails-with-unknown-option-to-s-error
        sed --in-place=.bak --expression "s|^OPTIONS=.*|OPTIONS=\"$options\"|" /etc/rc.d/rc.snmpd
    else
        echo "SNMP logging flag already present in rc.snmpd, skipping modification"
    fi

    echo "Restart SNMP daemon now that we've adjusted how rc.snmpd starts it"
    # Make sure error logging is going to STDOUT so it prints in install logs
    bash /etc/rc.d/rc.snmpd start 2>&1

    # Wait for daemon startup to complete by watching for PID file
    # Send error output of "No such file or directory" to /dev/null
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
