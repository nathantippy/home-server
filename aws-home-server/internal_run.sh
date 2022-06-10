#!/bin/bash

TASK=${1:-"plan"}


if [ "instructions" == "${TASK}" ]; then
        
    if [ "aws" == "${TF_VAR_dns_impl}" ]; then
	    echo ""
		echo "NEXT STEP:"
		echo "           If this is the first run it make take up to 3 hours for the new IP associated with your domain to propagate everywhere."
		echo ""
	fi
	
	if [ "external" == "${TF_VAR_dns_impl}" ]; then
	    STATIC_IP="$(terraform -chdir=./public_ip output -raw ip)"
	    echo ""
		echo "NEXT STEP:"
		echo "           If this is the first run or the IP has changed, add the following DNS entries to your external DNS provider."
	
		echo "             MX Record     ${TF_VAR_domain}         mail.${TF_VAR_domain} "
		echo "             MX Record     *.${TF_VAR_domain}       mail.${TF_VAR_domain} "		  	
		echo "             A Record      ${TF_VAR_domain}         ${STATIC_IP}  "
		echo "             A Record      mail.${TF_VAR_domain}    ${STATIC_IP}  "
		echo "             A Record      *.${TF_VAR_domain}       ${STATIC_IP}   "
			
		echo "           Once updated it make take up to 3 hours for the DNS records to propagate."	
		echo "           After waiting the next step should be run with:   03-aws-home-server-build.sh"
	fi
    
else
	#move keys out so we can use this to connect
	cp home-server-ssh-${TF_VAR_domain}.pub exports/home-server-ssh-${TF_VAR_domain//./-}.pub
	cp home-server-ssh-${TF_VAR_domain} exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	chown ${USER} exports/home-server-ssh-${TF_VAR_domain//./-}.pub
	chown ${USER} exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	chmod 400 exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	
# check if secret exists
aws secretsmanager describe-secret --secret-id home_server/${TF_VAR_domain} --output json
FOUND_IT=$(aws secretsmanager describe-secret --secret-id home_server/${TF_VAR_domain} --output json 2>&1 | grep -c 'AWSCURRENT')
if [ "${FOUND_IT}" -eq "0" ]; then
    echo "DO NOT use old secret home_server/${TF_VAR_domain}  ${FOUND_IT}"
	export TF_VAR_use_old_secret=false
else
    echo "ATTEMPT to use old secret home_server/${TF_VAR_domain}  ${FOUND_IT}"
	export TF_VAR_use_old_secret=true
fi

	
#variable "root_volume_iops" {
#	default = 3000  # 3000 is free, max is 16000 - not used for sc1
#}
#variable "root_volume_throughput" {
# 	default = 125  # 125 MB/s is free, max is 1000 - not used for sc1
#}
#variable "root_volume_type" {          #
#	default = "gp3" 
#}
#variable "root_volume_size" {
# 	default = 48  # 8G is the minimum but we need room for lots of email, 125 is smallest for sc1	
#}
	
	# apply terraform
	if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
	   
	    if [ "destroy" == "${TASK}" ]; then   
	    
	        echo "we need to move nextlcoud into maint mode: TODO: CAN WE DO THIS IN TF?"
	    
	    fi
	
	    cd run_instance
	    terraform ${TASK} -auto-approve
	else
	    cd run_instance
	    terraform ${TASK} 
	fi
    
fi



