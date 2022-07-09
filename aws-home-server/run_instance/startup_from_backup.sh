#!/bin/bash
   
# do not run as sudo.
   
   
echo "--- ensure drive is formatted and mounted ---"
sudo bash ./startup_init.sh   
         
echo "--- restore all "
sudo bash ./full_restore.sh
   
# we must restore and check for valid certificates before we restart this old backup.   
bash ./startup_letsencrypt_refresh.sh
  
sudo systemctl stop dovecot.service #must be stopped to start postfix
# restart to pick up the certs!!
sudo systemctl restart postfix
sudo systemctl restart dovecot.service
sudo service postgresql status  
  
# ensure apache2 is up in running.
sudo systemctl restart apache2
  
 
# for testing only, remove later.
#sudo apt-get install telnet -y
#sudo apt-get install mailutils -y      
     
    # for testing only
    #         # for testing from the command line, echo "mail body"| mail -s "test mail" TO_USER


# debug nextcloud
# tail -f /var/www/html/data/nextcloud.log | jq


# start user backup process, every night at 1:01
sudo netstat -tunlp

crontab -l > crontab_new 
if [ "$(cat crontab_new | grep -c 'cron_backup.sh')" -eq "0" ]; then
	echo "1 1 * * * /home/admin/cron_backup.sh" >> crontab_new
	crontab crontab_new
	rm -f crontab_new
	sudo systemctl restart cron
	# required to sync with PAM
	sudo service cron restart
fi
echo "----- crontab list -----"
crontab -l

