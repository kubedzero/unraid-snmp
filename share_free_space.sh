#!/usr/bin/bash

# This uses the Unraid-provided shares.ini to print out free KB per share

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Define the input file from which we will read Share name and free KB
iniInput=/var/local/emhttp/shares.ini

# Store Share names and KB free
# Find names by getting lines with an open bracket "["
shareNames=$(grep '\[' $iniInput)
# Find kilobytes free by getting lines with string "free="
shareFree=$(grep 'free=' $iniInput)

# Store the line count of shareNames 
shareNameCount=$(echo "$shareNames" | wc -l)

# If counts differ, exit early
if [ "$shareNameCount" -ne "$(echo "$shareNames" | wc -l)" ]
then
  echo "Exiting: Name count [$shareNameCount] differs from Free count"
  exit 1
fi

# Iterate through each name/size element pair
# https://github.com/koalaman/shellcheck/wiki/SC2004 no need for $
for (( i=1; i<=shareNameCount; i++ ));
do

  # Name stored as ["myShareName"] with surrounding double quotes and brackets
  # https://stackoverflow.com/questions/15777232/how-can-i-echo-print-specific-lines-from-a-bash-variable
  # Remove the opening [" and the closing "]. In sed, \[" matches open [" 
  # \(.*\) groups the middle, "\] matches end "], \1 outputs the middle group  
  share_name=$(sed -n "${i}"p <<< "$shareNames" | sed 's/\["\(.*\)"\]/\1/')

  # Free space stored as free="12345" with free=" at start and " at end
  free_kb=$(sed -n "${i}"p <<< "$shareFree" | sed 's/free="\(.*\)"/\1/')

  # Exit early if Share Name is empty or free space is not numeric
  # https://unix.stackexchange.com/questions/151654/checking-if-an-input-number-is-an-integer
  if [[ -z "$share_name" || ! $free_kb =~ ^[0-9]+$ ]]
  then
    $ECHO "Exiting: Encountered an empty share name or non-numeric free space"
    exit 1
  fi

  # Convert to bytes, avoid kilobyte (1000 bytes) kibibyte (1024 bytes) misuse
  free_bytes=$(($free_kb * 1024))

  # Print current share's name and free KB on a line for SNMP to grab
  echo "$share_name: $free_bytes"

done

# Exit normally with 0 signal
exit 0