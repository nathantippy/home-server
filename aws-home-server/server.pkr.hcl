
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
						tags          = merge(
						                      {"instance_family" : "t4g"}
										   )
						ena_support   = true
				        sriov_support = true
					}               
                   
	
	# WARNING: we can not write to /home/admin since this will be remounted upon machine launch
	#          any files for that location will need to be loaded later
	
	provisioner "shell" {
	    only = ["amazon-ebs.debian"]
		inline = [
		        "dpkg --print-architecture",
		        
		        # a place to backup the users
		        "sudo mkdir -p /home/admin/users", 
		        
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
                "sudo apt-get install zip -y",
                "sudo apt-get install dosfstools=4.2-1 -y", # mkfs
                "sudo apt-get install xfsprogs=5.10.0-4 -y", # xfs - supports giant files
                "sudo apt-get install rsync=3.2.3-4+deb11u1 -y",
   
		        "sudo apt-get install fail2ban=0.11.2-2 -y", # testing email without this..
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
                "sudo apt-get install certbot=1.12.0-2 -y",
		        ## start of mail installer.   
		        ## https://www.tecmint.com/install-postfix-mail-server-with-webmail-in-debian/
		        ## https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/
                "echo \"order hosts,bind\" > temp.conf", # read the hosts file first.
                "echo \"multi on\" >> temp.conf",
                "sudo mv temp.conf /etc/host.conf",
                "cat /etc/host.conf",                 
				"sudo DEBIAN_FRONTEND=noninteractive apt-get install postfix=3.5.6-1+b1 -y",
				"sudo sed -i \"s|#smtps |smtps |g\" /etc/postfix/master.cf", #turns on port 465 for TLS
				"sudo sed -i \"s|#smtpd |smtpd |g\" /etc/postfix/master.cf", #turns on email to correct destination
				"sudo sed -i \"s|#submission |submission |g\" /etc/postfix/master.cf", #turns on port 587 for TLS
				"sudo mkdir -p /etc/postfix/sasl_passwd",
				"sudo /usr/sbin/postmap /etc/postfix/sasl_passwd",
				"sudo postconf -n",
                "sudo apt-get install libsasl2-2 libsasl2-modules sasl2-bin -y", 
				############################################################################################################################
                "sudo apt-get install dovecot-core=1:2.3.13+dfsg1-2 -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-imapd=1:2.3.13+dfsg1-2 -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-pop3d=1:2.3.13+dfsg1-2 -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-pgsql=1:2.3.13+dfsg1-2 -y", # grab specific version tested for the scripts
                "sudo apt-get install dovecot-lucene=1:2.3.13+dfsg1-2 -y",   #apt-cache madison
				"sudo sed -i \"s|#listen = |listen = |g\" /etc/dovecot/dovecot.conf",           
				"sudo sed -i \"s|#disable_plaintext_auth = yes|disable_plaintext_auth = no|g\" /etc/dovecot/conf.d/10-auth.conf",
				"sudo sed -i \"s|auth_mechanisms = plain|auth_mechanisms = plain login|g\" /etc/dovecot/conf.d/10-auth.conf",                    
				"sudo sed -i \"s|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|g\" /etc/dovecot/conf.d/10-mail.conf",
				############################################################################################################################
				############################################################################################################################
               
                
                
                "sudo apt-get install cockpit -y",                
                "sudo sed -i \"s|pam.deny.so|pam_pwquality.so retry=5 minlen=9 maxrepeat=5 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 gecoscheck=1 reject_username|g\" /etc/pam.d/common-password", #strong passwords
                
                # install Roundcube mail client due to great license and features.                
                # download the new version
                                                
                "sudo apt-get install apache2 -y",
                "sudo a2enmod ssl",
                "sudo a2enmod headers",
                "sudo a2ensite default-ssl",
                
                #  apt-cache madison postgresql
                "sudo apt-get install postgresql=13+225 -y", 
                "sudo apt-get install postgresql-contrib -y", 
                
                
                     #    check it works and version:   sudo -u postgres psql -c "SELECT version();"
                     #                                  pg_lsclusters
                     #                                  sudo service postgresql status
                     #    edit config:   sudo vim /etc/postgresql/13/main/postgresql.conf
                     
                     # Next in the TF wee will run 
                     # sudo -u postgres createuser roundcube -P
                     # sudo -u postgres createdb -O roundcube -E UNICODE -W roundcubemail
                                              
                    #see: html/roundcube/INSTALL              
                    #see: html/roundcube/config/defaults.inc.php
                
                
                
                
                #  https://robido.com/server-admin/how-to-install-roundcube-with-nginx-postfix-and-dovecot/
                "sudo wget -qO - https://packages.sury.org/php/apt.gpg | sudo apt-key add -",
                "sudo echo \"deb https://packages.sury.org/php/ $(lsb_release -sc) main\" | sudo tee /etc/apt/sources.list.d/php.list",
                "sudo apt update",
			    "sudo apt-get install php7.3 libapache2-mod-php7.3 php7.3-curl php7.3-xml php7.3-zip php7.3-mysql php7.3-pgsql -y",
                "sudo apt-get install php7.3-common php7.3-mbstring php7.3-xmlrpc php7.3-gd php7.3-intl php7.3-ldap php7.3-imagick php7.3-json php7.3-cli -y",
                
                
                # need to set matching versions...  apt-cache madison roundcube
                                          
                "sudo wget https://github.com/roundcube/roundcubemail/releases/download/1.5.2/roundcubemail-1.5.2-complete.tar.gz",
                "tar xzf roundcubemail-1.5.2-complete.tar.gz",  
                "sudo mkdir -p /var/www/html/roundcube/config",
                "sudo cp -r roundcubemail-1.5.2/* /var/www/html/roundcube",
                "sudo rm -r roundcubemail-1.5.2",
                "sudo rm roundcubemail-1.5.2-complete.tar.gz",
           
			    
                "sudo chown -R www-data.www-data /var/www/html/roundcube/",
                "sudo chmod -R 775 /var/www/html/roundcube/temp",
                "sudo chmod -R 775 /var/www/html/roundcube/logs",
                "sudo find /var/www/html/roundcube/ -type d -exec chmod 750 {} \\;",
				"sudo find /var/www/html/roundcube/ -type f -exec chmod 640 {} \\;",
                                              
                     
                ##### element (vector)              
                "wget https://github.com/vector-im/element-web/releases/download/v1.9.6-rc.1/element-v1.9.6-rc.1.tar.gz",
                "sudo tar -zxvf ./element-v1.9.6-rc.1.tar.gz -C /var/www/html",
                "sudo mv /var/www/html/element-v1.9.6-rc.1 /var/www/html/element",
                "sudo rm ./element-v1.9.6-rc.1.tar.gz",              

                
                
#wget http://downloads.sourceforge.net/project/roundcubemail/roundcubemail/1.0.2/roundcubemail-1.0.2.tar.gz
#tar -zxvf roundcubemail-1.0.2.tar.gz
#mv roundcubemail-1.0.2 /usr/share/roundcube
#mkdir /var/log/roundcube
                
                
				#rust lang
				"curl https://sh.rustup.rs -sSf | sh -s -- -y",
				#matrix server, we must build until their download page is fixed.
				#"wget https://gitlab.com/famedly/conduit/-/archive/next/conduit-next.zip",
				#"unzip conduit-next.zip",
				#"cd conduit-next",
				#"cargo build --release",
				#"cd ..",
							

                "sudo apt-get install haproxy=2.4.12-1~bpo11+1 -y", # proxy for jitsi and synapse/Dendrite	
                #   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                
                
                
			    #"sudo mkdir /var/www/html/mail",
			    # use nginx for this..
			    
			    
			    
                # install rainloop under javanut.com/mail
			    #"cd /var/www/html/mail", 
			    #"sudo curl -sL https://repository.rainloop.net/installer.php | sudo php",
			    #"sudo cd ~",

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
  

                ######         install go for the matrix dendrite              
		        #"wget https://golang.org/dl/go1.17.3.linux-$(dpkg --print-architecture).tar.gz",      #############
		        #"sudo tar -zxvf go1.17.3.linux-$(dpkg --print-architecture).tar.gz -C /usr/local/",   # go ver 1.17.3
                #"env GOOS=linux GOARCH=$(dpkg --print-architecture)",
		        #"echo \"export PATH=/usr/local/go/bin:$${PATH}\" | sudo tee /etc/profile.d/go.sh",
                #". /etc/profile.d/go.sh",
                #"go version && go env",      		       
		       
		        #####         install dendrite
		        #"sudo apt-get install git -y", # decenralized revision history 
		        #"sudo rm -rf dendrite",
		        #"git clone https://github.com/matrix-org/dendrite --branch v0.5.1",        # tag v0.5.1  
		        #"echo \"done with git clone\"",
		        #"cd dendrite",		        
		        #". ./build.sh"        
		        		     	        		        
	      
		]
	}
}

