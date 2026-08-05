terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Substitua pela sua região
}

data "aws_secretsmanager_secret_version" "example" {
  secret_id = "database_credentials2" # Substitua pelo nome do seu segredo
}

resource "aws_instance" "secrets_instance" {
  ami           = "ami-00ca32bbc84273381" # Substitua pela AMI da sua região
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "Username: ${jsondecode(data.aws_secretsmanager_secret_version.example.secret_string)["username"]}" > /tmp/secrets.txt
              echo "Password: ${jsondecode(data.aws_secretsmanager_secret_version.example.secret_string)["password"]}" >> /tmp/secrets.txt
              EOF

  tags = {
    Name = "Instance with Secrets"
  }
}