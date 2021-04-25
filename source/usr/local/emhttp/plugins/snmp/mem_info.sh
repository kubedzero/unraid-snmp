#!/bin/bash

# This uses /proc/meminfo to grab various memory values for SNMP

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Given arguments, retrieve and format for output to SNMP
# $1 is proc_mem_name_grep, $2 is friendly_name
getValFromMemInfo () {

    # Using the passed in argument, try to get the line from /proc/meminfo
    mem_value=$(grep "$1" /proc/meminfo)

    # Skip outputting if grep pattern did not yield exactly one result
    if [[ ! "$(echo $mem_value | wc -l)" -eq "1" ]]
    then
        return
    fi

    # Comparing to free --kibi, kibibytes is confirmed in /proc/meminfo 
    mem_value_kibi=$(echo "$mem_value" | awk '{print $2}')
    # Change to bytes, avoid kilobyte (1000 bytes) kibibyte (1024 bytes) misuse
    mem_value_bytes=$((mem_value_kibi * 1024))
    # Use the friendly name and byte value as output
    echo "$2: $mem_value_bytes"
}

# Call the function, $1 is the grep pattern and $2 is the SNMP output name
# https://access.redhat.com/solutions/406773 describes different values
getValFromMemInfo "MemTotal:" "MemTotal"
getValFromMemInfo "MemFree:" "MemFree"
getValFromMemInfo "MemAvailable:" "MemAvailable"
# Force matching at the beginning of the line
getValFromMemInfo "^Cached:" "Cached"
getValFromMemInfo "Active:" "Active"
getValFromMemInfo "Inactive:" "Inactive"
getValFromMemInfo "Committed_AS:" "Committed_AS"
getValFromMemInfo "Dirty:" "Dirty"

exit 0