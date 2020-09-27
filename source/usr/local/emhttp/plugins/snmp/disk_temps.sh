#!/usr/bin/bash

# Scan installed disks for their standby state and temperature
# Use a 5 minute TTL cache file for increased performance when calling rapidly

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Define the working directory in which files will live
working_dir=/tmp/plugins/snmp/
# Define the file that will hold disk temperatures
cache_file_name=disk_temps.txt
# Define the lock file that will prevent multiple simultaneous writes
cache_lock_name=disk_temps.lock
# Define the log output for errors
cache_log_name=disk_temps.log

# Update file name variables with full paths
cache_file_full_path="$working_dir$cache_file_name"
cache_lock_full_path="$working_dir$cache_lock_name"
cache_log_full_path="$working_dir$cache_log_name"

# Create the directory in which these files will reside
mkdir -p "$working_dir"

# Check if cache file has been modified in the last five minutes
if [[ -n $(find $working_dir -name $cache_file_name -mmin -5) ]]
then
    # Output to the log file that we used cached values
    echo "Valid cached values served at $(date)" >> "$cache_log_full_path"
    # Output the cached information
    cat "$cache_file_full_path"
    exit 0
fi


# Define the function which will poll the disks' state in another PID
function update_cache_file {
    # Attempt to get lock file handle/descriptor 200.
    # -n ensures we fail immediately if we can't immediately lock
    if ! flock -n 200
    then
        echo "PID $$ couldn't acquire lock on $cache_lock_full_path at $(date)"
        exit 2
    else
        echo "PID $$ acquired the lock at $(date). Begin updating $cache_file_name"
    fi

    # Call mdcmd to get disk info.
    mdcmd_data=$(mdcmd status)
    # Find instances of ID and Name with something after the = character
    # ID is the model/serial such as WDC_WD100EMAZ-00WJTA0_1EAAA8SZ
    # Name is the Linux address, the "sdc" part of /dev/sdc
    dev_model_data=$(grep 'rdevId.*=.' <<< "$mdcmd_data")
    dev_address_data=$(grep 'rdevName.*=.' <<< "$mdcmd_data")

    # Store the line count of models
    dev_model_count=$(echo "$dev_model_data" | wc -l)

    # If counts differ, exit early
    if [ "$dev_model_count" -ne "$(echo "$dev_address_data" | wc -l)" ]
    then
        echo "Exiting: Model count [$dev_model_count] differs from Address count"
        exit 1
    fi

    # source will load the lines of the .cfg as variables
    # Exit flag is 1 when file missing, so provide an OR true to offer an exit 0
    # 2> /dev/null hides STDERR and sends it to /dev/null instead
    # Set the variables we expect to get beforehand, so we know a base value exists
    source "/boot/config/plugins/snmp/snmp.cfg" 2> /dev/null || true

    # Check if the variable sourced from the .cfg is equal to 1/enabled
    # Provide default value if variable is unset, to avoid breaking `set`
    if [[ "${UNSAFETEMP:-}" -eq "1" ]]
    then
        echo "Disk temp retrieval may wake disks from STANDBY"
        # Set the command-modifying var we'll use later to an empty string
        # NOTE: WD disks need to be spun up for attributes to show
        # NOTE: Disks may be forced out of STANDBY to report attributes
        standby_check=""
    else
        # Call smartctl with --nocheck standby to exit early if power mode is STANDBY
        standby_check="--nocheck standby"
    fi

    # Remove the cache file before we start writing to it
    rm -f "$cache_file_full_path"

    # Iterate through each model/address pair
    # https://github.com/koalaman/shellcheck/wiki/SC2004 no need for $
    for (( i=1; i<=dev_model_count; i++ ));
    do

        # Get a particular line from each multi-line string
        model_line=$(sed -n "${i}"p <<< "$dev_model_data")
        address_line=$(sed -n "${i}"p <<< "$dev_address_data")

        # Check that each line has the same mdcmd group number
        model_group_num=$(echo "$model_line" | sed 's#.*\.\(.*\)=.*#\1#')
        address_group_num=$(echo "$address_line" | sed 's#.*\.\(.*\)=.*#\1#')

        if [[ "$model_group_num" != "$address_group_num" ]]
        then
            echo "Exiting: mdcmd parsing had mismatched group numbers $model_group_num and $address_group_num"
            exit 1
        fi

        # Format the address into /dev/sdc, /dev/sdN, etc
        dev_path=$(echo "$address_line" | sed 's#.*=#/dev/#')
        # Format the name by removing the mdcmd group info and equal sign
        disk_name=$(echo "$model_line" | sed 's/.*=//')

        # Call smartctl and attempt to get the attributes via -A
        # Exit flag is 2 when in standby, so provide an OR true to offer an exit 0
        # standby_check variable should either be an empty string (no modification)
        # or standby_check might be --nocheck standby to prevent disk spinup
        smartctl_output=$(smartctl $standby_check -A "$dev_path") || true

        # Check if the disk is reported to be in standby mode
        if [[ $smartctl_output == *"Device is in STANDBY mode"* ]]
        then
            echo "Disk $dev_path $disk_name in standby, reporting temperature as -2"
            # Append the formatted disk name and standby temperature to the cache file
            echo "$disk_name: -2" >> $cache_file_full_path
        else
            # Disk was not in standby and should have a temperature to read
            temperature=$(echo "$smartctl_output" | grep -m 1 -i Temperature_Celsius | awk '{print $10}')

            # Check that temp is non-empty and numeric, putting temp as -1 otherwise
            # https://www.geekpills.com/operating-system/linux/bash-check-integer-or-float
            if [[ -z "$temperature" ]]
            then
                echo "Encountered an empty temperature value, reporting temperature as -1"
            else
                if [[ $temperature =~ ^[+-]?[0-9]*$ || $temperature =~ ^[+-]?[0-9]+\.?[0-9]*$ ]]
                then
                    echo "Disk $dev_path $disk_name temp is $temperature C"
                    # Append the formatted disk name and real temperature to the cache file
                    echo "$disk_name: $temperature" >> $cache_file_full_path
                    sleep 1
                    # Continue to the next loop iteration
                    continue
                else
                    echo "Encountered a non-float, non-integer temperature, reporting temperature as -1"
                fi
            fi
            # Append the formatted disk name and error temperature to the cache file
            echo "$disk_name: -1" >> $cache_file_full_path
        fi

    done
    echo "PID $$ is finished with the lock at $(date), $cache_file_full_path is updated"
}

# Call the function defined above.
# </dev/null provides empty input. I'm not sure why we need this
# >>$cache_log_full_path redirects all STDOUT to a file
# 2>&1 redirects STDERR (2) into STDOUT (1)
# 200>$filename I think executes the function under file handle 200 on the given filename
# & forks and runs the function in a subshell with a separate PID
# https://bashitout.com/2013/05/18/Ampersands-on-the-command-line.html
# https://tobru.ch/follow-up-bash-script-locking-with-flock/
update_cache_file </dev/null >>$cache_log_full_path 2>&1 200>$cache_lock_full_path &

# Disconnect the forked process from this script's PID tree
disown

# Wait 1000ms for a chance at disk temps being partially for fully listed
sleep 1

# Check if cache file has been modified in the last five minutes
if [[ -n $(find $working_dir -name $cache_file_name -mmin -5) ]]
then
    # Output whatever cached info is there, which is better than nothing
    # This is the same behavior as calling SNMP rapidly after refresh
    # which could lead to partial results
    cat "$cache_file_full_path"
    exit 0
fi


exit 0
