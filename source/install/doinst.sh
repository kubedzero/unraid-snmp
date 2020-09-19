#!/bin/sh

# Configure the SNMP plugin files for use


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Set directory permissions and move into it
chmod a+r /usr/local/emhttp/plugins/snmp
cd /usr/local/emhttp/plugins/snmp

# Set shell script executable permissions
chmod a+x disk_free_space.sh
chmod a+x drive_temps.sh
chmod a+x share_free_space.sh

# Set read only permissions for other files
chmod a+r snmpd.conf
chmod a+r snmp.png
chmod a+r README.md