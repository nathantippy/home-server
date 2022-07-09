terraform {
  
  required_providers {
    aws = ">= 3.1.0"  
    local = ">= 2.1.0"
    template = ">= 2.2.0"  
  }
  
  required_version = "~> 1.1.2"
}


locals {
	root_name             = "terra-arch-remote-state"
	terraform-policy-name = "${local.root_name}"
    table_name            = "${local.root_name}-locks"
    bucket_name           = "${local.root_name}-${data.aws_caller_identity.current.account_id}"
   
    region                = "us-east-2"
    home-server-user-name = "server-builder"

}

variable "access_key" { # NOTE: this is the admin key
}
variable "secret_key" { # NOTE: this is the admin key
}
provider "aws" {
  region     = local.region
  access_key = var.access_key
  secret_key = var.secret_key
}

data "aws_caller_identity" "current" {}


////////////////////////////////////

resource "aws_s3_bucket" "tf-remote-state" {
  bucket = local.bucket_name
  acl    = "private"
  versioning {
    enabled = "true"
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = {
  	"terraform-arch":"foundational"
  }
}

resource "aws_dynamodb_table" "tf-remote-state" {
  name         = local.table_name
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
  	"terraform-arch":"foundational"
  }
}


resource "aws_iam_role" "home-server-role" {
  name               = "${local.home-server-user-name}-role"
  description        = "Allows access to build servers using terraform"
  assume_role_policy = data.aws_iam_policy_document.principal-identifiers.json
  max_session_duration = 14400
  tags = {
  	"terraform-arch":"foundational"
  }
}

///////////////////////////////////////////////////////////////////

data "aws_iam_policy_document" "terraform-state-role-policy" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.bucket_name}"]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${local.bucket_name}/*"]
  }
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:*:*:table/${local.table_name}"]
  }
}
resource "aws_iam_role_policy" "home-server-terraform-policy" {
  name   = "${local.terraform-policy-name}-policy"
  policy = data.aws_iam_policy_document.terraform-state-role-policy.json
  role   = "${local.home-server-user-name}-role"
  depends_on = [aws_iam_role.home-server-role]
}

/////////////////////////////////////////////////////////////////

data "aws_iam_policy_document" "packer-role-policy" {
  statement {
    actions   = ["ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteKeyPair",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteVolume",
                "ec2:DeregisterImage",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeRegions",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:GetPasswordData",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances"]
    resources = ["*"]
  }

}
resource "aws_iam_role_policy" "home-server-packer-policy" {
  name   = "${local.home-server-user-name}-packer-policy"
  policy = data.aws_iam_policy_document.packer-role-policy.json
  role   = "${local.home-server-user-name}-role"
  depends_on = [aws_iam_role.home-server-role]
}

# TODO: restrict once we know what we need.
data "aws_iam_policy_document" "server-launch-role-policy" {
  statement {
    actions   = ["secretsmanager:*","ec2:*","kms:*","iam:*","s3:*"]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "home-server-launch-policy" {
  name   = "${local.home-server-user-name}-launch-policy"
  policy = data.aws_iam_policy_document.server-launch-role-policy.json
  role   = "${local.home-server-user-name}-role"
  depends_on = [aws_iam_role.home-server-role]
}
///////////////////////////////////////////////////////////////////////////////

data "aws_iam_policy_document" "principal-identifiers" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${local.home-server-user-name}"]
    }
  }
}

resource "aws_iam_user" "home-server-user" {
  name = local.home-server-user-name
  tags = {
  	"terraform-arch":"foundational"
  }
}
resource "aws_iam_user_policy" "home-server-assume-role" {
  name = "assume-role"
  user = aws_iam_user.home-server-user.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_access_key" "home-server-user-key" {
  user = aws_iam_user.home-server-user.name
}

/////////////////////////////////////////////////////
//  build output files
/////////////////////////////////////////////////////

data "template_file" "home-server-setup" {
  template = "${file("${path.module}/home-server-setup.tpl")}"
  vars = {
    secret_key = aws_iam_access_key.home-server-user-key.secret
    access_key = aws_iam_access_key.home-server-user-key.id 
    role_arn   = aws_iam_role.home-server-role.arn
    region     = local.region
  }
}

data "template_file" "remote-state" {
  template = "${file("${path.module}/remote-state.tpl")}"
  vars = {
  		bucket = local.bucket_name   # aws_s3_bucket.tf-remote-state.id
  		region = local.region
  		table  = local.table_name   # aws_dynamodb_table.tf-remote-state.id
  }
}

resource "local_file" "home-server-setup" {
    content  = data.template_file.home-server-setup.rendered
    filename = "home-server-setup.sh"
}
resource "local_file" "remote-state" {
    content  = data.template_file.remote-state.rendered
    filename = "remote-state.tfvars"
}


