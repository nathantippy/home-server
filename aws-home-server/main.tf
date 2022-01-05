

terraform {
  
  backend "s3" {
  }
  
  required_providers {
    aws = ">= 3.1.0"  
    local = ">= 2.1.0"
    template = ">= 2.2.0"  
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

variable "region" {
	default = "us-east-2"
}

variable "pub_key_file" { 
}
variable "pem_key_file" { 
}

variable "role_arn" { 
}
variable "access_key" {
}
variable "secret_key" {
}

locals {
   key-name = "home-server-ssh"  
   instance-type = "t4g.micro"
   bbb = "bbb"
}

data "aws_caller_identity" "current" {
}

data "local_file" "pub-key" {
   filename = var.pub_key_file
}
data "local_file" "ssh-pem" {
   filename = var.pem_key_file
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

resource "aws_key_pair" "deployer" {
  key_name   = local.key-name
  public_key = "${data.local_file.pub-key.content}"
}

resource "aws_vpc" "test-env" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  
}
resource "aws_eip" "primary-eip" {
  instance = "${aws_instance.home-server.id}"
  vpc      = true
}

output "ip" {
	value = aws_eip.primary-eip.public_ip
}
output "command" {
	value = "sudo ssh -i ./keep/home-server-ssh.pem admin@${aws_eip.primary-eip.public_ip}"
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.test-env.id}"

}
resource "aws_subnet" "subnet-uno" {
  cidr_block = "${cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.test-env.id}"
  availability_zone = "${var.region}a" 
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.test-env.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }

}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.subnet-uno.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}

resource "aws_kms_key" "home-server-root-ebs" {
  description             = "Home Server Root EBS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_instance" "home-server" {
	ami = data.aws_ami.most_recent_home-server.id
	monitoring = true
	instance_type = local.instance-type
	key_name = local.key-name
    security_groups = ["${aws_security_group.home-server.id}"]

    subnet_id = "${aws_subnet.subnet-uno.id}"

	root_block_device {
		delete_on_termination = false
		encrypted             = true
		kms_key_id            = aws_kms_key.home-server-root-ebs.id
		iops                  = 3000 # 3000 is free, max is 16000
		throughput            = 125  # 125 MB/s is free, max is 1000
		volume_type           = "gp3"
		volume_size           = 80  # in GB should be >= 8 for debian etc all,  can modify without source replacement!
	
	
	}	

#      CLEAN UP THE NAMES HERE
#      OPEN PORTS FOR SERVICES WE WILL BE RUNNING.
#      TODO: add tags for everything...
		
}



resource "aws_security_group" "home-server" {
   name = "home-server-sg" # needs more unique name...
   vpc_id = "${aws_vpc.test-env.id}"
   ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "null_resource" "setup_proxy" { 

  provisioner "file" {
	    content = "hello world"
	    destination = "test.txt"
	    connection {
	      type = "ssh"
	      host = aws_eip.primary-eip.public_ip
	      user = "admin"
	      private_key = data.local_file.ssh-pem.content
	    }  
    }

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = aws_eip.primary-eip.public_ip
      user = "admin"
      private_key = data.local_file.ssh-pem.content
    }  
    inline = [ "echo \"successful connection ssh admin@${aws_eip.primary-eip.public_ip} \"",
               "ls",
               "echo \"Done with this.\""
             ]
  }

  triggers = { always = timestamp() } # comment this out so we only run on instance creation.

}




