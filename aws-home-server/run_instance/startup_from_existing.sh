#!/bin/bash
   
echo "--- ensure drive is formatted and mounted ---"
bash ./startup_init.sh   
         
bash ./startup_letsencrypt_refresh.sh



# TODO: shutdown should have mantenance mode on before we shut down. TODO: depends on clean shutdown script.

sudo systemctl stop dovecot.service #must be stopped to start postfix
# restart to pick up the certs
sudo systemctl restart postfix
sudo systemctl restart dovecot.service

sudo systemctl start apache2
sudo systemctl enable apache2

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:data-fingerprint
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off

# ensure caches match what we have on the drive
sudo -u www-data php /var/www/html/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/html/nextcloud/occ files:scan-app-data
# check for Nextcloud updates
echo "Nextcloud apps are checked for updates..."
sudo -u www-data php /var/www/html/nextcloud/occ app:update --all
  

#sudo systemctl start apache2
  
 
# for testing only, remove later.
#sudo apt-get install telnet -y
#sudo apt-get install mailutils -y      
     
    # for testing only
    #         # for testing from the command line, echo "mail body"| mail -s "test mail" TO_USER


# debug nextcloud
# tail -f /var/www/html/data/nextcloud.log | jq

sudo netstat -tunlp

crontab -l > crontab_new 
if [ "$(cat crontab_new | grep -c 'cron_backup.sh')" -eq "0" ]; then
	echo "1 1 * * * /home/admin/cron_backup.sh" >> crontab_new
	crontab crontab_new
	rm -f crontab_new
	sudo systemctl restart cron
fi
echo "----- crontab list -----"
crontab -l




