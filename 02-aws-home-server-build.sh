#!/bin/sh

DOMAIN=${1:-"javanut.com"} # TODO: set to yourdomain.com
DNS=${2:-"external"} # aws OR external

if [ "yourdomain.com" == "${DOMAIN}" ]; then
    read -e -p "Enter desired domain (you must already own this domain):" -i "yourdomain.com" DOMAIN
fi

echo "your domain: ${DOMAIN}"

# these are specific to each domain so we can run multple servers for differnt domains in the same account
PUBLIC_IP_STATE_FILE="home-server-${DOMAIN//./-}-public-ip"
RUN_INSTANCE_STATE_FILE="home-server-${DOMAIN//./-}-run-instance" 

echo "public_ip state: ${PUBLIC_IP_STATE_FILE}"
echo "run_instance state: ${RUN_INSTANCE_STATE_FILE}"


if [ -f keep.bak ]; then
    unzip -o keep.bak
fi

. keep/home-server-setup.sh

cd base-builder-image
    docker build -t base-builder-image .
cd ..

cd aws-home-server

# build our remote state config for terraform
# do not change full name, its known by docker
cat ../keep/remote-state.tfvars > remote-state.tfvars 
echo "key  =  \"${PUBLIC_IP_STATE_FILE}.tfstate\"" >> remote-state.tfvars
echo "role_arn  =  \"${role_arn}\"" >> remote-state.tfvars
mv remote-state.tfvars public_ip
 
cat ../keep/remote-state.tfvars > remote-state.tfvars 
echo "key  =  \"${RUN_INSTANCE_STATE_FILE}.tfstate\"" >> remote-state.tfvars
echo "role_arn  =  \"${role_arn}\"" >> remote-state.tfvars
mv remote-state.tfvars run_instance 
 

# build
docker build --build-arg access_key="${access_key}"\
             --build-arg secret_key="${secret_key}"\
             --build-arg region="${region}"\
             --build-arg role_arn="${role_arn}"\
             --build-arg domain="${DOMAIN}"\
             --build-arg dns_impl="${DNS}"\
             --build-arg user="$(id -u):$(id -g)"\
             -t aws-home-server-build-launch .

docker run --rm aws-home-server-build-launch instructions

cd ..



 
