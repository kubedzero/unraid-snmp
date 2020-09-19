#!/bin/sh

# Given a version name and source code directory, create the snmp-unraid package


# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

package_name="unraid-snmp"

echo "Version defined as [$1]"
echo "Source code directory defined as [$2]"

file_name=$(printf "%s-%s-x86_64-1.txz" "$package_name" "$1")

echo "Creating Slackware package $(pwd)/$file_name"
makepkg --linkadd y --chown n "$file_name"
