#!/bin/sh

TASK=${1:-"plan"}


export LOCAL_FOLDER=$PWD/keep/  # exports the pub/pem files for connecting

# --user "$(id -u):$(id -g)" 
docker run --rm -v ${LOCAL_FOLDER}:/exports aws-home-server-build-launch ${TASK}



#sudo chmod 400 keep/home-server-ssh.pem # must be set or we can not use this to log in with SSH


# sudo ssh -i "./keep/home-server-ssh.pem" admin@ec2-3-139-30-133.us-east-2.compute.amazonaws.com


 
echo "visit: http://javanut.com/roundcube/installer/"

