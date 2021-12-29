#!/bin/sh

TASK=${1:-"plan"}

STATE_FILE="home-server" # need longer name??

. keep/home-server-setup.sh


cd aws-launch-home-server

# build our remote state config for terraform
# do not change full name, its known by docker
cat ../keep/remote-state.tfvars > full-remote-state.tfvars 
echo "key  =  \"${STATE_FILE}.tfstate\"" >> full-remote-state.tfvars
echo "role_arn  =  \"${role_arn}\"" >> full-remote-state.tfvars
 
echo "-----------------------" 
cat full-remote-state.tfvars
echo "-----------------------" 

# build
docker build --build-arg access_key="${access_key}"\
             --build-arg secret_key="${secret_key}"\
             --build-arg region="${region}"\
             --build-arg role_arn="${role_arn}"\
             -t aws-home-server-launch-builder .

docker run aws-home-server-launch-builder ${TASK}

cd ..



 
