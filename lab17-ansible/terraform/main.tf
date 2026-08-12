terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------
# Variáveis de Entrada
# ---------------------------------------------------------
variable "aws_region" {
  type        = string
  description = "Região da AWS"
  default     = "us-east-1"
}

variable "instance_count" {
  type        = number
  description = "Quantidade de servidores a serem provisionados"
  default     = 2
}

variable "instance_type" {
  type        = string
  description = "Tipo das instâncias EC2"
  default     = "t2.micro"
}

variable "key_name" {
  type        = string
  description = "Nome da chave SSH cadastrada na AWS (Padrão AWS Academy: vockey)"
  default     = "vockey"
}

# ---------------------------------------------------------
# Data Source: Busca da AMI Ubuntu 22.04 LTS mais recente
# ---------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------
# Security Group com portas 22 (SSH) e 80 (HTTP) abertas
# ---------------------------------------------------------
resource "aws_security_group" "web_ansible_sg" {
  name        = "ansible-web-sg"
  description = "Permite acesso SSH e HTTP para servidores gerenciados via Ansible"

  ingress {
    description = "Acesso SSH para o Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Acesso HTTP para testes da aplicacao"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Trafego de saida liberado para download de pacotes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "ansible-web-sg"
    ManagedBy = "Terraform"
  }
}

# ---------------------------------------------------------
# Provisionamento Multi-Host de Instâncias EC2
# ---------------------------------------------------------
resource "aws_instance" "web_servers" {
  count                  = var.instance_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_ansible_sg.id]

  tags = {
    Name        = "Servidor-Web-0${count.index + 1}"
    Environment = "Laboratorio-Ansible"
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------
output "public_ips" {
  description = "Lista de IPs publicos das instancias para o inventario do Ansible"
  value       = aws_instance.web_servers[*].public_ip
}

output "web_urls" {
  description = "URLs HTTP para testar os servidores no navegador"
  value       = [for ip in aws_instance.web_servers[*].public_ip : "http://${ip}"]
}