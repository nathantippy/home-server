#!/bin/bash
          
 
echo "-------------------- set up drives ---------------------"

# format ebs volume only if it has not already been formated                     
if [ "$(sudo file -s ${EBS_DEVICE} | grep "SGI XFS filesystem" -c)" -ne 1 ]; then
    echo "format new drive ${EBS_DEVICE}"
    sudo mkfs -t xfs ${EBS_DEVICE}
fi                     
                     
sudo chown admin:admin /etc/fstab
  
# only switch to the remote drive if it has not been added to fstab for mounting.                     
if [ "$(grep -c 'var xfs' /etc/fstab)" -eq 0 ]; then             

        sudo echo "old fstab did not map the var"
        sudo cat /etc/fstab
    
        sudo mkdir -p /mnt/temp_var
        sudo mount ${EBS_DEVICE} /mnt/temp_var
    
    # not done because this may be breaking the install.   
    if [ ! "$(ls -A /mnt/temp_var)" ]; then
         echo "setup new var folder"
         sudo cp -p -r /var/* /mnt/temp_var # keep any new files found before we swap over
    fi
    
        sudo umount ${EBS_DEVICE}
                                
        sudo echo "${EBS_DEVICE} /var xfs  defaults,nofail   0    0 " >> /etc/fstab 
        echo "adding var to fstab"
        sudo mount -a  #this may take a little time.

else
        echo "var already in fstab"     
        sudo mount -a  #this may take a little time.   
fi

#if [ -f element.tar.gz ]; then           
#    sudo tar -zxvf ./element.tar.gz -C /var/www/html
#    sudo rm element.tar.gz
#fi
     

echo "-------------------------- lets encrypt setup   ------------------------------------"
     
## generate new certs or use the old one
sudo service apache2 stop
if [ -f "/var/archive/letsencrypt.zip" ]; then
    if [[ $(find "/var/archive/letsencrypt.zip" -mtime +80 -print) ]]; then
      echo "cert is older than 80 days, time to renew"
      sudo cd /var/archive
      sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
      sudo zip /var/archive/letsencrypt.zip /etc/letsencrypt/* -r 
    else
      echo "use the stored cert"
      sudo unzip -o /var/archive/letsencrypt.zip -d /      
    fi
else
    echo "new cert"
    sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
    sudo zip /var/archive/letsencrypt.zip /etc/letsencrypt/* -r 
fi
 
  



# if exists then use it.
RESTORE_DATE="latest"

if [ -f /var/archive/nc_html_$${RESTORE_DATE}.tar.gz ] && [ -f /var/archive/nc_db_$${RESTORE_DATE}.sql ]; then

    echo "-------------------------- restore the last backup ----------------------------------"
    #  restore data 
    #sudo rm -r /var/www/html/nextcloud/
    sudo mkdir -p /var/www/html/nextcloud/
    echo "sudo tar -xpzf /var/archive/nc_html_$${RESTORE_DATE}.tar.gz -C /var/www/html/nextcloud/"
    sudo tar -xpzf /var/archive/nc_html_$${RESTORE_DATE}.tar.gz -C /var/www/html/nextcloud/
    sudo chown -R www-data:www-data /var/www/html
    echo "done with restore of nextcloud folder"

    # restore database
    ###echo "DROP DATABASE nextcloud" | sudo -u postgres psql 
    cat /var/archive/nc_db_$${RESTORE_DATE}.sql | sudo -u postgres psql
    echo "done with postgres restore"

else 
    echo "-------------------------- fresh install ----------------------------------"
    ###############
    wget https://download.nextcloud.com/server/releases/nextcloud-19.0.13.zip 
    mv nextcloud-19.0.13.zip nextcloud.zip
    if [ -f nextcloud.zip ]; then
             sudo rm -R /var/www/html/nextcloud
             sudo unzip -o nextcloud.zip -d /var/www/html/
             rm nextcloud.zip   
    fi
    ###############
    cat pg_setup.sql | sudo -u postgres psql && rm pg_setup.sql

fi
# set rights for the nextcloud
sudo chown -R www-data:www-data /var/www/html/nextcloud/ && sudo chmod -R 755 /var/www/html/nextcloud/


sudo systemctl start apache2

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:data-fingerprint


sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off

# ensure caches match what we have on the drive
sudo -u www-data php /var/www/html/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/html/nextcloud/occ files:scan-app-data
# check for Nextcloud updates
echo "Nextcloud apps are checked for updates..."
sudo -u www-data php /var/www/html/nextcloud/occ app:update --all
  
 
# now that we have the drive mounted check for old users      
#testing did this corrupt our admin..    

   
              

# move cert to cockpit to secure https on 9090
#sudo mkdir -p /etc/cockpit/ws-certs.d
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/cert.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.crt
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/fullchain.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.crt
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/privkey.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.key


# 1. fix cockpit admin for adding users
# 2. start nextcloud install with mail client . (roundcube sucks)
# 3. certs for cockpit
# 4. certs for apache


                #    check db works and version:   sudo -u postgres psql -c "SELECT version();"
                     #                                  pg_lsclusters
                     #                                  sudo service postgresql status

sudo systemctl stop dovecot.service #must be stopped to start postfix
# restart to pick up the certs
sudo systemctl restart postfix
sudo systemctl restart dovecot.service

sudo systemctl start apache2
sudo systemctl enable apache2
  
#sudo service apache2 start  


# old
#sudo sed -i "s|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/letsencrypt/live/javanut.com/fullchain.pem|g" /etc/apache2/sites-available/default-ssl.conf
#sudo sed -i "s|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/letsencrypt/live/javanut.com/privkey.pem|g" /etc/apache2/sites-available/default-ssl.conf
			

 
# for testing only, remove later.
#sudo apt-get install telnet -y
#sudo apt-get install mailutils -y      
     
    # for testing only
    #         # for testing from the command line, echo "mail body"| mail -s "test mail" TO_USER


# debug nextcloud
# tail -f /var/www/html/data/nextcloud.log | jq



sudo netstat -tunlp

# restore last user state and all their email
sudo /home/admin/users_restore.sh # if we have no users to restore that is ok    


# start user backup process, every 6 hours at 3 min after the top
crontab -l > crontab_new 
if [ "$(cat crontab_new | grep -c 'users_backup')" -eq "0" ]; then
	echo "3 */6 * * * /home/admin/users_backup.sh" >> crontab_new
	crontab crontab_new
fi

