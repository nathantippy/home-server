#!/bin/bash

TASK=${1:-"plan"}

export TF_VAR_access_key="${ACCESS_KEY}"
export TF_VAR_secret_key="${SECRET_KEY}"

if [ -f "exports/init.tfstate" ]; then
    cp exports/init.tfstate init.tfstate
fi

if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
    terraform ${TASK} -state=init.tfstate -auto-approve
else
    terraform ${TASK} -state=init.tfstate
fi

mv next_bash.sh exports/next_bash.sh
mv remote-state.tfvars exports/remote-state.tfvars
mv init.tfstate exports/init.tfstate





