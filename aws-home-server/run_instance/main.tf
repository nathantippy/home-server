

terraform {
  
  backend "s3" {
  }
  
  required_providers {
    aws = ">= 3.1.0"  
    local = ">= 2.1.0"
    template = ">= 2.2.0"  
    null = ">= 3.1.0"
    random = ">= 3.1.0"
  }
  
  required_version = "~> 1.1.2"
}

provider "aws" {
  region = var.region

  access_key = var.access_key
  secret_key = var.secret_key

  assume_role {
    role_arn = var.role_arn 
  }
    
}

data "terraform_remote_state" "prev" {
  backend = "local"
  config = {
    path = "${path.module}/../public_ip.tfstate"
  }
}

variable "domain" {}
variable "region" {}
variable "pub_key_file" {}
variable "pem_key_file" {}
variable "dns_impl" {}
variable "role_arn" {}
variable "access_key" {}
variable "secret_key" {}

variable "use_old_secret" {
	default = true
}
variable "php_version" {
	default = "7.4"
}

variable "apache2_memory_limit" {
    type = string
	default = "512M"
}
variable "apache2_upload_max_filesize" {
	type = string
	default = "2048M"
}
variable "apache2_post_max_size" {
	type = string
	default = "500M"
}
variable "apache2_max_execution_time" {
	type = string
	default = "900"
}
variable "apache2_date_timezone" {
	type = string
	default = "America/Chicago"
}

variable "instance_type" {
	default = "t4g.medium"# "t4g. # nano .5G  (micro 1G minimum) small 2G medium 4G
}

locals {
   dns_count        = "aws"==var.dns_impl ?  1 : 0 # only set up route53 if dns_impl is set to aws
   
   key-name         = "home-server-${replace(var.domain,".","-")}-ssh"
   instance-type    = var.instance_type
   max-mailbox-size = 17179869184*4  # in bytes 64 GB, the default for gmail is 16.
   
   # TODO: to save more we can use sc1 but bank them with gluster to cut the price in half.
   volume_iops       = 3000  # was 6000 causing 14$ per month, now testing 3000 for new releases.
   volume_throughput = 250
   volume_type       = "gp3"
   volume_size       = 24  # was 32 but we do not need that much
      
}

data "aws_caller_identity" "current" {
}

/////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////

data "aws_route53_zone" "domain_zone" {
  count        = local.dns_count
  name         = "${var.domain}."
  private_zone = false
}

resource "aws_route53_record" "mail" {
  count        = local.dns_count
  zone_id = data.aws_route53_zone.domain_zone[0].zone_id
  name    = "mail.${data.aws_route53_zone.domain_zone[0].name}"
  type    = "A"
  ttl     = "60"
  records = ["${data.terraform_remote_state.prev.outputs.ip}"]
}

resource "aws_route53_record" "all" {
  count        = local.dns_count
  zone_id = data.aws_route53_zone.domain_zone[0].zone_id
  name    = "*.${data.aws_route53_zone.domain_zone[0].name}"
  type    = "A"
  ttl     = "60"
  records = ["${data.terraform_remote_state.prev.outputs.ip}"]
}

resource "aws_route53_record" "root" {
  count        = local.dns_count
  zone_id = data.aws_route53_zone.domain_zone[0].zone_id
  name    = "${data.aws_route53_zone.domain_zone[0].name}"
  type    = "A"
  ttl     = "60"
  records = ["${data.terraform_remote_state.prev.outputs.ip}"]
}

resource "aws_route53_record" "mx_root" {
  count        = local.dns_count
  zone_id = data.aws_route53_zone.domain_zone[0].zone_id
  name    = "${data.aws_route53_zone.domain_zone[0].name}"
  type    = "MX"
  ttl     = "60"
  records = ["mail.${var.domain}"]
}

resource "aws_route53_record" "mx_all" {
  count        = local.dns_count
  zone_id = data.aws_route53_zone.domain_zone[0].zone_id
  name    = "*.${data.aws_route53_zone.domain_zone[0].name}"
  type    = "MX"
  ttl     = "60"
  records = ["mail.${var.domain}"]
}

/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////


data "aws_ami" "most_recent_home-server" {
	most_recent = true
	filter {
		name = "name"
		values = ["debian_arm_homeserver_latest"] 
	}
	filter {
		name = "virtualization-type"
		values = ["hvm"]
	}
	owners = [data.aws_caller_identity.current.account_id]

}

resource "random_string" "nextcloud-pass" {
	length  = 18
	special = false
	upper   = true
	numeric = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pub.content}")
    }   
}
resource "random_string" "admin-pass" {
	length  = 18
	special = false
	upper   = true
	numeric  = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pub.content}")
    }   
}
resource "random_string" "nc-pg-pass" {
	length  = 18
	special = false
	upper   = true
	numeric  = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pub.content}")
    }   
}


resource "aws_kms_key" "home-server-root-ebs" {
  description             = "Home Server Root EBS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.home-server.id
  allocation_id = data.terraform_remote_state.prev.outputs.ip-arn
}

output "command" {
	value = <<EOF
sudo ssh-keygen -f /root/.ssh/known_hosts -R ${data.terraform_remote_state.prev.outputs.ip}
##
## new install 
sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh-${replace(var.domain,".","-")}.pem admin@${data.terraform_remote_state.prev.outputs.ip} bash ./startup_from_new.sh
##
## resume from last backup
sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh-${replace(var.domain,".","-")}.pem admin@${data.terraform_remote_state.prev.outputs.ip} bash ./startup_from_backup.sh
##
## startup as is
sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh-${replace(var.domain,".","-")}.pem admin@${data.terraform_remote_state.prev.outputs.ip} bash ./startup_from_existing.sh
##
## full backup
sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh-${replace(var.domain,".","-")}.pem admin@${data.terraform_remote_state.prev.outputs.ip} bash ./full_backup.sh
## shutdown
sudo ssh -o "StrictHostKeyChecking no" -i ./keep/home-server-ssh-${replace(var.domain,".","-")}.pem admin@${data.terraform_remote_state.prev.outputs.ip} bash ./shutdown_clean.sh

EOF

# need to log in and start up the right script.

}
#  sudo zip letsencrypt.zip * -r -e  # should back this up since lets encrypt would prefer we only do this 5 per week  https://letsencrypt.org/docs/rate-limits/
# cp to admin folder for safe keeping.
# sudo scp -i ./keep/home-server-${replace(var.domain,".","-")}-ssh.pem admin@3.139.30.133:/home/admin/letsencrypt.zip .

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${data.terraform_remote_state.prev.outputs.vpc-id}"

}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${data.terraform_remote_state.prev.outputs.vpc-id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }

}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${data.terraform_remote_state.prev.outputs.subnet-zone-a-id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}


resource "aws_volume_attachment" "user-data" {  # TODO: we need snapshot backups of this..
  device_name = "/dev/sdh"
  volume_id   = data.terraform_remote_state.prev.outputs.user-data-volume-id
  instance_id = aws_instance.home-server.id
}

// TODO: if stopped we must terminate and rebuild..

resource "aws_instance" "home-server" {
	ami                    = data.aws_ami.most_recent_home-server.id
	monitoring             = true
	instance_type          = local.instance-type
	key_name               = local.key-name
    vpc_security_group_ids = [data.terraform_remote_state.prev.outputs.security-group-id]

    subnet_id              = "${data.terraform_remote_state.prev.outputs.subnet-zone-a-id}"

	root_block_device {
		delete_on_termination = true 
		encrypted             = true
		kms_key_id            = aws_kms_key.home-server-root-ebs.arn
		iops                  = ("sc1"==local.volume_type) ? null : local.volume_iops
		throughput            = ("sc1"==local.volume_type) ? null : local.volume_throughput 
		volume_type           = local.volume_type
		volume_size           = local.volume_size	
		tags = {
		 	"Name"    : "home-server-${replace(var.domain,".","-")}"
		 	"Domain"  : var.domain
		} 
	
	}	

#      TODO: add tags for everything...
    tags = {
         	"Name"    : "homeserver" 
		 	"Domain"  : var.domain
    }
		
}


data "local_file" "ssh-pub" {
   filename = "../${var.pub_key_file}"
}
data "local_file" "ssh-pem" {
   filename = "../${var.pem_key_file}"
}

variable "alias-domains" {
    type = string
	default = ""

}

locals {
  
  virtual_domains_file = "%{ for x in split(",",replace(var.alias-domains, " ", "") ) } ${x}  #default \n%{ endfor } "

}


data "template_file" "postfix-main-cf" {
	template = file("${path.module}/../postfix-main.cf")
	vars = {
		TF-HOSTNAME              = "mail.${var.domain}"
		TF-DOMAIN                = var.domain
		
		TF-VIRTUAL-ALIAS-DOMAINS = "none"==var.alias-domains ? "" : ", ${var.alias-domains}" // "domain2.com, domain3.com"
		TF-PRIVATE-CIDR          = data.terraform_remote_state.prev.outputs.vpc-cidr
		TF-MAX-MAILBOX_SIZE      = local.max-mailbox-size # this limits risk and can be bumpted up as needed.
	}
}

//TODO: fix terraarch licenses are no longer valid..

locals {
    // use the old version if found. 
    //    only deleted if someone also deletes the install or changes the password
	admin_pass=try(local.old_pass.admin_pass, random_string.admin-pass.result)  //andom_string.admin-pass.result
	nc_pg_pass=try(local.old_pass.nc_pg_pass, random_string.nc-pg-pass.result)
}

output "admin_pass" {
	value = local.admin_pass
	sensitive = true
}
output "nc_pg_pass" {
	value = local.nc_pg_pass
	sensitive = true
}



locals {
  old_pass = jsondecode(try(data.aws_secretsmanager_secret_version.secret-version[0].secret_string,
                     "{\"admin_pass\":\"${random_string.admin-pass.result}\",\"nc_pg_pass\":\"${random_string.nc-pg-pass.result}\"}")) 
}

data "aws_secretsmanager_secret_version" "secret-version" {
  count = var.use_old_secret ? 1 : 0
  secret_id = data.terraform_remote_state.prev.outputs.home-server-secret-id
}

locals {
  userId         = data.terraform_remote_state.prev.outputs.duplicati-user_id
  userSecret     = data.terraform_remote_state.prev.outputs.duplicati-user_secret
  backupBucketId = data.terraform_remote_state.prev.outputs.backup-bucket-id
}


resource "aws_secretsmanager_secret_version" "home_server_secrets" {
    secret_id     = data.terraform_remote_state.prev.outputs.home-server-secret-id
    secret_string = jsonencode({
                    	"admin_pass"=local.admin_pass
                    	"nc_pg_pass"=local.nc_pg_pass
                     })
}

data "template_file" "restore-nextcloud" {
	template = file("${path.module}/full_restore.sh")
	vars = {
	    TF_USER_ID = local.userId
	    TF_USER_SECRET = local.userSecret
	    TF_BACKUP_BUCKET = local.backupBucketId
	    TF_PASSWORD = local.admin_pass  # TODO: better password
	}
}

output "backup-bucket-id" {
	value=local.backupBucketId
}

data "template_file" "backup-nextcloud" {
	template = file("${path.module}/full_backup.sh")
	vars = {
	    TF_USER_ID = local.userId
	    TF_USER_SECRET = local.userSecret
	    TF_BACKUP_BUCKET = local.backupBucketId
	    TF_PASSWORD = local.admin_pass  # TODO: better password
	}
}


data "template_file" "expect-admin" {
	template = file("${path.module}/../expect-admin.txt")
	vars = {
	    ADMIN_PASS  = local.admin_pass
	}
}

data "template_file" "expect-pg" {
	template = file("${path.module}/../pg_setup.sql")
	vars = {
	    NEXTCLOUD_PASSWORD = local.nc_pg_pass #"password"
	}
}


data "template_file" "default-ssl-conf" {
	template = file("${path.module}/default-ssl.conf")
	vars = {
	    TF-DOMAIN        = var.domain
	}
}


data "template_file" "startup_init_sh" {
	template = file("${path.module}/startup_init.sh")
	vars = {
	    EBS_DEVICE         = "/dev/nvme1n1"
	}
}
data "template_file" "startup_letsencrypt_refresh_sh" {
	template = file("${path.module}/startup_letsencrypt_refresh.sh")
	vars = {
	    TF-DOMAIN          = var.domain
	}
}
data "template_file" "startup_from_backup_sh" {
	template = file("${path.module}/startup_from_backup.sh")
	vars = {
		TF_BACKUP_BUCKET = local.backupBucketId	
		TF_USER_ID = local.userId
		TF_USER_SECRET = local.userSecret
		TF_PASSWORD = local.admin_pass
	}
}
data "template_file" "startup_from_existing_sh" {
	template = file("${path.module}/startup_from_existing.sh")
	vars = {
	}
}
data "template_file" "startup_from_new_sh" {
	template = file("${path.module}/startup_from_new.sh")
	vars = {
	}
}
data "template_file" "shutdown_clean_sh" {
	template = file("${path.module}/shutdown_clean.sh")
	vars = {
	}
}
data "template_file" "cron_backup_sh" {
	template = file("${path.module}/cron_backup.sh")
	vars = {
	}
}


#data "template_file" "startup_creds_sh" {
#	template = file("${path.module}/startup_creds.sh")
#	vars = {
#		TF-DOMAIN          = var.domain
#	    TF-DOMAIN-NAME     = replace(var.domain,".","_")
#	    EBS_DEVICE         = "/dev/nvme1n1"
#	    NOTE               = "one test"
#	}
#}


data "template_file" "dovecot_10_ssl" {
	template = file("${path.module}/dovecot-10-ssl.conf")
	vars = {
		TF-DOMAIN     = var.domain
	}
}

locals {

default_sieve = <<EOF
require ["fileinto", "mailbox"];

if header :contains "X-Spam-Flag" "YES" {
        fileinto :create "Junk";
}	
EOF

}


resource "null_resource" "setup_instance" { 

  depends_on = [aws_volume_attachment.user-data, aws_instance.home-server ]
  
     provisioner "file" {
        content = data.template_file.backup-nextcloud.rendered
	    destination = "full_backup.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }
    provisioner "file" {
        content = data.template_file.restore-nextcloud.rendered
	    destination = "full_restore.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }

    provisioner "file" {
        content = local.default_sieve
	    destination = "default.sieve"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }


   provisioner "file" {
	    content = data.template_file.expect-admin.rendered
	    destination = "expect-admin.run" 
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	    }  
   }
   
   provisioner "file" {
	    content = data.template_file.expect-pg.rendered
	    destination = "pg_setup.sql" 
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	    }  
   }      


   provisioner "file" {
	    content = local.virtual_domains_file
	    destination = "virtual_domains" # /etc/postfix/
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	    }  
   }


   provisioner "file" {
	    content = data.template_file.postfix-main-cf.rendered
	    destination = "main.cf" # /etc/postfix/
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	    }  
   }

#
   provisioner "file" {
        content = data.template_file.default-ssl-conf.rendered
	    destination = "default-ssl.conf"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
   }


   provisioner "file" {
        source = "${path.module}/dovecot-10-master.conf"
	    destination = "10-master.conf" # /etc/dovecot/conf.d/
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }

   provisioner "file" {
        source = "${path.module}/postfix_master.cf"
	    destination = "master.cf" # /etc/postfix/master.cf
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }

   
   provisioner "file" {
        source = "${path.module}/spam_local.cf"
	    destination = "spam_local.cf" # /etc/spamassassin/local.cf
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }
    
    provisioner "file" {
        content = data.template_file.dovecot_10_ssl.rendered
	    destination = "10-ssl.conf" # /etc/dovecot/conf.d/
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	 
	    }  
    } 

   provisioner "file" {
        source = "${path.module}/users_backup.sh"        
	    destination = "users_backup.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }
    provisioner "file" {
        source = "${path.module}/users_restore.sh"        
	    destination = "users_restore.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }

   
  provisioner "file" {
        content = data.template_file.startup_init_sh.rendered
	    destination = "startup_init.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.startup_letsencrypt_refresh_sh.rendered
	    destination = "startup_letsencrypt_refresh.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.startup_from_backup_sh.rendered
	    destination = "startup_from_backup.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.startup_from_existing_sh.rendered
	    destination = "startup_from_existing.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.startup_from_new_sh.rendered
	    destination = "startup_from_new.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.shutdown_clean_sh.rendered
	    destination = "shutdown_clean.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   provisioner "file" {
        content = data.template_file.cron_backup_sh.rendered
	    destination = "cron_backup.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = data.terraform_remote_state.prev.outputs.ip
      user = "admin"
      private_key = data.local_file.ssh-pem.content
 
    }  
        
    # copy and refresh on every run, each step must be omnipotent 
    tiggers = { always = timestamp() }
    
    inline = [ "echo \"successful connection ssh admin@${data.terraform_remote_state.prev.outputs.ip} \"",
           
               "sudo chmod +x startup_creds.sh",
               "sudo bash -c \"echo '${data.terraform_remote_state.prev.outputs.ip} ${var.domain} mail.${var.domain}' >> /etc/hosts\"",  
		
               #create the user and database for roundcube given the desired password.

               "sudo chmod +x expect-admin.run",
		       "sudo ./expect-admin.run && rm ./expect-admin.run", # do not enable until we have the password
		      	
		      # setup the spam sieve rules	
		       "mkdir -p /var/lib/dovecot/sieve/",	
		       "sudo mv default.sieve /var/lib/dovecot/sieve/default.sieve",	
		       "sudo sievec /var/lib/dovecot/sieve/default.sieve",
		       "sudo chown -R dovecot:dovecot /var/lib/dovecot/sieve/*",	
		       "sudo chmod -R 755 /var/lib/dovecot/sieve",		      		      		      
		      		      		      		      
		      		      		      		      
               "sudo chmod +x users_backup.sh",
               "sudo chmod +x users_restore.sh",
               "sudo chmod +x full_backup.sh",
               "sudo chmod +x full_restore.sh",
			   "sudo chmod +x cron_backup.sh",
			   "sudo chmod +x startup_from_backup.sh",
			   "sudo chmod +x startup_from_new.sh",
			   "sudo chmod +x startup_from_existing.sh",
			   "sudo chmod +x startup_init.sh",
               "sudo chmod +x startup_letsencrypt_refresh.sh",
               "sudo chmod +x shutdown_clean.sh",
  
               "sudo mv virtual_domains /etc/postfix/virtual_domains",
               "sudo /usr/sbin/postmap /etc/postfix/virtual_domains", # generates virtual_domains.db
               "sudo /usr/sbin/postfix reload",
               #https://blog.tinned-software.net/setup-postfix-for-multiple-domains/
               #https://www.binarytides.com/install-spamassassin-with-postfix-dovecot/
               
			   "sudo mv main.cf /etc/postfix/main.cf",			   
			   "sudo mv master.cf /etc/postfix/master.cf",
			   "sudo mv spam_local.cf /etc/spamassassin/local.cf",
			   
			   "sudo mv 10-master.conf /etc/dovecot/conf.d/10-master.conf",
			   "sudo mv 10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf",
			   "echo \"protocols = $$protocols lmtp\" | sudo tee /usr/share/dovecot/protocols.d/lmtp.protocol",
			   "sudo sed -i \"s|#sieve_default =|sieve_default =|g\" /etc/dovecot/conf.d/90-sieve.conf",
			   "sudo sed -i \"s|#mail_plugins = $$mail_plugins|mail_plugins = $$mail_plugins sieve|g\" /etc/dovecot/conf.d/20-lmtp.conf",
			
			# redirect postfix via dovecot for spam ailter
			 "sudo sed -i \"s|#auth_username_format = %Lu|auth_username_format = %Ln|g\" /etc/dovecot/conf.d/10-auth.conf",  # remove @domainname to recipient - this solve lmtp error 'user not found
			
			
			
			
			#TODO: these should be files but not sure how..	   	
			# TODO: not looking omnipotent !!	build sh to run and erase from here.
			#   "cat /etc/apache2/sites-enabled/000-default.conf | grep -c '<VirtualHost .:443>'",   	
			   "cat default-ssl.conf | sudo tee -a /etc/apache2/sites-enabled/000-default.conf",
			   "rm default-ssl.conf",	
 				    
				
				
				"sudo sed -i \"s|output_buffering = 4096|output_buffering = Off|g\" /etc/php/${var.php_version}/cli/php.ini",   
			    "sudo sed -i \"s|memory_limit = 128M|memory_limit = ${var.apache2_memory_limit}|g\" /etc/php/${var.php_version}/cli/php.ini",

 				"sudo sed -i \"s|output_buffering = 4096|output_buffering = Off|g\" /etc/php/${var.php_version}/apache2/php.ini",   
			    "sudo sed -i \"s|memory_limit = 128M|memory_limit = ${var.apache2_memory_limit}|g\" /etc/php/${var.php_version}/apache2/php.ini",
				"sudo sed -i \"s|upload_max_filesize = 2M|upload_max_filesize = ${var.apache2_upload_max_filesize}|g\" /etc/php/${var.php_version}/apache2/php.ini",
				"sudo sed -i \"s|post_max_size = 8M|post_max_size = ${var.apache2_post_max_size}|g\" /etc/php/${var.php_version}/apache2/php.ini",
				"sudo sed -i \"s|max_execution_time = 30|max_execution_time = ${var.apache2_max_execution_time}|g\" /etc/php/${var.php_version}/apache2/php.ini",
				"sudo sed -i \"s|;date.timezone = |date.timezone = ${var.apache2_date_timezone}|g\" /etc/php/${var.php_version}/apache2/php.ini",
				
				"sudo sed -i \"s|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/letsencrypt/live/${var.domain}/fullchain.pem|g\" /etc/apache2/sites-available/default-ssl.conf",
                "sudo sed -i \"s|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/letsencrypt/live/${var.domain}/privkey.pem|g\" /etc/apache2/sites-available/default-ssl.conf",
			
				
				"sudo systemctl start apache2",
				"sudo systemctl enable apache2",
			           
   
				  # this does not appear to be supported on AWS 
				  # NOTE: DO NOT CALL THIS: sudo hostnamectl set-hostname ${var.email_domain}               
                       
                "echo \"Done with postfix setup.\""
             ]
  }

} 



