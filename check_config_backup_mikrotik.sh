#!/bin/bash
#
# Special script for nagios/icinga to initiate Config Backup via SSH to a
# remote server for Mikrotik devices.
#
# Usage:
#
# Backing up to remote server:
# ./check_config_backup_mikrotik.sh -H 10.254.254.1 -u admin -D /tftpboot -k 5 -t backup -P secret
#

HOST=127.0.0.1
USER=admin
DST_DIR=/tftpboot
KEEP_ON_ROUTER=7
BACKUP_TYPE='backup'
BACKUP_PASSWORD=''
EXPORT_ROOT="/"
EXPORT_PARAMS='verbose'


function help() {
    echo "
Usage:
    $0 -H hostname -u username -D destination_directory -k days_to_keep -t [export|backup] -P backup_password -l mikrotik_level -e export_params

    Export params: compact verbose hide-sensitive

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
      -u|--username)
        USER="$2"
        shift
        ;;
      -D|--destination)
        DST_DIR="$2"
        shift
        ;;
      -k|--keep)
        KEEP_ON_ROUTER="$2"
        shift
        ;;
      -t|--type)
        BACKUP_TYPE="$2"
        shift
        ;;
      -P|--password)
        BACKUP_PASSWORD="$2"
        shift
        ;;
      -l|--level)
        EXPORT_ROOT="$2"
        shift
        ;;
      -e|--export-params)
        EXPORT_PARAMS="$2"
        shift
        ;;
      *)
        help
        ;;
    esac
    shift # past argument or value
done

DST_FILE=$HOST
SRC_FILE=`date +%F`
OLD_FILE=`date -d "-$KEEP_ON_ROUTER days" +%F`
JOB=""
RUNTIME=`date +%s`

if [[ $BACKUP_TYPE == 'export' ]]; then
    JOB="$EXPORT_ROOT export $EXPORT_PARAMS file=\"$SRC_FILE\"\n/quit\n"
    SRC_FILE=$SRC_FILE.rsc
    DST_FILE=$DST_FILE.rsc
    OLD_FILE=$OLD_FILE.rsc
else
    if [[ $BACKUP_PASSWORD == '' ]]; then
        JOB="/system backup save dont-encrypt=yes name=\"$SRC_FILE\"\n/quit\n"
    else
        JOB="/system backup save password=\"$BACKUP_PASSWORD\" name=\"$SRC_FILE\"\n/quit\n"
    fi
    SRC_FILE=$SRC_FILE.backup
    DST_FILE=$DST_FILE.backup
    OLD_FILE=$OLD_FILE.backup
fi

echo -e $JOB | ssh -T $USER@$HOST > /dev/null

RES=`scp $USER@$HOST:/$SRC_FILE $DST_DIR/$DST_FILE > /dev/null 2>&1 ; echo $?`

if [[ $RES == 0 ]]; then
    echo -n "OK. Deleting $OLD_FILE"
    echo -e "/file remove \"$OLD_FILE\"\n/quit\n" | ssh -T $USER@$HOST > /dev/null
    ((RUNTIME=`date +%s`-RUNTIME))
    echo " | time=${RUNTIME}s;;;;"
    exit 0
else
    ((RUNTIME=`date +%s`-RUNTIME))
    echo "ERROR | time=${RUNTIME}s;;;;"
    exit 1
fi
