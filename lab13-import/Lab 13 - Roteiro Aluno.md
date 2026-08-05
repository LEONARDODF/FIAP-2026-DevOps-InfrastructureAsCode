# LAB 13: Importação de Infraestrutura Existente (Terraform Import)

Este laboratório prático guiará você no processo de importação de infraestruturas pré-existentes (*brownfield*) para dentro do gerenciamento do Terraform utilizando o comando `terraform import`. Você aprenderá como vincular recursos criados manualmente no Console AWS ao estado (`terraform.tfstate`) e ao código HCL, permitindo assumir o controle e governança da infraestrutura sem a necessidade de recriá-la. Este laboratório será executado diretamente na **AWS Real** (AWS Academy).

---

## 🎯 Objetivos de Aprendizado
- Compreender a diferença entre cenários de infraestrutura *Greenfield* (novos) e *Brownfield* (existentes).
- Declarar recursos "esqueleto" no arquivo `main.tf` para receber o estado importado.
- Executar o comando CLI `terraform import` associando o ID do recurso AWS ao bloco HCL.
- Inspecionar e alinhar discrepâncias (*drift*) entre o estado importado e a configuração no código via `terraform state show` e `terraform plan`.
- Executar alterações e o descomissionamento (`terraform destroy`) do recurso sob governança do Terraform.

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 1: Preparação do Ambiente e Identificação do Recurso Existente
1. Certifique-se de que suas credenciais temporárias da `AWS Academy` estão ativas no arquivo `~/.aws/credentials`.
2. Para simular um recurso legado/existente (*brownfield*), utilize uma instância EC2 já ativa na sua conta da AWS Academy (ou crie uma manualmente via Console AWS com o nome `"Instância Legada"`).
3. Inspecione o Console AWS e anote o **ID da Instância** (formato: `i-0123456789abcdef0`).

---

### Passo 2: Analisar a Estrutura no `main.tf`
Abra o arquivo `main.tf` na pasta `lab13-import/` e observe o bloco declarativo inicial:

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

resource "aws_instance" "example" {
  ami           = "ami-00ca32bbc84273381"
  instance_type = "t3.micro"

  tags = {
    Name = "Teste Import"
  }
}
```

*   O Terraform exige que o bloco de recurso (`resource "aws_instance" "example"`) já esteja declarado no arquivo `.tf` antes da execução do comando CLI de importação.

---

### Passo 3: Executar a Importação (`terraform import`)
No terminal do seu Codespaces, navegue para a pasta e execute a importação:

1. **Navegar para a pasta do Lab 13:**
   ```bash
   cd lab13-import
   ```
2. **Inicializar o Terraform:**
   ```bash
   terraform init
   ```
3. **Executar o Comando de Importação:**
   Substitua `i-0123456789abcdef0` pelo ID real da sua instância EC2 obtido no Passo 1:
   ```bash
   terraform import aws_instance.example i-0123456789abcdef0
   ```
   *Você verá a mensagem: `Import successful!` indicando que o recurso remoto foi mapeado para o arquivo `terraform.tfstate`.*

---

### Passo 4: Sincronização e Correção de Drift
Após a importação, o arquivo de estado contém todos os detalhes da instância real, mas o código HCL no `main.tf` pode ter divergências (*drift*).

1. **Inspecionar o Estado Importado:**
   ```bash
   terraform state show aws_instance.example
   ```
2. **Verificar Diferenças com o Planejamento:**
   ```bash
   terraform plan
   ```
   *Se o Terraform indicar intenção de substituir ou alterar atributos (como `ami` ou `instance_type`), edite o `main.tf` ajustando os valores para coincidirem exatamente com a instância real, até que o `terraform plan` retorne:*
   `No changes. Your infrastructure matches the configuration.`

---

## 🔍 Pontos de Validação Prática

1. **Testar Governança Pós-Importação:**
   Altere a tag `Name` no arquivo `main.tf`:
   ```hcl
     tags = {
       Name = "Instancia Importada e Gerenciada"
     }
   ```
2. **Aplicar a Alteração:**
   ```bash
   terraform apply
   ```
   *Digite **`yes`** e verifique no Console AWS que o nome da instância foi atualizado com sucesso via Terraform.*

---

## 🧹 Limpeza do Ambiente
Como a instância agora está sob controle do Terraform, você pode desprovisioná-la normalmente:
```bash
terraform destroy
```
*Digite **`yes`** para confirmar a destruição da instância.*
