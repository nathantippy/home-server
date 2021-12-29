bucket         = "terra-arch-remote-state-478534051034"
encrypt        = true
region         = "us-east-2"
dynamodb_table = "terra-arch-remote-state-locks"
key  =  "home-server.tfstate"
role_arn  =  "arn:aws:iam::478534051034:role/server-builder-role"
