#!/usr/bin/bash

# This uses df to find the free space of physical disks


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Run df with only the columns we want, mount point and available kibibytes
df_output=$(df --output=target --output=avail)

# Filter the output to only the lines we want, those with /boot or /mnt/disk* or /mnt/cache
# https://phoenixnap.com/kb/grep-multiple-strings
filtered_df_lines=$(grep -e '/mnt/disk[0-9]' -e '/mnt/cache' -e '/boot' <<< "$df_output")

# Iterate over each line of output
# https://unix.stackexchange.com/questions/9784/how-can-i-read-line-by-line-from-a-variable-in-bash
while IFS= read -r line
do

    # Get the clean name, or everything after the last slash
    # https://unix.stackexchange.com/questions/247560/print-everything-after-a-slash
    line=$(echo "$line" | sed 's:.*/::')

    # Use awk to get the desired information
    disk_name=$(echo "$line" | awk '{print $1}')
    disk_free_kib=$(echo "$line" | awk '{print $2}')

    # Exit early if Name is empty or free space is not numeric
    # https://unix.stackexchange.com/questions/151654/checking-if-an-input-number-is-an-integer
    if [[ -z "$disk_name" || ! $disk_free_kib =~ ^[0-9]+$ ]]
    then
        echo "Exiting: Encountered an empty disk name or non-numeric free space"
        exit 1
    fi

    # Multiply KiB by 1024 to get bytes
    disk_free=$((disk_free_kib * 1024))

    # Output the final string to STDOUT
    echo "$disk_name: $disk_free"

    # Printf '%s\n' "$var" is necessary because printf '%s' "$var" on a
    # variable that doesn't end with a newline then the while loop will
    # completely miss the last line of the variable.
done < <(printf '%s\n' "$filtered_df_lines")

# Exit normally with 0 signal
exit 0