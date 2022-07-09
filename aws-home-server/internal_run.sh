#!/bin/bash

TASK=${1:-"plan"}


if [ "archive" == "${TASK}" ]; then
            
        ls . -hal    #  -chdir=\"./run_instance\"   run_instance
            
        export BACKUP_BUCKET="$(terraform -chdir=./run_instance output -raw backup-bucket-id)"
         
       . ./role_assume.sh server-builder-role 14400 us-east-2 internal_run

        echo "aws s3 sync s3://${BACKUP_BUCKET} s3://${BACKUP_BUCKET}-archive --region ${TF_VAR_region} --output json"
        aws s3 sync s3://${BACKUP_BUCKET} s3://${BACKUP_BUCKET}-archive --region ${TF_VAR_region} --output json

       . ./role_release.sh
else
    if [ "nextcloud" == "${TASK}" ]; then
        
            
       . ./role_assume.sh server-builder-role 14400 us-east-2 internal_run
            
            SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id home_server/${TF_VAR_domain} --region ${TF_VAR_region} --query SecretString --output text)
            echo "${SECRET_JSON}"
                
            echo "open the browser to https://${TF_VAR_domain}/nextcloud and autofill"
            echo "-------------------------------------------------"
            echo "admin account, username:  admin"
            echo "admin account, password:  $(echo "${SECRET_JSON}" | jq -r '.admin_pass')"
            echo "data folder:   /mnt/second_drive/var/www/html/nextcloud/data" # already populated
            echo "configured the database: select PostgreSQL"
            echo "database user:      nextcloud"
            echo "database password: $(echo "${SECRET_JSON}" | jq -r '.nc_pg_pass')"
            echo "database name:      nextcloud"
            echo "localhost"  # already populated
        
       . ./role_release.sh
        
    else

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
            export 
            
	        #move keys out so we can use this to connect
	        cp home-server-ssh.pub exports/home-server-ssh-${TF_VAR_domain//./-}.pub
	        cp home-server-ssh exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	        chown ${USER} exports/home-server-ssh-${TF_VAR_domain//./-}.pub
	        chown ${USER} exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	        chmod 400 exports/home-server-ssh-${TF_VAR_domain//./-}.pem
	        
	        . ./role_assume.sh server-builder-role 14400 us-east-2 internal_run
	           
            # check if secret exists
            echo "aws secretsmanager describe-secret --secret-id home_server/${TF_VAR_domain} --region ${TF_VAR_region} --output json"
            aws secretsmanager describe-secret --secret-id home_server/${TF_VAR_domain} --region ${TF_VAR_region} --output json || exit $?
            FOUND_IT=$(aws secretsmanager describe-secret --secret-id home_server/${TF_VAR_domain} --region ${TF_VAR_region} --output json 2>&1 | grep -c 'AWSCURRENT')
            if [ "${FOUND_IT}" -eq "0" ]; then
                echo "DO NOT use old secret home_server/${TF_VAR_domain}  ${FOUND_IT}"
	            export TF_VAR_use_old_secret=false
	            
	            read -p "Are you sure? " -n 1 -r
                echo    # (optional) move to a new line
                if [[ ! $REPLY =~ ^[Yy]$ ]]
                then
                    exit 1
                fi	            
            else
                echo "ATTEMPT to use old secret home_server/${TF_VAR_domain}  ${FOUND_IT}"
	            export TF_VAR_use_old_secret=true
            fi

            . ./role_release.sh
	            
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
	            TF_PLUGIN_CACHE_DIR=../terraform.d/plugin-cache terraform ${TASK} -auto-approve
	        else
	            cd run_instance
	            TF_PLUGIN_CACHE_DIR=../terraform.d/plugin-cache terraform ${TASK} 
	        fi
	        
	        
	        
	        
            
        fi
    fi
fi

