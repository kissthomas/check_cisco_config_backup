# check_config_backup
Nagios/Icinga scripts to backup/save Cisco IOS and Mikrotik configuration.

Special script for nagios/icinga to initiate Config Backup via SNMP to a
 specified server supported by cisco device (tftp for example).

Alternatively you can use this scipt to automatically save configuration on
your cisco devices (run copy running-config startup-config periodically)

## Usage

### Backing up to remote server
    ./check_config_backup_save.sh -H 10.254.254.1 -i 10.254.254.211

### Saving running config to startup config
    ./check_config_backup_save.sh -H 10.254.254.1 -s 4 -d 3

## Icinga2 command template
### Command template
```icinga2
object CheckCommand "check-config-backup-cisco" {
	import "plugin-check-command"
	import "ipv4-or-ipv6"

	command = [ PluginDir + "/check_config_backup_cisco.sh" ]

	arguments = {
		"-H" = "$configbackup_address$"
		"-v" = {
			value = "$configbackup_snmpversion$"
			description = "SNMP version 1 or 2c"
		}
		"-C" = {
			value = "$configbackup_community$"
			description = "SNMP community"
		}
		"-p" = {
			value = "$configbackup_protocol$"
			description = "File transfer protocol"
		}
		"-s" = {
			value = "$configbackup_sourcetype$"
			description = "Backup source type"
		}
		"-d" = {
			value = "$configbackup_desttype$"
			description = "Backup destination type"
		}
		"-i" = {
			value = "$configbackup_server_ip$"
			description = "Source/Destination server IP address when network transfer requested"
		}
		"-f" = {
			value = "$configbackup_filename$"
			description = "Source/Destination Filename for file transfer"
		}
	}

	vars.configbackup_address = "$check_address$"
	vars.configbackup_community = "private"
	vars.configbackup_snmpversion = "2c"
	vars.configbackup_protocol = 1
	vars.configbackup_sourcetype = 4
	vars.configbackup_desttype = 1

}
```

### Service template for backing up running config
```icinga2
apply Service "config-backup" {
    import "generic-service"
    check_command = "check-config-backup-cisco"
    check_interval = 12h

    /**
     * IP address of your TFTP server
     */
    vars.configbackup_server_ip = "10.9.8.7"

    assign where host.vars.os == "Cisco IOS"
}
```
> As you can see here I'm using host.vars.os property to automatically
> assign the service to all my __Cisco IOS__ devices.

### Service template for backing up startup config
```icinga2
apply Service "config-backup" {
    import "generic-service"
    check_command = "check-config-backup"
    check_interval = 12h

    /**
     * IP address of your TFTP server
     */
    vars.configbackup_server_ip = "10.9.8.7"
    vars.configbackup_sourcetype = 3

    assign where host.vars.os == "Cisco IOS"
}
```

### Service template for saving running-config to startup-config periodically
```icinga2
apply Service "config-backup" {
    import "generic-service"
    check_command = "check-config-backup"
    check_interval = 12h

    vars.configbackup_sourcetype = 4
    vars.configbackup_desttype = 3

    assign where host.vars.os == "Cisco IOS"
}
```
