#!/bin/bash

# This uses lscpu to find the speed of the processor in Megahertz


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Run lscpu, find just the line with the Mhz, and grab the number
# Example lscpu output: CPU MHz:                         2400.000
lscpu_output=$(lscpu | grep "CPU MHz" | awk '{print $3}')

# Exit if Mhz is empty or non-numeric, otherwise print and exit
# https://www.geekpills.com/operating-system/linux/bash-check-integer-or-float
if [[ -z "$lscpu_output" ]]
then
    echo "Exiting: Encountered an empty MHz value"
else
    if [[ $lscpu_output =~ ^[+-]?[0-9]*$ || $lscpu_output =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]
    then
        echo "$lscpu_output MHz"
        exit 0
    else
        echo "Exiting: Encountered a non-numeric CPU MHz"
    fi
fi

# Exit with an error, as we only get here if there was an issue
exit 1