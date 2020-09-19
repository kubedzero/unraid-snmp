#!/usr/bin/bash

# This implementation isn't very advanced. Some hard drive manufacturers can compute the drive temps without spinning up
# the drives. See https://code.google.com/p/unraid-unmenu/source/browse/trunk/drivedb.lib.awk for a more sophisticated
# version.

MDCMD=/usr/local/sbin/mdcmd
AWK=/usr/bin/awk
BASENAME=/usr/bin/basename
CAT=/usr/bin/cat
ECHO=/usr/bin/echo
FIND=/usr/bin/find
FLOCK=/usr/bin/flock
GREP=/usr/bin/grep
RM=/usr/bin/rm
SED=/usr/bin/sed
HDPARM=/usr/sbin/hdparm
SMARTCTL=/usr/sbin/smartctl

CACHE=/tmp/plugins/snmp/drive_temps.txt
LOG=/tmp/plugins/snmp/drive_temps.log
LOCKFILE=/tmp/plugins/snmp/drive_temps.lock

mkdir -p $(dirname $CACHE)
mkdir -p $(dirname $LOG)
mkdir -p $(dirname $LOCKFILE)

#-----------------------------------------------------------------------------------------------------------------------

# Cache the results for 5 minutes at a time, to speed up queries
if $FIND $(dirname $CACHE) -mmin -5 -name $($BASENAME $CACHE) | $GREP -q $($BASENAME $CACHE)
then
  $CAT $CACHE
  exit 0
fi

#-----------------------------------------------------------------------------------------------------------------------

function compute_temperatures {
  if ! $FLOCK -n 200
  then
    echo "Couldn't acquire lock on $LOCKFILE"
    exit 2
  fi

  $RM -f $CACHE

  $MDCMD status | $GREP '\(rdevId\|rdevName\).*=.' | while read -r device
  do
    read -r name

    # Double-check the data to make sure it's in sync
    device_num=$($ECHO $device | $SED 's#.*\.\(.*\)=.*#\1#')
    name_num=$($ECHO $name | $SED 's#.*\.\(.*\)=.*#\1#')

    if [[ "$device_num" != "$name_num" ]]
    then
      $ECHO 'ERROR! Couldn'"'"'t parse mdcmd output. Command was:'
      $ECHO "$MDCMD status | $GREP '\(rdevId\|rdevName\).*=.' | while read -r device"
      exit 1
    fi

    device=$($ECHO $device | $SED 's#.*=#/dev/#')
    name=$($ECHO $name | $SED 's/.*=//')

    # Guzzi reports that it doesn't work for him with this guard code. I tested it and on my systems the drives don't spin
    # up. Perhaps this behavior changed from when the code I stole was first written. :)
    # https://lime-technology.com/forum/index.php?topic=41019.msg403695#msg403695
#    if ! $HDPARM -C $device 2>&1 | $GREP -cq standby
#    then
      temp=$($SMARTCTL -A $device | $GREP -m 1 -i Temperature_Celsius | $AWK '{print $10}')
#    fi

    # For debugging
#    $ECHO "$name = $device, $temp"

    $ECHO "$name: $temp" >> $CACHE
  done

  sleep 15
}

#-----------------------------------------------------------------------------------------------------------------------

compute_temperatures </dev/null >>$LOG 2>&1 200>$LOCKFILE &
disown

exit 0
