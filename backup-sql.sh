#!/usr/bin/bash


# check if user if root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root user"
    exit 1
fi

# check if ccrypt apt is installed.
if ! command -v ccrypt &> /dev/null
then
    echo "ccrypt could not be found. install it using apt."
    exit 1
fi

 . ./config.sh

check_if_was_successful() {
    if [[ $? != 0 ]]; then
        echo "$1 failed ..."  && exit 1
    else
        echo "$1 is Done"
    fi
}

send_via_scp() {
    scp -P 23 $BACKUP.cpt $storageBoxName@$storageBoxURL:$FILE_NAME.cpt
}


DATE=$(date +%Y-%m-%d-%H-%M-%S)
mkdir -p $HOME/db_backups

FILE_NAME=FEXDB-$DATE.sql
DEST=$HOME/db_backups/$DATE
BACKUP=$DEST/FEXDB-$DATE.sql
echo "backup file will be located at: $DEST with the name: $FILE_NAME"

mkdir -p "$DEST"

mysqldump -u root -p --single-transaction farhad > $BACKUP
check_if_was_successful mysqlDump

ccrypt -e -E secret -r $BACKUP
check_if_was_successful encryption

send_via_scp
check_if_was_successful send_via_scp