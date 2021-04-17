<?php
if (!empty($_REQUEST['SNMPDCONF'])) {
    // SNMPD is restarted through the HTML form by also supplying "#commands"
    file_put_contents('/etc/snmp/snmpd.conf', $_REQUEST['SNMPDCONF']);
    // Also write to USB so we can restore this file after update / reboot
    file_put_contents('/boot/config/plugins/snmp/snmpd.conf', $_REQUEST['SNMPDCONF']);
}
