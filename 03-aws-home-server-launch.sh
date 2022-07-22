#!/bin/sh

TASK=${1:-"plan"}
DOMAIN=${2:-"domain"}


export LOCAL_FOLDER=$PWD/keep/  # exports the pub/pem files for connecting

# --user "$(id -u):$(id -g)" 
docker run --rm -v ${LOCAL_FOLDER}:/exports aws-${DOMAIN}-server-build-launch ${TASK}

#sudo chmod 400 keep/home-server-${replace(var.domain,".","-")}-ssh.pem # must be set or we can not use this to log in with SSH


# sudo ssh -i "./keep/home-server-${replace(var.domain,".","-")}-ssh.pem" admin@ec2-3-139-30-133.us-east-2.compute.amazonaws.com

# you may want to cache is it in the setup?
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/caching_configuration.html#recommendations-based-on-type-of-deployment
 
