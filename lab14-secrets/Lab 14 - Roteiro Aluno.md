# LAB 14: Integração com AWS Secrets Manager (Gerenciamento de Segredos)

Este laboratório prático guiará você na integração do Terraform com o **AWS Secrets Manager**. Nas melhores práticas de DevSecOps, credenciais sensíveis (como usuários, senhas de banco de dados e tokens de API) nunca devem ser gravadas diretamente (*hardcoded*) nos arquivos de código HCL nem commitadas em repositórios Git. Você aprenderá como consumir segredos armazenados de forma centralizada na AWS e injetá-los dinamicamente em recursos no momento do provisionamento. Este laboratório será executado diretamente na **AWS Real** (AWS Academy).

---

## 🎯 Objetivos de Aprendizado
- Compreender os riscos de credenciais expostas em código de infraestrutura.
- Criar e gerenciar um segredo no formato JSON no AWS Secrets Manager.
- Utilizar o data source `aws_secretsmanager_secret_version` para consultar segredos dinamicamente via Terraform.
- Manipular dados sensíveis em formato JSON utilizando a função nativa `jsondecode()`.
- Injetar credenciais com segurança no bootstrap (`user_data`) de uma instância EC2.

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 1: Criar o Segredo no AWS Secrets Manager
Antes de executar o Terraform, precisamos ter um segredo cadastrado na AWS:

1. **Acessar o Console AWS:**
   Navegue até o serviço **Secrets Manager** no Console AWS (na região `us-east-1`).
2. **Armazenar um Novo Segredo:**
   - Clique em **Store a new secret**.
   - Selecione o tipo **Other type of secret**.
   - Na seção **Key/value pairs**, adicione os seguintes pares:
     - **Key:** `username` | **Value:** `admin`
     - **Key:** `password` | **Value:** `S3cureP@ssw0rd!2026`
   - Clique em **Next**.
3. **Definir o Nome do Segredo:**
   - No campo **Secret name**, digite exatamente: `database_credentials2`
   - Clique em **Next** nas etapas seguintes e finalize clicando em **Store**.

---

### Passo 2: Analisar a Estrutura no `main.tf`
Abra o arquivo `main.tf` na pasta `lab14-secrets/` e observe como o segredo é recuperado e utilizado:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_secretsmanager_secret_version" "example" {
  secret_id = "database_credentials2"
}

resource "aws_instance" "secrets_instance" {
  ami           = "ami-00ca32bbc84273381"
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
```

*   `data "aws_secretsmanager_secret_version"` realiza a busca da versão ativa do segredo `database_credentials2` no Secrets Manager.
*   `jsondecode(...)` converte a string em formato JSON retornada pela AWS em um mapa acessível pelo Terraform, permitindo obter as chaves `["username"]` e `["password"]`.
*   O bloco `user_data` injeta o script de inicialização do Linux na criação da máquina para escrever essas informações em um arquivo local temporário (`/tmp/secrets.txt`).

---

### Passo 3: Executar a Infraestrutura
No terminal do seu Codespaces, navegue para a pasta e aplique a infraestrutura:

1. **Navegar para a pasta do Lab 14:**
   ```bash
   cd lab14-secrets
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

---

## 🔍 Pontos de Validação Prática

1. **Verificar a Criação da Instância:**
   Após a conclusão com sucesso, acesse o Console EC2 da AWS e localize a instância nomeada **`Instance with Secrets`**.
2. **Aviso de Segurança (State File):**
   *Atenção:* Embora o código HCL não contenha senhas explícitas, valores recuperados de data sources sensíveis ficam registrados em texto claro dentro do arquivo `terraform.tfstate`. Por isso, o arquivo de estado sempre deve ser armazenado em um backend remoto seguro (como um Bucket S3 criptografado) com acesso estritamente restrito.

---

## 🧹 Limpeza do Ambiente
Para evitar custos acumulados na AWS Academy, remova os recursos criados:
```bash
terraform destroy
```
*Digite **`yes`** para confirmar a destruição da infraestrutura.*
*(Opcional: Você também pode remover o segredo `database_credentials2` diretamente no Console do Secrets Manager).*
