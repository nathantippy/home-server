

locals {
	root_name             = "terra-arch-remote-state"
	terraform-role-name   = "${local.root_name}"
    table_name            = "${local.root_name}-locks"
    bucket_name           = "${local.root_name}-${data.aws_caller_identity.current.account_id}"
   
    region                = "us-east-2"
    home-server-user-name = "home-server-builder"
   
}

terraform {
  
  required_providers {
    aws = ">= 3.1.0"    
  }
  
  required_version = "~> 1.1.2"
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
data "aws_iam_policy_document" "iam-role-policy" {
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


resource "aws_iam_role" "terraform-role" {
  name               = local.terraform-role-name
  description        = "Allows access to all Terraform workspaces"
  assume_role_policy = data.aws_iam_policy_document.backend-assume-role.json
  tags = {
  	"terraform-arch":"foundational"
  }
}
resource "aws_iam_role_policy" "terraform-role" {
  name   = local.terraform-role-name
  policy = data.aws_iam_policy_document.iam-role-policy.json
  role   = local.terraform-role-name
  depends_on = [aws_iam_role.terraform-role]
}
data "aws_iam_policy_document" "backend-assume-role" {
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
resource "aws_iam_access_key" "home-server-user-key" {
  user = aws_iam_user.home-server-user.name
}

/////////////////////////////////////////////////////


data "template_file" "home-server-setup" {
  template = "${file("${path.module}/home-server-setup.tpl")}"
  vars = {
    secret_key = aws_iam_access_key.home-server-user-key.secret
    access_key = aws_iam_access_key.home-server-user-key.id 
    role_arn   = aws_iam_role.terraform-role.arn
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


