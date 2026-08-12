terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------
# Variáveis
# ---------------------------------------------------------
variable "aws_region" {
  type        = string
  description = "Região da AWS"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2"
  default     = "t2.micro"
}

variable "key_name" {
  type        = string
  description = "Nome da chave SSH cadastrada na AWS (Padrão AWS Academy: vockey)"
  default     = "vockey"
}

variable "private_key_path" {
  type        = string
  description = "Caminho relativo para a chave privada SSH local"
  default     = "./labsuser.pem"
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
# Security Group para SSH (22) e HTTP (80)
# ---------------------------------------------------------
resource "aws_security_group" "zero_touch_sg" {
  name        = "zero-touch-web-sg"
  description = "Permite acesso SSH e HTTP para esteira automatizada Zero-Touch"

  ingress {
    description = "SSH para o Ansible"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP para validacao da aplicacao"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Trafego de saida liberado"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "zero-touch-sg"
    ManagedBy = "Terraform"
  }
}

# ---------------------------------------------------------
# Instância EC2
# ---------------------------------------------------------
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.zero_touch_sg.id]

  tags = {
    Name      = "Servidor-Zero-Touch"
    ManagedBy = "Terraform-Ansible"
  }
}

# ---------------------------------------------------------
# 1. Geração Automática do Arquivo inventory.ini pelo Terraform
# ---------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = <<-EOT
  [webservers]
  servidor-zero-touch ansible_host=${aws_instance.web_server.public_ip}

  [webservers:vars]
  ansible_user=ubuntu
  ansible_ssh_private_key_file=${var.private_key_path}
  ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT

  filename = "${path.module}/inventory.ini"
}

# ---------------------------------------------------------
# 2. Execução Automatizada do Ansible via local-exec
# ---------------------------------------------------------
resource "null_resource" "trigger_ansible" {
  depends_on = [
    aws_instance.web_server,
    local_file.ansible_inventory
  ]

  # Gatilho para reexecutar se a instância for recriada
  triggers = {
    instance_id = aws_instance.web_server.id
  }

  # Aguarda a porta SSH da máquina responder antes de invocar o Ansible
  provisioner "remote-exec" {
    inline = ["echo 'SSH está ativo e pronto para receber o Ansible!'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = aws_instance.web_server.public_ip
      timeout     = "3m"
    }
  }

  # Dispara o Ansible Playbook automaticamente na máquina local/Codespaces
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local_file.ansible_inventory.filename} playbook.yml"
  }
}

# ---------------------------------------------------------
# Outputs
# ---------------------------------------------------------
output "instance_id" {
  description = "ID da instância EC2 provisionada"
  value       = aws_instance.web_server.id
}

output "public_ip" {
  description = "Endereço IP público do servidor"
  value       = aws_instance.web_server.public_ip
}

output "web_url" {
  description = "URL HTTP de acesso à aplicação recém-configurada"
  value       = "http://${aws_instance.web_server.public_ip}"
}
