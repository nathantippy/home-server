#!/bin/bash
REPAIR=$${1:-"no-repair"}

# TODO: add instructions for manual run and restore. 
#       add instructions for nextlcoud setup
#       add instrucitons for adding users
#       can some of this be done by pilot.
#       is backup working nightly?
#       can we change drive size.
#       test import of all old mail


############################################################################
## /mnt/second_drive/etc_users
############################################################################
echo "backup /mnt/second_drive/etc_users -----------------------------------------------------"
sudo bash ./users_backup.sh
if [ "repair" == "$${REPAIR}" ]; then
sudo duplicati-cli repair s3://${TF_BACKUP_BUCKET}/etc_users --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64
fi

sudo duplicati-cli backup s3://${TF_BACKUP_BUCKET}/etc_users "/mnt/second_drive/etc_users" --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64

############################################################################
## /mnt/second_drive/home
############################################################################
echo "backup /mnt/second_drive/home ------------------------------------------------------------"
if [ "repair" == "$${REPAIR}" ]; then
sudo duplicati-cli repair s3://${TF_BACKUP_BUCKET}/home --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64
fi

sudo duplicati-cli backup s3://${TF_BACKUP_BUCKET}/home "/mnt/second_drive/home" --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64

############################################################################
## /mnt/second_drive/var
############################################################################
#  https://duplicati.readthedocs.io/en/latest/05-storage-providers/#s3-compatible
echo "backup /mnt/second_drive/var -------------------------------------------------------------"
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --on

sudo mkdir -p /var/archive
sudo -u postgres pg_dumpall | sudo tee /var/archive/nc_db_latest.sql > pg_dump.sql

if [ "repair" == "$${REPAIR}" ]; then
sudo duplicati-cli repair s3://${TF_BACKUP_BUCKET}/var --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64
fi

sudo duplicati-cli backup s3://${TF_BACKUP_BUCKET}/var "/mnt/second_drive/var" --use-ssl --aws-access-key-id=${TF_USER_ID} --aws-secret-access-key=${TF_USER_SECRET} --passphrase=${TF_PASSWORD} --zip-compression-level=9 --zip-compression-zip64

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off


