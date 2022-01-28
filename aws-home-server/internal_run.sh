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
	    echo ""
		echo "NEXT STEP:"
		echo "           If this is the first run or the IP has changed, add the following DNS entries to your external DNS provider."
	
		echo "             MX Record     ${TF_VAR_email_domain}         mail.${TF_VAR_email_domain} "
		echo "             MX Record     *.${TF_VAR_email_domain}       mail.${TF_VAR_email_domain} "		  	
		echo "             A Record      ${TF_VAR_email_domain}         $(terraform -chdir=./public_ip output -raw ip)  "
		echo "             A Record      mail.${TF_VAR_email_domain}    $(terraform -chdir=./public_ip output -raw ip)  "
		echo "             A Record      *.${TF_VAR_email_domain}       $(terraform -chdir=./public_ip output -raw ip)   "
			
		echo "           Once updated it make take up to 3 hours for the DNS records to propagate."	
		echo "           After waiting the next step should be run with:   03-aws-home-server-build.sh"
	fi
    
else
	#move keys out so we can use this to connect
	cp home-server-ssh.pub exports/home-server-ssh.pub
	cp home-server-ssh exports/home-server-ssh.pem
	chown ${USER} exports/home-server-ssh.pub
	chown ${USER} exports/home-server-ssh.pem
	chmod 400 exports/home-server-ssh.pem
	
	# apply terraform
	if [ "apply" == "${TASK}" ] || [ "destroy" == "${TASK}" ]; then   
	    cd run_instance
	    terraform ${TASK} -auto-approve
	else
	    cd run_instance
	    terraform ${TASK} 
	fi
    
fi



