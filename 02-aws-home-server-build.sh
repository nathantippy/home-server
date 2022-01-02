#!/bin/sh


STATE_FILE="home-server" # need longer name??

. keep/home-server-setup.sh

if [ -f keep.bak ]; then
    unzip -o keep.bak
fi

cd base-builder-image
    docker build -t base-builder-image .
cd ..

cd aws-home-server

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
             --build-arg user="$(id -u):$(id -g)"\
             -t aws-home-server-build-launch .

cd ..



 
