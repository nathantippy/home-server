#!/bin/sh


terraform apply -var="access_key=${access_key}" -var="secret_key=${secret_key}" -var="role_arn=${role_arn}" -auto-approve 



