#!/bin/sh

ACCESS_KEY=${1:-"unknown"}
SECRET_KEY=${2:-"unknown"}

if [ "unknown" == "${ACCESS_KEY}" ]; then
    read -e -p "Enter aws_access_key_id:" ACCESS_KEY
fi
if [ "unknown" == "${SECRET_KEY}" ]; then
    read -e -p "Enter aws_secret_access_key:" SECRET_KEY
fi

export LOCAL_FOLDER=$PWD/keep/

cd aws-init

# build
docker build -t aws-init-builder .

docker run -v ${LOCAL_FOLDER}:/exports -e ACCESS_KEY="${ACCESS_KEY}" -e SECRET_KEY="${SECRET_KEY}" aws-init-builder apply

cd ..



 
