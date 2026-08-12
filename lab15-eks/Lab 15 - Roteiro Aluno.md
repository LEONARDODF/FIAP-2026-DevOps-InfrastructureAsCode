# LAB 15: Provisionamento de Cluster Kubernetes com Amazon EKS

Este laboratório prático guiará você no provisionamento automatizado de um cluster **Amazon EKS (Elastic Kubernetes Service)** utilizando o Terraform. Você aprenderá como construir uma arquitetura de rede multi-AZ resiliente (com VPC, subnets públicas e privadas em 3 zonas de disponibilidade), configurar o Control Plane gerenciado do Kubernetes e criar um Node Group de *worker nodes* EC2. Este laboratório será executado diretamente na **AWS Real** (AWS Academy).

---

## 🎯 Objetivos de Aprendizado
- Projetar uma topologia de rede segura e recomendada pela AWS para clusters EKS (com subnets privadas para os nós de trabalho).
- Integrar os papéis do IAM (`LabRole` da AWS Academy) via Data Source para Control Plane e Worker Nodes.
- Provisionar o cluster Kubernetes (`aws_eks_cluster`) e o Node Group gerenciado (`aws_eks_node_group`) com configurações de Auto Scaling.
- Autenticar e conectar a ferramenta de linha de comando `kubectl` ao cluster criado via AWS CLI.
- Inspecionar a saúde dos nós do cluster e desprovisionar a infraestrutura de forma limpa.

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 1: Preparação do Ambiente
1. Certifique-se de que suas credenciais temporárias da `AWS Academy` estão ativas no arquivo `~/.aws/credentials`.
2. Garanta que as ferramentas `aws` (AWS CLI) e `kubectl` estejam instaladas no seu ambiente/terminal do Codespaces.

---

### Passo 2: Analisar a Estrutura no `main.tf`
Abra o arquivo `main.tf` na pasta `lab15-eks/` e observe os blocos principais:

1. **Topologia de Rede:**
   - O código cria uma VPC (`10.0.0.0/16`) com 3 subnets privadas (onde os nós do Kubernetes residirão por segurança) e 3 subnets públicas distribuídas em 3 Availability Zones (`us-east-1a`, `us-east-1b`, `us-east-1c`).
2. **Reaproveitamento de Permissões (LabRole):**
   ```hcl
   data "aws_iam_role" "lab_role" {
     name = "LabRole"
   }
   ```
   No ambiente da AWS Academy, utilizaremos a role padrão `LabRole` que possui as permissões necessárias para o Control Plane do EKS e para os worker nodes.
3. **Cluster EKS e Node Group:**
   ```hcl
   resource "aws_eks_cluster" "eks_cluster" {
     name     = var.cluster_name
     role_arn = data.aws_iam_role.lab_role.arn
     version  = var.eks_version

     vpc_config {
       subnet_ids = concat(aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id)
     }
   }

   resource "aws_eks_node_group" "eks_node_group" {
     cluster_name    = aws_eks_cluster.eks_cluster.name
     node_group_name = "eks-node-group"
     node_role_arn   = data.aws_iam_role.lab_role.arn
     subnet_ids      = aws_subnet.public_subnets[*].id # Subnets publicas para registro rapido dos nos

     scaling_config {
       desired_size = var.desired_size # Padrão: 2
       max_size     = var.max_size     # Padrão: 3
       min_size     = var.min_size     # Padrão: 1
     }
   }
   ```

---

### Passo 3: Executar o Provisionamento do Cluster
No terminal do seu Codespaces, navegue para a pasta e aplique a infraestrutura:

1. **Navegar para a pasta do Lab 15:**
   ```bash
   cd lab15-eks
   ```
2. **Inicializar o Terraform:**
   ```bash
   terraform init
   ```
3. **Aplicar o Provisionamento:**
   ```bash
   terraform apply
   ```
   *Digite **`yes`** e aperte `Enter` para confirmar.*

> [!NOTE]
> **Tempo de Espera:** O provisionamento do cluster EKS e da infraestrutura de rede na AWS leva em média de **10 a 15 minutos**. Aguarde a conclusão do comando até que a mensagem `Apply complete!` seja exibida.

---

### Passo 4: Conectar ao Cluster com `kubectl`
Após o término com sucesso do `terraform apply`, configure o seu arquivo de contexto do Kubernetes (`kubeconfig`):

1. **Atualizar o Kubeconfig local via AWS CLI:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name eks-cluster
   ```
2. **Validar a Saúde dos Nós do Cluster:**
   Execute o comando `kubectl` para listar os *worker nodes* em execução:
   ```bash
   kubectl get nodes
   ```
   *Você deverá ver 2 nós EC2 com o status `Ready`.*

3. **Inspecionar os Pods do Sistema:**
   ```bash
   kubectl get pods -n kube-system
   ```
   *Confirme que os pods do CoreDNS, kube-proxy e aws-node estão em execução (`Running`).*

---

## 🔍 Pontos de Validação Prática

1. **Console AWS:**
   Navegue até o serviço **Amazon EKS** no Console AWS e selecione o cluster `eks-cluster`. Verifique na aba **Compute** se o Node Group `eks-node-group` está ativo e com os nós saudáveis.

---

## 🧹 Limpeza do Ambiente
Como os clusters EKS e instâncias EC2 geram custos por hora, é fundamental destruir os recursos ao final da atividade:

1. **Destruir a Infraestrutura:**
   ```bash
   terraform destroy
   ```
   *Digite **`yes`** para confirmar. A destruição também pode levar cerca de 10 minutos.*
