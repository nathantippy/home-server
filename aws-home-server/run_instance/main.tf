

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

variable "email_domain" {}
variable "region" {}
variable "pem_key_file" {}
variable "dns_impl" {}
variable "role_arn" {}
variable "access_key" {}
variable "secret_key" {}

locals {
   dns_count        = "aws"==var.dns_impl ?  1 : 0 # only set up route53 if dns_impl is set to aws
   
   key-name         = "home-server-ssh"
   instance-type    = "t4g.micro"
   max-mailbox-size = 17179869184  # in bytes 16 GB, the default for gmail is 16.
}

data "aws_caller_identity" "current" {
}


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

resource "random_string" "roundcube-pass" {
	length  = 22
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
	ami = data.aws_ami.most_recent_home-server.id
	monitoring = true
	instance_type = local.instance-type
	key_name = local.key-name
    vpc_security_group_ids = [data.terraform_remote_state.prev.outputs.security-group-id]

	user_data = data.template_file.user_data.rendered
    subnet_id = "${data.terraform_remote_state.prev.outputs.subnet-zone-a-id}"

	root_block_device {
		delete_on_termination = true
		encrypted             = true
		kms_key_id            = aws_kms_key.home-server-root-ebs.arn
		iops                  = 3000 # 3000 is free, max is 16000
		throughput            = 125  # 125 MB/s is free, max is 1000
		volume_type           = "gp3"
		volume_size           = 8 # 8G is the minimum	
		tags = {
		 	"Name" : "homeserver" 
		} 
	
	}	

#      CLEAN UP THE NAMES HERE
#      OPEN PORTS FOR SERVICES WE WILL BE RUNNING.
#      TODO: add tags for everything...
		
}




locals {
	userpass = random_string.roundcube-pass.result # "roundcube" # TODO: extract and auto generate,  TODO: also move EIP out to own state file..
	
}

data "local_file" "ssh-pem" {
   filename = "../${var.pem_key_file}"
}


data "template_file" "user_data" {
    template = file("${path.module}/../user-data.sh")
	vars = {
	    home_ebs_device = "/dev/nvme1n1"
	}
}

data "template_file" "postfix-main-cf" {
	template = file("${path.module}/../postfix-main.cf")
	vars = {
		TF-HOSTNAME         = "mail.${var.email_domain}"
		TF-DOMAIN           = var.email_domain
		TF-PRIVATE-CIDR     = data.terraform_remote_state.prev.outputs.vpc-cidr
		TF-MAX-MAILBOX_SIZE = local.max-mailbox-size # this limits risk and can be bumpted up as needed.
	}
}
data "template_file" "expect-createuser" {
	template = file("${path.module}/../expect-createuser.txt")
	vars = {
		PG_PASS  = local.userpass
	}
}
data "template_file" "expect-createdb" {
	template = file("${path.module}/../expect-createdb.txt")
	vars = {
	    PG_PASS  = local.userpass
	}
}
data "template_file" "roundcube-config-inc-php" {
	template = file("${path.module}/../config_inc_php.tpl")
	vars = {
	    PG_PASS  = local.userpass
	}
}
data "template_file" "startup_creds_sh" {
	template = file("${path.module}/startup_creds.sh")
	vars = {
		TF-DOMAIN     = var.email_domain
	}
}


resource "null_resource" "setup_instance" { 

  provisioner "file" {
	    content = data.template_file.roundcube-config-inc-php.rendered
	    destination = "config.inc.php"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	     
	    }  
   }

  provisioner "file" {
	    content = data.template_file.expect-createuser.rendered
	    destination = "expect-createuser.run"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	
	    }  
   }
   
  provisioner "file" {
	    content = data.template_file.expect-createdb.rendered
	    destination = "expect-createdb.run"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }
   
 
  provisioner "file" {
	    source = "${path.module}/letsencrypt.zip"
	    destination = "letsencrypt.zip"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	  
	    }  
   }

  provisioner "file" {
	    content = data.template_file.postfix-main-cf.rendered
	    destination = "postfix-main.cf"
	    connection {
	      type = "ssh"
	      host = data.terraform_remote_state.prev.outputs.ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	
	    }  
   }

  provisioner "file" {
        source = "${path.module}/dovecot-10-master.conf"
	    destination = "dovecot-10-master.conf"
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
      #timeout = "2m"
    }  
    inline = [ "echo \"successful connection ssh admin@${data.terraform_remote_state.prev.outputs.ip} \"",
               "ls",
               "sudo hostnamectl set-hostname ${var.email_domain}",
               
               "sudo bash -c \"echo '${data.terraform_remote_state.prev.outputs.ip} ${var.email_domain} mail.${var.email_domain}' >> /etc/hosts\"",
               "sudo DEBIAN_FRONTEND=noninteractive apt-get install postfix -y",
             
               "sudo cp /etc/postfix/main.cf{,.backup}",
               "sudo cp postfix-main.cf /etc/postfix/main.cf",
             
               "sudo postconf -n",
               "sudo rm postfix-main.cf",
               "sudo systemctl restart postfix",
              
              "sudo apt-get install dovecot-core -y", # version set in packer for script compatibility
              "sudo apt-get install dovecot-imapd -y", # version set in packer for script compatibility
              "sudo sed -i \"s|#listen = |listen = |g\" /etc/dovecot/dovecot.conf",  # 
              
              "sudo sed -i \"s|#disable_plaintext_auth = yes|disable_plaintext_auth = no|g\" /etc/dovecot/conf.d/10-auth.conf",
              "sudo sed -i \"s|auth_mechanisms = plain|auth_mechanisms = plain login|g\" /etc/dovecot/conf.d/10-auth.conf",
              
              #create the user and database for roundcube given the desired password.
              "sudo chmod +x expect-createuser.run",
              "sudo chmod +x expect-createdb.run",
			  "./expect-createuser.run || true",
              "./expect-createdb.run || true",
              
              "sudo chmod +x startup_creds.sh",
              # TODO: need to update the config and init the db...
              
              "sudo sed -i \"s|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|g\" /etc/dovecot/conf.d/10-mail.conf",
              "sudo cp dovecot-10-master.conf /etc/dovecot/conf.d/10-master.conf",
              "sudo systemctl restart dovecot.service",
              
         #     "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install roundcube roundcube-pgsql roundcube-plugins roundcube-plugins-extra php-net-ldap2",           
             
                         #  "sudo unzip -o letsencrypt.zip  # password?
                         #  sudo service apache2 stop
                         #  autoexpect sudo certbot certonly --standalone -d javanut.com    ", # prompts when port 80 is open only!
                         #  sudo zip letsencrypt.zip /etc/letsencrypt/* -r -e
            
            #  apt-cache madison certbot # we need our version then pipe in the commands?             
              # sudo /sbin/adduser nate
           
                  # install roundcube now that we have the domain name       
                      
              "echo \"Done with postfix setup.\""
             ]
  }

  #triggers = { always = timestamp() } # comment this out so we only run on instance creation.

} //    */




