#!/bin/bash
echo "ran cron backup" > /home/admin/cron_backup.txt
sudo bash /home/admin/full_backup.sh repair >> /home/admin/backup.log

