

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
variable "pem_key_file" {}
variable "dns_impl" {}
variable "role_arn" {}
variable "access_key" {}
variable "secret_key" {}



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

variable "root_volume_iops" {
	default = 3000  # 3000 is free, max is 16000 - not used for sc1
}
variable "root_volume_throughput" {
 	default = 125  # 125 MB/s is free, max is 1000 - not used for sc1
}
variable "root_volume_type" {          
	default = "gp3" 
}
variable "root_volume_size" {
 	default = 48  # 8G is the minimum but we need room for lots of email, 125 is smallest for sc1	
}

locals {
   dns_count        = "aws"==var.dns_impl ?  1 : 0 # only set up route53 if dns_impl is set to aws
   
   key-name         = "home-server-${replace(var.domain,".","-")}-ssh"
   instance-type    = "t4g.micro"# "t4g. # nano .5G  micro 1G small 2G
   max-mailbox-size = 17179869184  # in bytes 16 GB, the default for gmail is 16.
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
	number  = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pem.content}")
    }   
}
resource "random_string" "admin-pass" {
	length  = 18
	special = false
	upper   = true
	number  = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pem.content}")
    }   
}
resource "random_string" "nc-pg-pass" {
	length  = 18
	special = false
	upper   = true
	number  = true
	lower   = true
	keepers = {
    	eip = "${data.terraform_remote_state.prev.outputs.ip}"
    	private_key = sha512("${data.local_file.ssh-pem.content}")
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
	value = "sudo ssh-keygen -f /root/.ssh/known_hosts -R ${data.terraform_remote_state.prev.outputs.ip}\nsudo ssh -o \"StrictHostKeyChecking no\" -i ./keep/home-server-ssh.pem admin@${data.terraform_remote_state.prev.outputs.ip} sudo ./startup_creds.sh"

# need to log in and start up the right script.

}
#  sudo zip letsencrypt.zip * -r -e  # should back this up since lets encrypt would prefer we only do this 5 per week  https://letsencrypt.org/docs/rate-limits/
# cp to admin folder for safe keeping.
# sudo scp -i ./keep/home-server-ssh.pem admin@3.139.30.133:/home/admin/letsencrypt.zip .

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



resource "aws_instance" "home-server" {
	ami                    = data.aws_ami.most_recent_home-server.id
	monitoring             = true
	instance_type          = local.instance-type
	key_name               = local.key-name
    vpc_security_group_ids = [data.terraform_remote_state.prev.outputs.security-group-id]

    subnet_id              = "${data.terraform_remote_state.prev.outputs.subnet-zone-a-id}"

# TODO: this takes too long move root block out
# TODO: do full test  but copy takes too long as well so we may move to va
	root_block_device {
		delete_on_termination = true
		encrypted             = true
		kms_key_id            = aws_kms_key.home-server-root-ebs.arn
		iops                  = ("sc1"==var.root_volume_type) ? null : var.root_volume_iops
		throughput            = ("sc1"==var.root_volume_type) ? null : var.root_volume_throughput 
		volume_type           = var.root_volume_type
		volume_size           = var.root_volume_size	
		tags = {
		 	"Name"    : "homeserver" 
		 	"Domain"  : var.domain
		} 
	
	}	

#      TODO: add tags for everything...
    tags = {
         	"Name"    : "homeserver" 
		 	"Domain"  : var.domain
    }
		
}


data "local_file" "ssh-pem" {
   filename = "../${var.pem_key_file}"
}


variable "alias-domains" {
    type = string
	default = ""

}

data "template_file" "postfix-main-cf" {
	template = file("${path.module}/../postfix-main.cf")
	vars = {
		TF-HOSTNAME              = "mail.${var.domain}"
		TF-DOMAIN                = var.domain
		
		TF-VIRTUAL-ALIAS-DOMAINS = "none"==var.alias-domains ? "" : var.alias-domains // "domain2.com, domain3.com"
		TF-PRIVATE-CIDR          = data.terraform_remote_state.prev.outputs.vpc-cidr
		TF-MAX-MAILBOX_SIZE      = local.max-mailbox-size # this limits risk and can be bumpted up as needed.
	}
}

locals {
	admin_pass=random_string.admin-pass.result
	nc_pg_pass=random_string.nc-pg-pass.result
}

output "admin_pass" {
	value = local.admin_pass
}
output "nc_pg_pass" {
	value = local.nc_pg_pass
}

resource "aws_secretsmanager_secret_version" "home_server_secrets" {
    secret_id     = data.terraform_remote_state.prev.outputs.home-server-secret-id
    secret_string = jsonencode({
                    	"admin_pass"=local.admin_pass
                    	"nc_pg_pass"=local.nc_pg_pass
                     })
}

data "template_file" "expect-admin" {
	template = file("${path.module}/../expect-admin.txt")
	vars = {
	    ADMIN_PASS  = random_string.admin-pass.result 
	}
}

data "template_file" "expect-pg" {
	template = file("${path.module}/../pg_setup.sql")
	vars = {
	    NEXTCLOUD_PASSWORD = "password" # TODO: we need better password
	}
}


data "template_file" "default-ssl-conf" {
	template = file("${path.module}/default-ssl.conf")
	vars = {
	    TF-DOMAIN        = var.domain
	}
}


data "template_file" "startup_creds_sh" {
	template = file("${path.module}/startup_creds.sh")
	vars = {
		TF-DOMAIN          = var.domain
	    TF-DOMAIN-NAME     = replace(var.domain,".","_")
	    EBS_DEVICE         = "/dev/nvme1n1"
	    NOTE               = "one test"
	}
}
data "template_file" "dovecot_10_ssl" {
	template = file("${path.module}/dovecot-10-ssl.conf")
	vars = {
		TF-DOMAIN     = var.domain
	}
}



resource "null_resource" "setup_instance" { 

  depends_on = [aws_volume_attachment.user-data, aws_instance.home-server ]
  

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
        source = "${path.module}/backup_nextcloud.sh"
	    destination = "backup_nextcloud.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }
    provisioner "file" {
        source = "${path.module}/restore_nextcloud.sh"
	    destination = "restore_nextcloud.sh"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content	 
	    }  
    }
   
  provisioner "file" {
        content = data.template_file.startup_creds_sh.rendered
	    destination = "startup_creds.sh"
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
    inline = [ "echo \"successful connection ssh admin@${data.terraform_remote_state.prev.outputs.ip} \"",
           
               "sudo chmod +x startup_creds.sh",
               "sudo bash -c \"echo '${data.terraform_remote_state.prev.outputs.ip} ${var.domain} mail.${var.domain}' >> /etc/hosts\"",  
		
               #create the user and database for roundcube given the desired password.

               "sudo chmod +x expect-admin.run",
		       "sudo ./expect-admin.run && rm ./expect-admin.run", # do not enable until we have the password
		      		      		      		      
               "sudo chmod +x users_backup.sh",
               "sudo chmod +x users_restore.sh",
 
			   "sudo mv main.cf /etc/postfix/main.cf",
			   "sudo mv 10-master.conf /etc/dovecot/conf.d/10-master.conf",
			   "sudo mv 10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf",
	
			   #apt-cache madison dovecot
			   #apt list apache2 -a
		#	   "sudo apt-get install ./duplicati_2.0.6.3-1_all.deb -y", #is this too long here?
			   	
			   "cat default-ssl.conf | sudo tee -a /etc/apache2/sites-enabled/000-default.conf",
			   "rm default-ssl.conf",	
 		
 			#    "sudo mv nextcloud.conf /etc/apache2/sites-available/nextcloud.conf",
			#    "sudo mv nextcloud-le-ssl.conf /etc/apache2/sites-available/nextcloud-le-ssl.conf",
			   
			    
			    "sudo sed -i \"s|memory_limit = 128M|memory_limit = ${var.apache2_memory_limit}|g\" /etc/php/7.3/apache2/php.ini",
				"sudo sed -i \"s|upload_max_filesize = 2M|upload_max_filesize = ${var.apache2_upload_max_filesize}|g\" /etc/php/7.3/apache2/php.ini",
				"sudo sed -i \"s|post_max_size = 8M|post_max_size = ${var.apache2_post_max_size}|g\" /etc/php/7.3/apache2/php.ini",
				"sudo sed -i \"s|max_execution_time = 30|max_execution_time = ${var.apache2_max_execution_time}|g\" /etc/php/7.3/apache2/php.ini",
				"sudo sed -i \"s|;date.timezone = |date.timezone = ${var.apache2_date_timezone}|g\" /etc/php/7.3/apache2/php.ini",
				"sudo sed -i \"s|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/letsencrypt/live/${var.domain}/fullchain.pem|g\" /etc/apache2/sites-available/default-ssl.conf",
                "sudo sed -i \"s|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/letsencrypt/live/${var.domain}/privkey.pem|g\" /etc/apache2/sites-available/default-ssl.conf",
			
			
				
				"sudo systemctl start apache2",
				"sudo systemctl enable apache2",
				

		# only do this for FRESH install/?????		
		#		"cat pg_setup.sql | sudo -u postgres psql && rm pg_setup.sql",
						      
			
			# TODO: test single domain working
			# TODO: add multiple domains
			
			
 		                        
              #  sudo /sbin/adduser nate
            # map drive and check nextcloud...
            
   
				  # this does not appear to be supported on AWS 
				  # NOTE: DO NOT CALL THIS: sudo hostnamectl set-hostname ${var.email_domain}               
                       
                "echo \"Done with postfix setup.\""
             ]
  }

} 



