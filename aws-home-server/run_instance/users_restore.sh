#!/bin/bash

#restore all the users

#Now restore passwd and other files in /etc/
if [ -f "/var/archive/users/passwd.mig" ]; then
    rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" --exclude="admin/.ssh" /var/archive/users/home/ /home/
    cat /var/archive/users/passwd.mig >> /etc/passwd
fi

if [ -f "/var/archive/users/group.mig" ]; then
    cat /var/archive/users/group.mig >> /etc/group
fi

if [ -f "/var/archive/users/shadow.mig" ]; then
    cat /var/archive/users/shadow.mig >> /etc/shadow
fi

if [ -f "/var/archive/users/gshadow.mig" ]; then
    cp /var/archive/users/gshadow.mig /etc/gshadow
fi

# restore the database configuration
#if [ -d "/var/archive/db/postgresql/" ]; then
#    rsync -a --info=progress2 --exclude="lost+found" /var/archive/db/postgresql/ /etc/postgresql/
#fi
#if [ -d "/var/archive/db/postgresql-common/" ]; then
#    rsync -a --info=progress2 --exclude="lost+found" /var/archive/db/postgresql-common/ /etc/postgresql-common/
#fi


