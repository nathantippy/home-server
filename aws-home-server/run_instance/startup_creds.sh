#!/bin/bash


if [ -f "letsencrypt.zip" ]; then
    if [[ $(find "letsencrypt.zip" -mtime +60 -print) ]]; then
      echo "cert is older than 60 days, time to renew"
      sudo service apache2 stop
      sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
      sudo zip letsencrypt.zip /etc/letsencrypt/* -r 
      sudo service apache2 start   
    else
      echo "use the stored cert"
      sudo unzip -o letsencrypt.zip      
    fi
else
    sudo service apache2 stop
    sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
    sudo zip letsencrypt.zip /etc/letsencrypt/* -r 
    sudo service apache2 start
fi




