#!/bin/bash

# This uses the Unraid-provided shares.ini to print out free KB per share

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Define the input file from which Share name and free KB will be read
shares_ini=/var/local/emhttp/shares.ini

# Check that the file exists and is non-empty and exit otherwise
if ! [[ -f "$shares_ini" ]] || ! [[ -s "$shares_ini" ]]; then
    exit 1
fi

# Store Share names and KB free
# Find names by getting lines with an open bracket "["
share_names=$(grep '^\[' $shares_ini)
# Find kilobytes free by getting lines with string "free="
share_free=$(grep '^free=' $shares_ini)

# Store the line count of share_names
share_name_count=$(echo "$share_names" | wc -l)

# If counts differ, exit early
if [ "$share_name_count" -ne "$(echo "$share_free" | wc -l)" ]
then
    echo "Exiting: Name count [$share_name_count] differs from Free count"
    exit 1
fi

# Iterate through each name/size pair
# https://github.com/koalaman/shellcheck/wiki/SC2004 no need for $
for (( i=1; i<=share_name_count; i++ ));
do

    # Name stored as ["myShareName"] with surrounding double quotes and brackets
    # https://stackoverflow.com/questions/15777232/how-can-i-echo-print-specific-lines-from-a-bash-variable
    # Remove the opening [" and the closing "]. In sed, \[" matches open ["
    # \(.*\) groups the middle, "\] matches end "], \1 outputs the middle group
    share_name=$(sed -n "${i}"p <<< "$share_names" | sed 's/\["\(.*\)"\]/\1/')

    # Free space stored as free="12345" with free=" at start and " at end
    free_kibibytes=$(sed -n "${i}"p <<< "$share_free" | sed 's/free="\(.*\)"/\1/')

    # Exit early if Share Name is empty or free space is not numeric
    # https://unix.stackexchange.com/questions/151654/checking-if-an-input-number-is-an-integer
    if [[ -z "$share_name" || ! $free_kibibytes =~ ^[0-9]+$ ]]
    then
        echo "Exiting: Encountered an empty share name or non-numeric free space"
        exit 1
    fi

    # Convert to bytes, avoid kilobyte (1000 bytes) kibibyte (1024 bytes) misuse
    # https://github.com/koalaman/shellcheck/wiki/SC2004 no need for $
    free_bytes=$((free_kibibytes * 1024))

    # Print current share's name and free KB on a line for SNMP to grab
    echo "$share_name: $free_bytes"

done

# Exit normally with 0 signal
exit 0