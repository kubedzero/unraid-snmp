#!/bin/sh

# Configure the SNMP plugin files for use


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

echo "Set directory permissions and move into it"
chmod a+r /usr/local/emhttp/plugins/snmp
cd /usr/local/emhttp/plugins/snmp

echo "Set shell script executable permissions"
chmod a+x disk_free_space.sh
chmod a+x drive_temps.sh
chmod a+x share_free_space.sh

echo "Set read only permissions for other files"
chmod a+r snmpd.conf
chmod a+r snmp.png
chmod a+r README.md

# Only run modifications if snmpd startup/shutdown file exists
# https://linuxize.com/post/bash-check-if-file-exists/
if [[ -f /etc/rc.d/rc.snmpd ]]; then

    echo "Stop SNMP daemon if it is currently running"
    bash /etc/rc.d/rc.snmpd stop

    echo "Replace the default SNMP config with our own, backing up the original"
    mv --backup /usr/local/emhttp/plugins/snmp/snmpd.conf /etc/snmp/snmpd.conf

    # Define the additional flags we want to add into the SNMP daemon startup
    # Spaces at beginning and end of string to separate from other flags
    # 1=a=alert, 2=c=crit, 3=e=err, 4=w=warn, 5=n=notice, 6=i=info, 7=d=debug
    new_flags=" -LS0-6d -Lf /dev/null "

    # Get existing OPTIONS from file, keeping only what's in double quotes
    # https://stackoverflow.com/questions/35636323/extracting-a-string-between-two-quotes-in-bash
    options=$(grep "OPTIONS=" /etc/rc.d/rc.snmpd | cut -d'"' -f 2)
    # Check that flags haven't already been added
    if [[ $options != *"-L"* ]]; then
        # Concatenate the new flags with the old
        options=$new_flags$options
        echo "Editing SNMP startup flags to be [$options]"
        # Replace the line beginning with OPTIONS= with a custom set
        # Use a custom delimiter | to avoid collisions of sed and variable use of /
        # Escape the start quote and end quote when we recreate the line
        # https://stackoverflow.com/questions/9366816/sed-fails-with-unknown-option-to-s-error
        sed --in-place=.bak --expression "s|^OPTIONS=.*|OPTIONS=\"$options\"|" /etc/rc.d/rc.snmpd
    else
        echo "SNMP logging flag already present, skipping modification"
    fi

    echo "Restart SNMP daemon now that we've adjusted how it starts up"
    # Make sure error logging is going to STDOUT so it prints in install logs
    bash /etc/rc.d/rc.snmpd start 2>&1
    echo "PID of started SNMP daemon is $(cat /var/run/snmpd)"

    # Exit with the code of the SNMP daemon startup
    exit $?
else
    echo "Exiting: /etc/rc.d/rc.snmpd did not exist. Is net-snmp installed?"
    exit 1
fi
