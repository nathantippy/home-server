#!/bin/bash
          
                     #    check db works and version:   sudo -u postgres psql -c "SELECT version();"
                     #                                  pg_lsclusters
                     #                                  sudo service postgresql status
                     

  
  sudo mv main.cf /etc/postfix/main.cf
  sudo mv 10-master.conf /etc/dovecot/conf.d/10-master.conf
  sudo mv 10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf
  sudo mv config.inc.php /var/www/html/roundcube/config/config.inc.php
              

sudo service apache2 stop
if [ -f "letsencrypt.zip" ]; then
    if [[ $(find "letsencrypt.zip" -mtime +60 -print) ]]; then
      echo "cert is older than 60 days, time to renew"
      sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
      sudo zip letsencrypt.zip /etc/letsencrypt/* -r 
    else
      echo "use the stored cert"
      sudo unzip -o letsencrypt.zip -d /      
    fi
else
    sudo certbot certonly --standalone --register-unsafely-without-email -d ${TF-DOMAIN}
    sudo zip letsencrypt.zip /etc/letsencrypt/* -r 
fi

# move cert to cockpit to secure https on 9090
sudo mkdir -p /etc/cockpit/ws-certs.d
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/cert.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.crt
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/fullchain.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.crt
#sudo cp /etc/letsencrypt/live/${TF-DOMAIN}/privkey.pem /etc/cockpit/ws-certs.d/${TF-DOMAIN-NAME}.key

# sudo passwd admin  - we can use this to set the password for admin to something very long
# 



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

