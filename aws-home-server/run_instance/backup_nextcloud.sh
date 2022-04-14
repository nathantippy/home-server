#!/bin/bash

### copy old backup

cp /var/archive/nc_db_previous.sql /var/archive/nc_db_oldest.sql || true
cp /var/archive/nc_html_previous.tar.gz /var/archive/nc_html_oldest.tar.gz || true


cp /var/archive/nc_db_latest.sql /var/archive/nc_db_previous.sql || true
cp /var/archive/nc_html_latest.tar.gz /var/archive/nc_html_previous.tar.gz || true


################

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --on

#sudo -u postgres pg_dump nextcloud > /var/archive/nc_db_$(date -I).sql
# get all roles and tablespace defs.
sudo -u postgres pg_dumpall | sudo tee /var/archive/nc_db_latest.sql
sudo tar -cpzf /var/archive/nc_html_latest.tar.gz -C /var/www/html/nextcloud .

sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --off


