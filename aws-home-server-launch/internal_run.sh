#!/bin/bash

TASK=${1:-"plan"}

# apply terraform
if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
    terraform ${TASK} -auto-approve
else
    terraform ${TASK} 
fi

