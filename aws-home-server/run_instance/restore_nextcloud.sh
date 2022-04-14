#!/bin/bash
RESTORE_DATE=${1:-"UNKNOWN"}

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --on

sudo systemctl stop apache2


#sudo rm -r /var/www/html/nextcloud/
sudo mkdir -p /var/www/html/nextcloud/
echo "sudo tar -xpzf /var/archive/nc_html_${RESTORE_DATE}.tar.gz -C /var/www/html/nextcloud/"
sudo tar -xpzf /var/archive/nc_html_${RESTORE_DATE}.tar.gz -C /var/www/html/nextcloud/
sudo chown -R www-data:www-data /var/www/html
echo "done with restore of nextcloud folder"

###echo "DROP DATABASE nextcloud" | sudo -u postgres psql 

#mysql -h localhost -uroot -pnextcloud -e "DROP DATABASE nextcloud"
#cat pg_setup.sql | sudo -u postgres psql 
#mysql -h localhost -uroot -pnextcloud -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
#mysql -h localhost -uroot -pnextcloud -e "GRANT ALL PRIVILEGES on nextcloud.* to nextcloud@localhost"
cat /var/archive/nc_db_${RESTORE_DATE}.sql | sudo -u postgres psql 
#mysql -h localhost -unextcloud -pnextcloud nextcloud < /home/ubuntuusername/ncdb_1.sql
echo "done with postgres restore"

sudo systemctl start apache2

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:data-fingerprint


sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off

# ensure caches match what we have on the drive
sudo -u www-data php /var/www/html/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/html/nextcloud/occ files:scan-app-data
# check for Nextcloud updates
echo "Nextcloud apps are checked for updates..."
sudo -u www-data php /var/www/html/nextcloud/occ app:update --all


