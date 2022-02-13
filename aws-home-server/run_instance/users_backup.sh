#!/bin/bash

#backup all the users, we do not backup /home since its on a removable drive volume and backed up with snapshots

# *Debian and Ubuntu Linux* : Default is 1000 and upper limit is 29999   (/etc/adduser.conf).
export UGIDLIMIT=1000
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > /home/admin/users/passwd.mig
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > /home/admin/users/group.mig
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee – |egrep -f – /etc/shadow > /home/admin/users/shadow.mig
cp /etc/gshadow /home/admin/users/gshadow.mig









