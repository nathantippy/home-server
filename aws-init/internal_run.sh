#!/bin/bash

TASK=${1:-"plan"}

export TF_VAR_access_key="${ACCESS_KEY}"
export TF_VAR_secret_key="${SECRET_KEY}"

# copy in old files for state
if [ -f "exports/aws-init.tfstate" ]; then
    cp exports/aws-init.tfstate aws-init.tfstate
fi
if [ -f "exports/home-server-setup.sh" ]; then
    cp exports/home-server-setup.sh home-server-setup.sh
fi
if [ -f "exports/remote-state.tfvars" ]; then
    cp exports/remote-state.tfvars remote-state.tfvars
fi

# apply terraform
if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
    terraform ${TASK} -state=aws-init.tfstate -auto-approve
else
    terraform ${TASK} -state=aws-init.tfstate
fi

# move out the artfiacts for use later
mv home-server-setup.sh exports/home-server-setup.sh
mv remote-state.tfvars exports/remote-state.tfvars
mv aws-init.tfstate exports/aws-init.tfstate





