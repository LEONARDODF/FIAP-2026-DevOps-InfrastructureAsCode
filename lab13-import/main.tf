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

resource "aws_instance" "example" {
  ami           = "ami-0bdc7d025135d7b49"  # Substitua pela AMI da sua região
  instance_type = "t3.micro"

  tags = {
    Name = "Teste Import"
  }
}