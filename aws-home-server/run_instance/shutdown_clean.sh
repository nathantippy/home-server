#!/bin/bash
         
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:mode --on

sudo shutdown --poweroff       
         
