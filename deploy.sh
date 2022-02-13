#!/bin/bash

#docker builder prune

bash ./03-aws-home-server-launch.sh destroy || true


# great test utilities:
#  https://immuniweb.com/ssl
#  https://www.smtper.net/
#  https://www.gmass.co/smtp-test
#  https://teslaapps.net/en/the-apps/imap-email/settings-test.cfm
#  https://ssl-tools.net/mailservers
#  https://mxtoolbox.com/SuperTool.aspx
#  https://geekflare.com/smtp-testing-tools
#  https://www.gmass.co/smtp-test


# build a web site to kick off the building then another hosted by home server for maint and users adding.


bash ./02-aws-home-server-build.sh || exit

bash ./03-aws-home-server-launch.sh apply || exit

sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh.pem admin@3.139.30.133 sudo ./startup_creds.sh



