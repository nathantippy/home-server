
variable "isodate" {
  type    = string
}
variable "region" {
  type    = string
}
variable "access_key" {
  type    = string
}
variable "secret_key" {
  type    = string
}
variable "role_arn" {
  type    = string
}

variable "dovecot_version" {
	default = "1:2.3.13+dfsg1-2"
}	
	
# TODO: move the versions up here...

data "amazon-ami" "found_debian" {
  filters = {
    name                = "*debian-11-arm64-20211011-792*"  # no EKS and no AWS
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["136693071363"]
 
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"   
  assume_role {
        role_arn     = "${var.role_arn}"
        session_name = "packer"
  }
}

locals {
    timestamp_id = "latest" #replace(replace(timestamp(),":","_"),"T","_")
    server_name = "homeserver"
}


source "amazon-ebs" "debian_server" {

  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"   
  assume_role {
        role_arn     = "${var.role_arn}"
        session_name = "packer"
  }
  
  encrypt_boot          = true
  force_delete_snapshot = true
  force_deregister      = true  
  ebs_optimized         = true
   
  source_ami            = "${data.amazon-ami.found_debian.id}"
  ssh_username          = "admin"

  max_retries          = 30
  communicator         = "ssh"            
  ssh_timeout          = "30m"
  
}



build {

    name="indi"
    	
    source "source.amazon-ebs.debian_server" {
					    name                  = "debian"
						ami_name              = "debian_arm_${local.server_name}_${local.timestamp_id}"
						instance_type         = "t4g.micro"  # 6$ "c6gn.medium" 30$	
						tags                  = {
						                         instance_family : "t4g"
						                         build_date : "${var.isodate}"
										        }
						ena_support   = true
				        sriov_support = true
					}               
                   
	#provisioner "file" {
	#  source = "run_instance/users_backup.sh"
	#  destination = "/home/admin/users_backup.sh"
	#}
	#provisioner "file" {
	#  source = "run_instance/users_restore.sh"
	#  destination = "/home/admin/users_restore.sh"
	#}

	# WARNING: we can not write to /home/admin since this will be remounted upon machine launch
	#          any files for that location will need to be loaded later
	
	provisioner "shell" {
	    only = ["amazon-ebs.debian"]
		inline = [
		        "dpkg --print-architecture",
		        
		        # a place to backup the users
		        "sudo mkdir -p /var/archive/users",
		        # a place to host all our web sites 
		        "sudo mkdir -p /var/www/html",
		        
		        "sudo apt-get update -y -qq",
                "sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release -y",
                "sudo apt-get install sudo -y",
                		       
		        ######   ensure we have the right time on this server using AWS time service
		        "sudo apt-get install chrony -y", # local time service
			    "sudo echo \"server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4\" > ./chrony.conf2",
			    "sudo cat /etc/chrony/chrony.conf >> ./chrony.conf2",
                "sudo rm /etc/chrony/chrony.conf",
                "sudo mv ./chrony.conf2 /etc/chrony/chrony.conf",
                "sudo /etc/init.d/chrony restart",            
                
                #### common tools
		        "sudo apt-get install curl net-tools -y",
		        "sudo apt-get install bash-completion wget lsof -y",
		        "sudo apt-get install expect -y",
		        
		        "sudo apt-get install bash -y",
                "sudo apt-get install vim -y",
                "sudo apt-get install jq -y",
                                
                "sudo apt-get install unzip zip -y",
                "sudo apt-get install dosfstools=4.2-1 -y", # mkfs
                "sudo apt-get install xfsprogs=5.10.0-4 -y", # xfs - supports giant files
                "sudo apt-get install rsync=3.2.3-4+deb11u1 -y",
   
		        "sudo apt-get install fail2ban=0.11.2-2 -y", 
		        "sudo apt-get install iptables-persistent -y",
        		        
		        ########      docker  https://www.techlear.com/blog/2021/10/01/how-to-install-docker-on-debian-11/		        
				"sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
				"sudo echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",				
				"sudo apt-get update -y -qq",
 				"sudo apt-get install docker-ce docker-ce-cli containerd.io -y",
                
        
                
				####################################################################################################################
				# we setup the mail server late to ensure that /etc/resolv.conf is done changing so postfix can resolve dns entries
	            # https://upcloud.com/community/tutorials/secure-postfix-using-lets-encrypt/                                
				####################################################################################################################         
                "apt-cache madison postfix",
                "sudo apt-get install certbot=1.12.0-2 -y",
		        ## start of mail installer.   
		        ## https://www.tecmint.com/install-postfix-mail-server-with-webmail-in-debian/
		        ## https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/
                "echo \"order hosts,bind\" > temp.conf", # read the hosts file first.
                "echo \"multi on\" >> temp.conf",
                "sudo mv temp.conf /etc/host.conf",
                "cat /etc/host.conf",                
				"sudo DEBIAN_FRONTEND=noninteractive apt-get install postfix=3.5.6-1+b1 -y",
											
				"sudo mkdir -p /etc/postfix/sasl_passwd",
				"sudo /usr/sbin/postmap /etc/postfix/sasl_passwd",
				"sudo postconf -n",
					
				############################################################################################################################
                "apt-cache policy dovecot",
                
                "sudo apt-get install dovecot-core=${var.dovecot_version} -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-imapd=${var.dovecot_version} -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-pop3d=${var.dovecot_version} -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-pgsql=${var.dovecot_version} -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-lucene=${var.dovecot_version} -y",   #apt-cache policy
			    "sudo apt-get install dovecot-gssapi=${var.dovecot_version} -y", 
			    "sudo apt-get install dovecot-managesieved=${var.dovecot_version} -y",
			    "sudo apt-get install dovecot-sieve=${var.dovecot_version} -y",			
			    "sudo apt-get install dovecot-lmtpd=${var.dovecot_version} -y",  # if broken try remove and install  
			    "sudo apt-get install dovecot-solr=${var.dovecot_version} -y",       #  collides with postfix dovecot-submissiond -y",
                              
                "sudo apt-get install libsasl2-2 libsasl2-modules sasl2-bin -y", 
				"sudo sed -i \"s|#listen = |listen = |g\" /etc/dovecot/dovecot.conf",           
				"sudo sed -i \"s|#disable_plaintext_auth = yes|disable_plaintext_auth = no|g\" /etc/dovecot/conf.d/10-auth.conf",
				"sudo sed -i \"s|auth_mechanisms = plain|auth_mechanisms = plain login|g\" /etc/dovecot/conf.d/10-auth.conf", 
				
				#use this block to keep mail under user home folder           
				"sudo sed -i \"s|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|g\" /etc/dovecot/conf.d/10-mail.conf",
				# use this block to keep all mail under var				
				#"sudo sed -i \"s|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = mbox:~/mail|g\" /etc/dovecot/conf.d/10-mail.conf",

                # other notes 
	       	    #"sudo sed -i \"s|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = mbox:/var/mail/%u|g\" /etc/dovecot/conf.d/10-mail.conf",
		        #                 mail_location = mbox:~/mail:INBOX=/var/mail/%u:INDEX=/var/indexes/%u				
				############################################################################################################################
				############################################################################################################################
                
                "sudo apt-get install cockpit -y",                
                     
			     # fix crontab
			    "sudo apt-get -y install libpam-pwquality",     
                "sudo sed -i \"s|pam.deny.so|pam_pwquality.so retry=5 minlen=9 maxrepeat=5 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 gecoscheck=1 reject_username|g\" /etc/pam.d/common-password", #strong passwords               
			    "sudo service cron restart",

                # download the backup service and install it
                "wget https://updates.duplicati.com/beta/duplicati_2.0.6.3-1_all.deb",
                "sudo apt-get install ./duplicati_2.0.6.3-1_all.deb -y",
                
                "apt-cache policy apache2",
                "sudo apt-get install apache2=2.4.53-1~deb11u1 -y", 
                "sudo a2enmod rewrite",
				"sudo a2enmod headers",
				"sudo a2enmod env",
				"sudo a2enmod dir",
				"sudo a2enmod mime", 
				"sudo a2enmod ssl",
				
				"wget https://github.com/vector-im/element-web/releases/download/v1.9.6-rc.1/element-v1.9.6-rc.1.tar.gz",
				"mv element-v1.9.6-rc.1.tar.gz element.tar.gz",
                
                "sudo wget -qO - https://packages.sury.org/php/apt.gpg | sudo apt-key add -",
                "sudo echo \"deb https://packages.sury.org/php/ $(lsb_release -sc) main\" | sudo tee /etc/apt/sources.list.d/php.list",
                "sudo apt update",
                
                "sudo apt-get install php7.4 libapache2-mod-php7.4 php7.4-curl php7.4-xml php7.4-zip php7.4-mysql php7.4-pgsql php7.4-cgi  php7.4-mysql -y",
                "sudo apt-get install php7.4-common php7.4-mbstring php7.4-xmlrpc php7.4-gd php7.4-intl php7.4-ldap php7.4-imagick php7.4-json php7.4-cli -y",
			    # local memory cache used by nextcloud
                "sudo apt-get install php7.4-apcu -y",
                
                "sudo apt-get install postgresql postgresql-contrib -y",                                
                         
     ## install imapsync ########## this only works on an intel box
     #echo "Installing Dependencies for imapsync AND spamassassin"
     
     "sudo apt-get -y install git rcs make makepasswd cpanminus apt-file gcc libssl-dev libauthen-ntlm-perl libclass-load-perl libcrypt-ssleay-perl liburi-perl",
     "sudo apt-get -y install libdata-uniqid-perl libdigest-hmac-perl libdist-checkconflicts-perl libfile-copy-recursive-perl libio-compress-perl libio-socket-inet6-perl libio-socket-ssl-perl libio-tee-perl libmail-imapclient-perl libmodule-scandeps-perl libnet-ssleay-perl libpar-packer-perl",
     "sudo apt-get -y install libreadonly-perl libsys-meminfo-perl libterm-readkey-perl libtest-fatal-perl libtest-mock-guard-perl libtest-pod-perl libtest-requires-perl libtest-simple-perl libunicode-string-perl libencode-imaputf7-perl libfile-tail-perl libregexp-common-perl",
     "sudo apt-get -y install libregexp-common-email-address-perl libregexp-common-perl libregexp-common-time-perl libtest-deep-fuzzy-perl libtest-deep-perl libtest-deep-json-perl libtest-deep-perl libtest-deep-type-perl libtest-deep-unorderedpairs-perl libtest-modern-perl libtest-most-perl",
     
     #echo "Installing required Python/spamassasin modules using CPAN"	
	 "sudo cpanm Crypt::OpenSSL::RSA Crypt::OpenSSL::Random --force",
	 "sudo cpanm Mail::IMAPClient JSON::WebToken Test::MockObject", 
	 "sudo cpanm Unicode::String Data::Uniqid",
  
     "sudo cpanm Net::DNS NetAddr::IP --force", # required for spamassasin
  
           #############################################
     
     #echo "Downloading and building imapsync"
     
     "sudo git clone https://github.com/imapsync/imapsync.git",
     "sudo apt-file update",
     "cd imapsync && sudo mkdir -p dist",
     "sudo git checkout tags/imapsync-1.836",
     "sudo make install",
     
      #############################################
				"sudo apt-get install spamassassin -y",
				"sudo apt-get install spamc -y",
                "sudo sed -i \"s|ENABLED=0|ENABLED=1|g\" /etc/default/spamassassin",
                "sudo sed -i \"s|CRON=0|CRON=1|g\" /etc/default/spamassassin",
                "sudo groupadd spamd",
                "sudo useradd -g spamd -s /bin/false -d /var/log/spamassassin spamd",
                "sudo mkdir /var/log/spamassassin",
                "sudo chown spamd:spamd /var/log/spamassassin",
                
                "sudo service spamassassin start -y",
                # sudo service spamassassin status
                # spamassassin --version
                # sudo netstat -ntpl	
                # update the filters, run this on crontab nightly but probably not needed if CRON=1
                "sudo sa-update && sudo service spamassassin reload",		
     
     ##############################
                                
                
                
				#rust lang - move to later after drive mount
				#"curl https://sh.rustup.rs -sSf | sh -s -- -y",
				
				#matrix server, we must build until their download page is fixed.
				#"wget https://gitlab.com/famedly/conduit/-/archive/next/conduit-next.zip",
				#"unzip conduit-next.zip",
				#"cd conduit-next",
				#"cargo build --release",
				#"cd ..",
							

                #"sudo apt-get install haproxy=2.4.12-1~bpo11+1 -y", # proxy for jitsi and synapse/Dendrite	
                #   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                
         
			 

                #"sudo apt-get install nginx -y", # proxy for jitsi and synapse/Dendrite - old we have ha proxy above..	        
                #   "sudo apt-get install gcc -y", # both dendrite and mastidon
                # mastodon	- broken	        
                # "sudo apt-get install imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev file git-core -y",
                # "sudo apt-get install g++ libprotobuf-dev protobuf-compiler pkg-config autoconf -y",
                # "sudo apt-get install bison build-essential libssl-dev libyaml-dev libreadline6-dev -y",
                # "sudo apt-get install zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev -y",
                # "sudo apt-get install nginx redis-server redis-tools postgresql postgresql-contrib -y",
                # "sudo apt-get install python3-pip -y",
                # "sudo pip3 install --upgrade pip",
               # "sudo apt-get install python3-acme python3-certbot python3-mock python3-openssl python3-pkg-resources python3-pyparsing python3-zope.interface -y",
                # "sudo apt-get install certbot python3-certbot-nginx libidn11-dev libicu-dev libjemalloc-dev -y",
		        # "sudo curl -sL https://deb.nodesource.com/setup_12.x | bash -",
		        # "sudo curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -",
                # "sudo echo \"deb https://dl.yarnpkg.com/debian/ stable main\" | tee /etc/apt/sources.list.d/yarn.list",
                # "sudo apt-get update -y -qq",
                # "sudo apt-get install nodejs yarn -y",
  

# Go lang not always available
# remove this into its own server just for building dendrite later
#                "sudo apt-get install gcc -y",
#		        "sudo apt-get install git -y", # decenralized revision history 
                ######         install go for the matrix dendrite, DONE HERE FOR ARM PLATFORM              
#		        "wget https://golang.org/dl/go1.17.3.linux-$(dpkg --print-architecture).tar.gz",      #############
#		        "sudo tar -zxvf go1.17.3.linux-$(dpkg --print-architecture).tar.gz -C /usr/local/",   # go ver 1.17.3
#                "env GOOS=linux GOARCH=$(dpkg --print-architecture)",
#                "sudo rm go1.17.3.linux-$(dpkg --print-architecture).tar.gz",
#		        "echo \"export PATH=/usr/local/go/bin:$${PATH}\" | sudo tee /etc/profile.d/go.sh",
#               ". /etc/profile.d/go.sh",
#                "go version && go env", 
		        
		        #####         install dendrite
		        # move to a temp dir for this work.
		        #"sudo rm -rf dendrite",
		        #"git clone https://github.com/matrix-org/dendrite --branch v0.6.4",        # tag v0.6.4  
		        #"echo \"done with git clone\"",
		        #"cd dendrite",		        
		        #". ./build.sh"        
		        		     	        		        
	      
		]
	}
}

