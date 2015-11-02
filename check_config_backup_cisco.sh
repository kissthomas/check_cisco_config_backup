#!/bin/bash
#
# Special script for nagios/icinga to initiate Config Backup via SNMP to a
# specified server supported by cisco device (tftp for example).
# Alternatively you can use this scipt to automatically save configuration on
# your cisco devices (run copy running-config startup-config periodically)
#
# Usage:
#
# Backing up to remote server:
# ./check_config_backup_save.sh -H 10.254.254.1 -i 10.254.254.211
#
# Saving running config to startup config:
# ./check_config_backup_save.sh -H 10.254.254.1 -s 4 -d 3
#

HOST=127.0.0.1
SNMPVERSION=2c
SNMPCOMMUNITY=private

PROTOCOL=1              # tftp
SOURCETYPE=4            # running-config
DESTTYPE=1              # network file
SERVERIP=127.0.0.1      # destination ip address
FILENAME=config.cfg     # destination file name

function help() {
    echo "
Usage:
    $0 -H hostname -v [1|2c] -C community -p ccCopyProtocol -s ccCopySourceFileType -d ccCopyDestFileType -i server_ip -f filename

ccCopyProtocol:
     1 tftp
     2 ftp
     3 rcp
     4 scp
     5 sftp
ccCopySourceFileType and ccCopyDestFileType:
     1 networkFile
     2 iosFile
     3 startupConfig
     4 runningConfig
     5 terminal
     6 fabricStartupConfig
"
    exit 3
}

if [[ $# < 1 ]]; then
    help
fi

while [[ $# > 0 ]]
do
    key="$1"
    case $key in
      -H|--host)
        HOST="$2"
        shift
        ;;
      -v|--snpmversion)
        SNMPVERSION="$2"
        shift
        ;;
      -C|--community)
        SNMPCOMMUNITY="$2"
        shift
        ;;
      -p|--protocol)
        PROTOCOL="$2"
        shift
        ;;
      -s|--sourcetype)
        SOURCETYPE="$2"
        shift
        ;;
      -d|--desttype)
        DESTTYPE="$2"
        shift
        ;;
      -i|--serverip)
        SERVERIP="$2"
        shift
        ;;
      -f|--filename)
        FILENAME="$2"
        shift
        ;;
      *)
        help
        ;;
    esac
    shift # past argument or value
done

if [[ "$FILENAME" ==  "config.cfg" ]]; then
    if [[ $SOURCETYPE == 3 ]]; then
        FILENAME=$HOST-sc.cfg
    elif [[ $SOURCETYPE == 4 ]]; then
        FILENAME=$HOST-rc.cfg
    else
        FILENAME=$HOST.cfg
    fi
fi


snmpset=`which snmpset`
snmpget=`which snmpget`
RAND=$RANDOM

# The SNMP object types can be:
#     i: INTEGER
#     u: unsigned INTEGER
#     t: TIMETICKS
#     a: IPADDRESS
#     o: OBJID
#     s: STRING
#     x: HEX STRING
#     d: DECIMAL STRING
#     b: BITS
#     U: unsigned int64
#     I: signed int64
#     F: float
#     D: double

#
# ccCopyProtocol: The protocol file transfer protocol that should be used to
# copy the configuration file over the network. If the config file transfer is
# to occur locally on the SNMP agent, the method of transfer is left up to the
# implementation, and is not restricted to the protocols below.
# The object can be:
#     1. tftp
#     2. ftp
#     3. rcp
#     4. scp
#     5. sftp
$snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.2.$RAND i $PROTOCOL > /dev/null|| exit 3

# ccCopySourceFileType: Specifies the type of file to copy from.
# The object can be:
#     1. networkFile
#     2. iosFile
#     3. startupConfig
#     4. runningConfig
#     5. terminal
#     6. fabricStartupConfig
$snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.3.$RAND i $SOURCETYPE > /dev/null || exit 3

# ccCopyDestFileType: specifies the type of file to copy to.
# The object can be:
#     1. networkFile
#     2. iosFile
#     3. startupConfig
#     4. runningConfig
#     5. terminal
#     6. fabricStartupConfig
$snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.4.$RAND i $DESTTYPE > /dev/null || exit 3

if [[ $SOURCETYPE != 3 && $SOURCETYPE != 4 ]] || [[ $DESTTYPE != 3 && $DESTTYPE != 4 ]] ; then
    # ccCopyServerAddress: The IP address of the TFTP server from (or to) which to
    # copy the configuration file. This object must be created when either the
    # ccCopySourceFileType or ccCopyDestFileType has the value 'networkFile'.
    $snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.5.$RAND a $SERVERIP > /dev/null || exit 3

    # ccCopyFileName: The file name (including the path, if applicable) of the file.
    $snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.6.$RAND s $FILENAME > /dev/null || exit 3
fi

# ccCopyEntryRowStatus: The status of this table entry. Once the entry status
# is set to active, the associated entry cannot be modified until the request
# completes (ccCopyState transitions to ‘successful’ or ‘failed’ state).
# The object can be:
#     1. active
#     2. notInService
#     3. notReady
#     4. createAndGo
#     5. createAndWait
#     6. destroy
$snmpset -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.14.$RAND i 1 > /dev/null || exit 3

# ccCopyState: Specifies the state of this config-copy request. This value of
# this object is instantiated only after the row has been instantiated, i.e.
# after the ccCopyEntryRowStatus has been made active.
# The object can be:
#     1. waiting
#     2. running
#     3. successful
#     4. failed

RUNTIME=`date +%s`
while [[ `$snmpget -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.10.$RAND | awk '{print $NF}'` < 3 ]]; do
   sleep 1
done
((RUNTIME=`date +%s`-RUNTIME))

RESULT=`$snmpget -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.10.$RAND | awk '{print $NF}'`

case $RESULT in
  3)
    echo "OK | time=${RUNTIME}s;;;;"
    exit 0
    ;;
  4)
    RESULT2=`$snmpget -c $SNMPCOMMUNITY -v $SNMPVERSION $HOST 1.3.6.1.4.1.9.9.96.1.1.1.1.13.$RAND | awk '{print $NF}'`
    case $RESULT2 in
        1) ERROR='Unknown error' ;;
        2) ERROR='Bad file name' ;;
        3) ERROR='Timeout' ;;
        4) ERROR='No memory' ;;
        5) ERROR='No config' ;;
        6) ERROR='Unsupported protocol' ;;
        7) ERROR='Some config failed to apply' ;;
        8) ERROR='System not ready' ;;
        9) ERROR='Request aborted' ;;
    esac
    echo "WARNING: $ERROR | time=${RUNTIME}s;;;;"
    exit 1
    ;;
esac
