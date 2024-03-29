#!/bin/bash

############################################################################
## /mnt/second_drive/etc_users
############################################################################
echo "restore /mnt/second_drive/etc_users -------------------------------------------------"
sudo duplicati-cli restore s3://${TF_BACKUP_BUCKET}/etc_users --overwrite=true --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --restore-permissions=true --symlink-policy=follow

sudo bash ./users_restore.sh

############################################################################
## /mnt/second_drive/home
############################################################################
echo "restore /mnt/second_drive/home --------------------------------------------------------"
# TODO: old .ssh may need to be kept for access!!! simple rename command?
sudo duplicati-cli restore s3://${TF_BACKUP_BUCKET}/home --overwrite=true --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --restore-permissions=true --symlink-policy=follow

############################################################################
## /mnt/second_drive/var
############################################################################
echo "restore /mnt/second_drive/var -------------------------------------------------------------"

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --on
sudo systemctl stop apache2

# we can add --version=<int> to restore a specific backup.
sudo duplicati-cli restore s3://${TF_BACKUP_BUCKET}/var --overwrite=true --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --restore-permissions=true --symlink-policy=follow



#sudo chown -R www-data:www-data /var/www/html


###echo "DROP DATABASE nextcloud" | sudo -u postgres psql 

#mysql -h localhost -uroot -pnextcloud -e "DROP DATABASE nextcloud"
#cat pg_setup.sql | sudo -u postgres psql 
#mysql -h localhost -uroot -pnextcloud -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
#mysql -h localhost -uroot -pnextcloud -e "GRANT ALL PRIVILEGES on nextcloud.* to nextcloud@localhost"

#TODO: may need to rerun this line if our password is not matching the db.
cat /var/archive/nc_db_latest.sql | sudo -u postgres psql 
#mysql -h localhost -unextcloud -pnextcloud nextcloud < /home/ubuntuusername/ncdb_1.sql


sudo systemctl start apache2


sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:data-fingerprint

# ensure caches match what we have on the drive
sudo -u www-data php /var/www/html/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/html/nextcloud/occ files:scan-app-data
# check for Nextcloud updates
echo "Nextcloud apps are checked for updates..."
sudo -u www-data php /var/www/html/nextcloud/occ app:update --all


