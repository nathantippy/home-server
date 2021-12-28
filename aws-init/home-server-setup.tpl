#!/bin/sh

export access_key="${access_key}"
export secret_key="${secret_key}"
export role_arn  ="${role_arn}"



#terraform apply -var="access_key=${access_key}" -var="secret_key=${secret_key}" -var="role_arn=${role_arn}" -state=init.tfstate -auto-approve







