#!/bin/bash

#backup all the users, we do not backup /home since its on a removable drive volume and backed up with snapshots
#run by crontab to ensure all email etc is captured on the remote drive.

sudo mkdir -p /var/archive/db

# backup user data stored in nextcloud
#sudo -u postgres pg_dump nextcloud | sudo tee /var/archive/db/nextcloud_backup.sql

# store the database configuration
#rsync -a --info=progress2 --exclude="lost+found" /etc/postgresql/ /var/archive/db/postgresql/
#rsync -a --info=progress2 --exclude="lost+found" /etc/postgresql-common/ /var/archive/db/postgresql-common/


# *Debian and Ubuntu Linux* : Default is 1000 and upper limit is 29999   (/etc/adduser.conf).
export UGIDLIMIT=1000
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > /var/archive/users/passwd.mig
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > /var/archive/users/group.mig
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee - |egrep -f - /etc/shadow > /var/archive/users/shadow.mig
cp /etc/gshadow /var/archive/users/gshadow.mig
mkdir -p /var/archive/users/home
rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /home/ /var/archive/users/home/








