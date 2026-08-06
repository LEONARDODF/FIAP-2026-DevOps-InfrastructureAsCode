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

# Variáveis
variable "cluster_name" {
  type = string
  default = "eks-cluster"
  description = "Nome do cluster EKS"
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
  description = "CIDR da VPC"
}

variable "availability_zones" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
  description = "Lista de Availability Zones"
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  description = "Lista de CIDRs das sub-redes privadas"
}

variable "public_subnet_cidrs" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  description = "Lista de CIDRs das sub-redes públicas"
}

variable "eks_version" {
  type = string
  default = "1.36"
  description = "Versão do Kubernetes"
}

variable "desired_size" {
  type = number
  default = 2
  description = "Tamanho desejado do Node Group"
}

variable "max_size" {
  type = number
  default = 3
  description = "Tamanho máximo do Node Group"
}

variable "min_size" {
  type = number
  default = 1
  description = "Tamanho mínimo do Node Group"
}

# Recursos

# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "eks-private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "eks-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count = length(var.public_subnet_cidrs)
  subnet_id = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Data Source para obter o ARN do LabRole
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name
  role_arn = data.aws_iam_role.lab_role.arn
  version = var.eks_version

  vpc_config {
    subnet_ids = aws_subnet.private_subnets[*].id
  }

  tags = {
    Name = var.cluster_name
  }
}

# Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn = data.aws_iam_role.lab_role.arn
  subnet_ids = aws_subnet.private_subnets[*].id
  version = var.eks_version

  scaling_config {
    desired_size = var.desired_size
    max_size = var.max_size
    min_size = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "eks-node-group"
  }
}

# Outputs
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "kubeconfig" {
  value = <<EOF
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks_cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority[0].data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${aws_eks_cluster.eks_cluster.name}"
      # This is intentional, to avoid prompting the user to install the plugin.
      # The result of this command is used by kubectl to authenticate to the cluster.
      provideClusterInfo: false
EOF
  sensitive = true
}