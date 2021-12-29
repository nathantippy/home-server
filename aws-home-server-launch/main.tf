

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
  region = "us-east-2"

  access_key = var.access_key
  secret_key = var.secret_key

  assume_role {
    role_arn = var.role_arn #"arn:aws:iam::478534051034:role/DevRole"
  }
    
}

variable "pub_key_file" { //required
}
variable "role_arn" {  //#todo: 
}
variable "access_key" {
}
variable "secret_key" {
}

locals {
   key-name = "home-server-ssh"  
   instance-type = "t4g.micro"
}

data "aws_caller_identity" "current" {
}

data "local_file" "pub-key" {
  filename = var.pub_key_file
}

data "aws_ami" "most_recent_home-server" {
	most_recent = true
	filter {
		name = "name"
		values = ["debian_arm_SNAPSHOT"] # RENAME AS HOME SERVER
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
resource "aws_eip" "ip-test-env" {
  instance = "${aws_instance.home-server.id}"
  vpc      = true
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.test-env.id}"

}
resource "aws_subnet" "subnet-uno" {
  cidr_block = "${cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.test-env.id}"
  availability_zone = "us-east-1a"
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
resource "aws_instance" "home-server" {
	ami = data.aws_ami.most_recent_home-server.id
	monitoring = true
	instance_type = local.instance-type
	key_name = local.key-name
 security_groups = ["${aws_security_group.ingress-all-test.id}"]

subnet_id = "${aws_subnet.subnet-uno.id}"

#todo: set exernal EBS root volume
#      CLEAN UP THE NAMES HERE
#      ADD ROUTE53 ASSIGNEMENT
#      OPEN PORTS FOR SERVICES WE WILL BE RUNNING.
	
	
}

resource "aws_security_group" "ingress-all-test" {
name = "allow-all-sg"
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

