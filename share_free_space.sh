#!/usr/bin/bash

ECHO=/usr/bin/echo
GREP=/usr/bin/grep
SED=/usr/bin/sed

SHARES_INI=/var/local/emhttp/shares.ini

$GREP '\(\[\|free=\)' /var/local/emhttp/shares.ini | while read -r share_name
do
  read -r free_kb

  share_name=$($ECHO $share_name | $SED 's/\["\(.*\)"\]/\1/')
  free_kb=$($ECHO $free_kb | $SED 's/free="\(.*\)"/\1/')

  free_bytes=$(($free_kb * 1024))

  if [[ -z "$share_name" || ! $free_bytes =~ ^[0-9]+$ ]]
  then
    $ECHO "ERROR! Couldn't parse $SHARES_INI"
    exit 1
  fi

  $ECHO "$share_name: $free_bytes"
done

exit 0
