#!/bin/bash

TASK=${1:-"plan"}

#move keys out so we can use this to connect
cp minecraft-server-ssh.pub exports/minecraft-server-ssh.pub
cp minecraft-server-ssh exports/minecraft-server-ssh.pem
chown ${USER} exports/minecraft-server-ssh.pub
chown ${USER} exports/minecraft-server-ssh.pem
chmod 400 exports/minecraft-server-ssh.pem

# apply terraform
if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
    terraform ${TASK} -auto-approve
else
    terraform ${TASK} 
fi



