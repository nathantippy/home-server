#!/bin/bash

TASK=${1:-"plan"}

#move keys out so we can use this to connect
cp home-server-ssh.pub exports/home-server-ssh.pub
cp home-server-ssh exports/home-server-ssh.pem
chown ${USER} exports/home-server-ssh.pub
chown ${USER} exports/home-server-ssh.pem
chmod 400 exports/home-server-ssh.pem

# apply terraform
if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
    terraform ${TASK} -auto-approve
else
    terraform ${TASK} 
fi



