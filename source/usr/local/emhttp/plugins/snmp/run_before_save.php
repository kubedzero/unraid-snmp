<?php
if (!empty($_REQUEST['SNMPDCONF'])) {
    // Copy the text box content into the live config file used by SNMP
    file_put_contents('/etc/snmp/snmpd.conf', $_REQUEST['SNMPDCONF']);
    // Also write to USB so package installation can use it after reboot/update
    file_put_contents('/boot/config/plugins/snmp/snmpd.conf', $_REQUEST['SNMPDCONF']);
}
?>