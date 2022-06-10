#!/bin/bash

#restore all the users

TARGET_FOLDER="/mnt/second_drive/etc_users"

#Now restore passwd and other files in /etc/
if [ -f "${TARGET_FOLDER}/passwd.mig" ]; then
    #home folder restore is done by external code, this just does the accounts
    #rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" --exclude="admin/.ssh" /var/archive/users/home/ /home/
    cat ${TARGET_FOLDER}/passwd.mig >> /etc/passwd
fi

if [ -f "${TARGET_FOLDER}/group.mig" ]; then
    cat ${TARGET_FOLDER}/group.mig >> /etc/group
fi

if [ -f "${TARGET_FOLDER}/shadow.mig" ]; then
    cat ${TARGET_FOLDER}/shadow.mig >> /etc/shadow
fi

if [ -f "${TARGET_FOLDER}/gshadow.mig" ]; then
    cp ${TARGET_FOLDER}/gshadow.mig /etc/gshadow
fi



