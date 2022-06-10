#!/bin/bash
         
echo "-------------------------- lets encrypt refresh ------------------------------------"
     
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





