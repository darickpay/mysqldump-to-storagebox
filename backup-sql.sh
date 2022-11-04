#!/usr/bin/bash

# check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo "rclone could not be found. install it using apt."
    exit 1
fi

# check if rclone is configured
if [[ ! -f "$HOME/.config/rclone/rclone.conf" ]]; then
	echo "rclone needs to be configured. check out documentation https://rclone.org/commands/rclone_config_file/"
	exit 1
fi

MYSQL_PASSWORD_NO=false
# check if mysqldump user configured
if [[ "$1" == *"-"* && "$1" == *"m"* ]]; then
	if [[ ! -f "$HOME/.my.cnf" ]]; then
		echo "mysqldump needs to be configured. check out this link: https://stackoverflow.com/questions/9293042/how-to-perform-a-mysqldump-without-a-password-prompt"
		exit 1
	fi
else
	MYSQL_PASSWORD_NO=true
fi

# check if user is root
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
		echo "$1 failed ..."
		# check if the admin wants to be alerted if something got wrong.
		if [[ "$1" == *"-"* && "$1" == *"a"* ]]; then
			curl $ALERT_ENDPOINT &> /dev/null
			check_if_was_successful alert
		fi
		exit 1
	else
			echo "$1 is Done"
	fi
}


remove_file_from_local() {
    rm -rf $DEST
}


send_via_rclone() {
	# create monthly archive directory
	ARCHIVE_DIR=$BACKUP_DESTINATION/$FOLDER_DATE
	rclone mkdir $ARCHIVE_DIR
	echo "storage archive directory is: $ARCHIVE_DIR"
	# copy to archive destination
	DEST_FILE=$ARCHIVE_DIR/$FILE_NAME
	rclone -P copyto $BACKUP $DEST_FILE
	echo "backup file located at: $DEST_FILE"
}


DATE=$(date +%Y-%m-%d-%H-%M-%S)
FOLDER_DATE=$(date +%Y-%m)
mkdir -p $HOME/db_backups

FILE_NAME=FEXDB-$DATE.sql
DEST=$HOME/db_backups/$DATE
BACKUP=$DEST/FEXDB-$DATE.sql
echo "backup file will be located at: $DEST with the name: $FILE_NAME"

mkdir -p "$DEST"

if [ $MYSQL_PASSWORD_NO = true ]; then
	mysqldump -u $MYSQL_USER -p --single-transaction farhad > $BACKUP
else
	mysqldump -u $MYSQL_USER --single-transaction farhad > $BACKUP
fi
check_if_was_successful mysqlDump


# check if encryption config provided
if [[ "$1" == *"-"* && "$1" == *"e"* ]]; then
	ccrypt -e -E SECRET -r $BACKUP
	check_if_was_successful encryption
	# after encryption file name must be changed.
	FILE_NAME=FEXDB-$DATE.sql.cpt
	BACKUP=$DEST/FEXDB-$DATE.sql.cpt
fi

send_via_rclone
check_if_was_successful send_via_rclone

# check if local file removal config provided
if [[ "$1" == *"-"* && "$1" == *"r"* ]]; then
	remove_file_from_local
	check_if_was_successful remove_file_from_local
	echo "file removed from local"
fi