
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

variable "domain" {}
variable "region" {}
variable "pub_key_file" {}
variable "role_arn" {}
variable "access_key" {}
variable "secret_key" {}

variable "volume_iops" {
	default = 3000  # 3000 is free, max is 16000 - not used for sc1
}
variable "volume_throughput" {
 	default = 125  # 125 MB/s is free, max is 1000 - not used for sc1
}
variable "volume_type" {          
	default = "gp3" 
}
variable "volume_size" {
 	default = 48  # 8G is the minimum but we need room for lots of email, 125 is smallest for sc1	
}



locals {
   key-name               = "home-server-${replace(var.domain,".","-")}-ssh"
   vpn_cidr               = "10.10.10.0/24"
}

data "aws_caller_identity" "current" {
}


data "local_file" "pub-key" {
   filename = "../${var.pub_key_file}"
}
resource "aws_key_pair" "deployer" {
  key_name   = local.key-name
  public_key = "${data.local_file.pub-key.content}"
}


resource "aws_eip" "primary-eip" { # TODO: move to new TF with route53 logic..
  vpc      = true  
}


resource "aws_vpc" "home-server" {
  cidr_block = local.vpn_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags =  {
  	Name = "home-server-${replace(var.domain,".","-")}"
  }
}

resource "null_resource" "setup_reverse_dns" { 
	# terraform can not do this yet so we do it manually ..
	#aws ec2 modify-address-attribute \
	#    --allocation-id eipalloc-abcdef01234567890 \
	#    --domain-name example.com
  provisioner "local-exec" {

  command = <<EOF
    SESSION=$(aws sts assume-role --role-arn ${var.role_arn} --role-session-name terraform-local-exec);
    env -u AWS_SECURITY_TOKEN bash -c "\
    export AWS_ACCESS_KEY_ID=$(echo $SESSION | jq -r .Credentials.AccessKeyId); 
    export AWS_SECRET_ACCESS_KEY=$(echo $SESSION | jq -r .Credentials.SecretAccessKey); 
    export AWS_SESSION_TOKEN=$(echo $SESSION | jq -r .Credentials.SessionToken); 
    aws ec2 modify-address-attribute --allocation-id ${aws_eip.primary-eip.id} --domain-name ${var.domain} --region ${var.region} "
EOF
    environment = {
      AWS_ACCESS_KEY_ID = var.access_key
      AWS_SECRET_ACCESS_KEY = var.secret_key
    }  
  }
}


resource "aws_secretsmanager_secret" "home_server" {
    name = "home_server/${var.domain}"
}

output "home-server-secret-id" {
  value = aws_secretsmanager_secret.home_server.id
}
output "ip-arn" {
	value = aws_eip.primary-eip.id
}
output "ip" {
	value = aws_eip.primary-eip.public_ip
}
output "vpc-cidr" {
	value = aws_vpc.home-server.cidr_block
}
output "vpc-id" {
    value = aws_vpc.home-server.id
}
output "user-data-volume-id" {
	value = aws_ebs_volume.cheap-data.id
}
output "subnet-zone-a-id" {
	value = aws_subnet.home-region-a.id
}
output "subnet-zone-b-id" {
	value = aws_subnet.home-region-b.id
}
output "subnet-zone-c-id" {
	value = aws_subnet.home-region-c.id
}
output "security-group-id" {
	value = aws_security_group.home-server.id
}

resource "aws_subnet" "home-region-a" {
  cidr_block = "${cidrsubnet(aws_vpc.home-server.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.home-server.id}"
  availability_zone = "${var.region}a" 
}
resource "aws_subnet" "home-region-b" {
  cidr_block = "${cidrsubnet(aws_vpc.home-server.cidr_block, 3, 2)}"
  vpc_id = "${aws_vpc.home-server.id}"
  availability_zone = "${var.region}b" 
}
resource "aws_subnet" "home-region-c" {
  cidr_block = "${cidrsubnet(aws_vpc.home-server.cidr_block, 3, 3)}"
  vpc_id = "${aws_vpc.home-server.id}"
  availability_zone = "${var.region}c" 
}


resource "aws_kms_key" "home-server-cheap-data" {
  description             = "${var.domain} Users Data EBS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_ebs_volume" "cheap-data" {
  availability_zone = aws_subnet.home-region-a.availability_zone
  encrypted         = true
  
  type              = var.volume_type
  size              = var.volume_size

  iops              = ("sc1"==var.volume_type || "st1"==var.volume_type) ? null : var.volume_iops
  throughput        = ("sc1"==var.volume_type || "st1"==var.volume_type) ? null : var.volume_throughput 
  kms_key_id        = aws_kms_key.home-server-cheap-data.arn
  
  tags = {
 	"Name" : "homeserver-users-${replace(var.domain,".","-")}" 
  } 
}


resource "aws_security_group" "home-server" { 
   name = "home-server-${replace(var.domain,".","-")}"
   vpc_id = aws_vpc.home-server.id
   ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }  
  ingress { # http for roundcube and matrix
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }  
  ingress { # https for roundcube and matrix
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }  
  ingress { # http for cockpit
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 9090
    to_port = 9090
    protocol = "tcp"
  }  
 
  ingress { # SMTP email 25 !!!
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 25
    to_port = 25
    protocol = "tcp"
  }
  ingress { # SMTP SSL/TLS email 465  
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 465
    to_port = 465
    protocol = "tcp"
  } 
  ingress { # SMTP SSL/TLS & STARTTLS email 587  - not working or used.
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 587
    to_port = 587
    protocol = "tcp"
  }

  ingress { # IMAP STARTTLS AND NONE email 143  !!!
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 143
    to_port = 143
    protocol = "tcp"
  }
  ingress { # IMAP SSL/TLS   !!!
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 993
    to_port = 993
    protocol = "tcp"
  }
  
  ingress { # pop3 SSL/TLS
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 995
    to_port = 995
    protocol = "tcp"
  }
    ingress { # pop3 STARTTLS and NONE
   cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 110
    to_port = 110
    protocol = "tcp"
  }
  
  
    ingress {
    description      = "ping"
    from_port        = 8
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    description      = "packet_too_big_please_fragment"
    from_port        = 3
    to_port          = 4
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "time_exceeded"
    from_port        = 11
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "traceroute"
    from_port        = 30
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
// Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

########## setup for duplicati

resource "aws_iam_user" "duplicati-user" {
  name = "duplicati_${replace(var.domain,".","-")}"
  tags = {
  	"terraform-arch":"duplicati"
  }
}
resource "aws_iam_access_key" "duplicati-user-key" {
  user = aws_iam_user.duplicati-user.name
}

output "duplicati-user_id" {
	value = aws_iam_access_key.duplicati-user-key.id
}
output "duplicati-user_secret" {
	value = aws_iam_access_key.duplicati-user-key.secret
	sensitive = true

}

resource "aws_iam_user_policy" "inline-duplicati-policy" {
  name = "duplicati-policy"
  user = aws_iam_user.duplicati-user.name
 
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [ "s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject" ],
      "Effect": "Allow",
      "Resource": [ "arn:aws:s3:::${local.backup_bucket_id}",
                    "arn:aws:s3:::${local.backup_bucket_id}/*" ]
    }
  ]
}
EOF
}

resource "aws_s3_bucket_server_side_encryption_configuration" "home-backup" {
  bucket = aws_s3_bucket.home-backup.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


locals {
	backup_bucket_id = "${lower(aws_iam_access_key.duplicati-user-key.id)}-duplicati-${replace(var.domain,".","-")}"
}

output "backup-bucket-id" {
	value = local.backup_bucket_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "home-backup" {
  bucket = aws_s3_bucket.home-backup.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket" "home-backup" {
  bucket = "${local.backup_bucket_id}"
  acl    = "private"
  versioning {
    enabled = "false"
  }

  tags = {
  	"terraform-arch":"duplicati"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "home-backup-archive" {
  bucket = aws_s3_bucket.home-backup-archive.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket" "home-backup-archive" {
  bucket = "${local.backup_bucket_id}-archive"
  acl    = "private"
  versioning {
    enabled = "false"
  }

  tags = {
  	"terraform-arch":"archive"
  }
}

########## end of duplicati setup


# OPTIONAL: dns mapping, this may be external...??
/*
resource "aws_route53_zone" "main" {
  name = "example.com"
  tags = {
  }
}

resource "aws_route53_zone" "dev" {
  name = "dev.example.com"

  tags = {
    Environment = "dev"
  }
}

resource "aws_route53_record" "dev-ns" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "dev.example.com"
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.dev.name_servers
}*/
