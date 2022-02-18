#!/bin/bash
          
     
## generate new certs or use the old one
sudo service apache2 stop


# format ebs volume only if it has not already been formated                     
if [ "$(sudo file -s ${HOME-EBS-DEVICE} | grep "SGI XFS filesystem" -c)" -ne 1 ]; then
    echo "format new drive ${HOME-EBS-DEVICE}"
    sudo mkfs -t xfs ${HOME-EBS-DEVICE}
fi                     
                     
# only switch to the remote drive if it has not been added to fstab for mounting.                     
if [ "$(grep "home" /etc/fstab -c)" -eq 0 ]; then             
        sudo mkdir -p /mnt/temp_home    
        sudo mount ${HOME-EBS-DEVICE} /mnt/temp_home
        sudo cp /home/* /mnt/temp_home # keep any new files found before we swap over
        sudo umount ${HOME-EBS-DEVICE}
            
        sudo chown admin:admin /etc/fstab    
        sudo echo "${HOME-EBS-DEVICE} /home xfs  defaults,nofail   0    0 " >> /etc/fstab 
        echo "adding to fstab"
else
        echo "already in fstab"        
fi
sudo mount -a  #this may take a little time.
df

ls
ls /home/admin


if [ -f "/home/admin/letsencrypt.zip" ]; then
    if [[ $(find "/home/admin/letsencrypt.zip" -mtime +60 -print) ]]; then
      echo "cert is older than 60 days, time to renew"
      sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
      sudo zip /home/admin/letsencrypt.zip /etc/letsencrypt/* -r 
    else
      echo "use the stored cert"
      sudo unzip -o /home/admin/letsencrypt.zip -d /      
    fi
else
    echo "new cert"
    sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
    sudo zip /home/admin/letsencrypt.zip /etc/letsencrypt/* -r 
fi
 
# now that we have the drive mounted check for old users          
sudo /home/admin/users_restore.sh # if we have no users to restore that is ok       
              

# move cert to cockpit to secure https on 9090
sudo mkdir -p /etc/cockpit/ws-certs.d
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
sudo service apache2 start  

 
# for testing only, remove later.
#sudo apt-get install telnet -y
#sudo apt-get install mailutils -y      
     
    # for testing only
    #         # for testing from the command line, echo "mail body"| mail -s "test mail" TO_USER
                

sudo netstat -tunlp

