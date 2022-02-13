#!/bin/bash

#restore all the users

#Now restore passwd and other files in /etc/
if [ -f "/home/admin/users/passwd.mig" ]; then
    cat /home/admin/users/passwd.mig >> /etc/passwd
fi

if [ -f "/home/admin/users/group.mig" ]; then
    cat /home/admin/users/group.mig >> /etc/group
fi

if [ -f "/home/admin/users/shadow.mig" ]; then
    cat /home/admin/users/shadow.mig >> /etc/shadow
fi

if [ -f "/home/admin/users/gshadow.mig" ]; then
    cp /home/admin/users/gshadow.mig /etc/gshadow
fi


