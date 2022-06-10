#!/bin/bash

#backup all the users, we do not backup /home since its on a removable drive volume and backed up with snapshots
#run by crontab to ensure all email etc is captured on the remote drive.

#sudo mkdir -p /var/archive/db

# backup user data stored in nextcloud
#sudo -u postgres pg_dump nextcloud | sudo tee /var/archive/db/nextcloud_backup.sql

# store the database configuration
#rsync -a --info=progress2 --exclude="lost+found" /etc/postgresql/ /var/archive/db/postgresql/
#rsync -a --info=progress2 --exclude="lost+found" /etc/postgresql-common/ /var/archive/db/postgresql-common/

TARGET_FOLDER="/mnt/second_drive/etc_users"

# *Debian and Ubuntu Linux* : Default is 1000 and upper limit is 29999   (/etc/adduser.conf).
export UGIDLIMIT=1000
sudo awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > ${TARGET_FOLDER}/passwd.mig
sudo awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > ${TARGET_FOLDER}/group.mig
sudo awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | sudo tee - |egrep -f - /etc/shadow > ${TARGET_FOLDER}/shadow.mig
sudo cp /etc/gshadow ${TARGET_FOLDER}/gshadow.mig

#old home copy no longer needed since we backup this elsewhere.
#mkdir -p /var/archive/users/home
#rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /home/ /var/archive/users/home/




