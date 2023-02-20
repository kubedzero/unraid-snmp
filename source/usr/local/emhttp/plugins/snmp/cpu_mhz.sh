#!/bin/bash

# This uses /proc/cpuinfo to find the speed of the processor in Megahertz


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Find the first line in /proc/cpuinfo with the 
#  MHz (it repeats for each installed processor), and grab the number to store as a variable
# Relevant cpuinfo output: cpu MHz     : 4199.992
cpuinfo_mhz=$(grep "cpu MHz" --max-count 1 /proc/cpuinfo | awk '{print $4}')

# Exit if MHz is empty or non-numeric, otherwise print and exit
# https://www.geekpills.com/operating-system/linux/bash-check-integer-or-float
if [[ -z "$cpuinfo_mhz" ]]
then
    echo "Exiting: Encountered an empty MHz value"
else
    if [[ $cpuinfo_mhz =~ ^[+-]?[0-9]*$ || $cpuinfo_mhz =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]
    then
        echo "$cpuinfo_mhz MHz"
        exit 0
    else
        echo "Exiting: Encountered a non-numeric CPU MHz"
    fi
fi

# Exit with an error, as we only get here if there was an issue
exit 1