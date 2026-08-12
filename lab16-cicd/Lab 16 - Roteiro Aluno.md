# LAB 16: Pipeline de CI/CD para IaC com GitHub Actions & AWS

Neste laboratório prático, você implementará uma esteira de **CI/CD (Integração e Entrega Contínuas)** corporativa para Infrastructure as Code utilizando o **GitHub Actions** conectado à sua conta da **AWS** (AWS Academy). 

Você aprenderá a construir um fluxo **GitOps** com duas etapas fundamentais:
1. **Quality & Security Gate (CI):** Validação de formatação (`fmt`), sintaxe (`validate`) e análise estática de segurança.
2. **Automated Deploy (CD):** Injeção segura de credenciais temporárias, planejamento de infraestrutura (`plan`) e aplicação automática (`apply`) na AWS a partir de eventos do Git.

---

## 🎯 Objetivos de Aprendizado
- Criar e gerenciar um **Fork** de repositório de infraestrutura com GitHub Actions ativo.
- Gerenciar credenciais de nuvem de forma segura e isolada utilizando **GitHub Actions Secrets**.
- Estruturar um pipeline em YAML com múltiplos *jobs* interdependentes (`needs`).
- Aplicar práticas de DevSecOps com análise estática de conformidade antes de qualquer deploy.
- Validar o ciclo de vida completo: *Push no Fork $\rightarrow$ CI/CD Runner $\rightarrow$ Recursos Provisionados na sua conta AWS*.

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 1: Criar o seu Fork do Repositório
Para que você tenha controle administrativo total sobre as esteiras e seus próprios segredos de nuvem, realize um Fork do repositório da disciplina para a sua conta pessoal do GitHub:

1. Acesse o repositório oficial da disciplina no GitHub.
2. No canto superior direito da página, clique no botão **Fork**.
3. Em **Owner**, selecione a sua conta pessoal do GitHub.
4. Mantenha o nome sugerido e clique no botão verde **Create fork**.
5. Agora você está trabalhando no seu próprio repositório (`https://github.com/<seu-usuario>/<nome-repo>`).

---

### Passo 2: Habilitar o GitHub Actions no seu Fork
> [!IMPORTANT]
> **Aviso de Segurança do GitHub:** Por padrão, todo repositório criado via Fork inicia com as Actions desativadas para prevenir abusos. É obrigatório ativá-las manualmente.

1. No seu fork, clique na aba **Actions** (no menu superior).
2. Clique no botão verde: **"I understand my workflows, go ahead and enable them"**.
3. O GitHub Actions agora está autorizado a executar pipelines no seu fork.

---

### Passo 3: Configurar as Credenciais no seu Fork (Secrets)
Para que o runner do GitHub Actions possa autenticar chamadas de API na sua conta da AWS, cadastre as credenciais temporárias da **AWS Academy** como segredos do seu repositório:

1. No Console da **AWS Academy**, clique em **AWS Details** e depois em **Show** ao lado de *AWS CLI*.
2. Copie os valores correspondentes de:
   - `aws_access_key_id`
   - `aws_secret_access_key`
   - `aws_session_token`
3. No seu repositório (**seu Fork no GitHub**), acesse:
   - **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions** $\rightarrow$ **New repository secret**.
4. Crie os 4 segredos a seguir:

| Nome do Segredo | Valor |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | Cole o valor de `aws_access_key_id` da AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Cole o valor de `aws_secret_access_key` da AWS Academy |
| `AWS_SESSION_TOKEN` | Cole o valor de `aws_session_token` da AWS Academy |
| `AWS_REGION` | `us-east-1` |

> [!WARNING]
> **Atenção às Credenciais da AWS Academy:** As credenciais de laboratório expiram periodicamente (a cada 3–4 horas). Caso o pipeline falhe com erro `ExpiredToken` ou `AuthFailure`, basta atualizar os valores desses Secrets no seu fork.

---

### Passo 4: Clonar ou Abrir o seu Fork no Codespaces
Abra o seu fork para edição:
1. No seu fork no GitHub, clique no botão verde **Code** $\rightarrow$ aba **Codespaces** $\rightarrow$ **Create codespace on main** (ou clone localmente).
2. Navegue até a pasta do laboratório:
   ```bash
   cd lab16-cicd
   ```
3. Inspecione o arquivo `main.tf`:
   - Um **Security Group** (`aws_security_group.web_sg`) com portas 80 e 443 liberadas.
   - Uma instância **EC2** Ubuntu (`aws_instance.web_server`) com inicialização de servidor web Nginx via `user_data`.

---

### Passo 5: Estrutura da Esteira (`.github/workflows/terraform-pipeline.yml`)
> [!IMPORTANT]
> **Localização Obrigatória:** A pasta `.github/workflows/` **DEVE estar localizada na raiz do repositório Git**. O GitHub não reconhece workflows se eles estiverem dentro de subpastas (como `lab16-cicd/.github/`).
>
> Como o código do laboratório fica na pasta `lab16-cicd/`, o workflow utiliza a diretiva `defaults.run.working-directory: ./lab16-cicd` para executar os comandos do Terraform no diretório correto.

O arquivo de workflow fica localizado em `.github/workflows/terraform-pipeline.yml` (na raiz do repositório):

```yaml
name: "Terraform CI/CD Pipeline (Lab 16)"

on:
  push:
    branches:
      - main
    paths:
      - 'lab16-cicd/**'
      - '.github/workflows/terraform-pipeline.yml'
  pull_request:
    branches:
      - main
    paths:
      - 'lab16-cicd/**'
  workflow_dispatch:
    inputs:
      action:
        description: "Ação a executar na infraestrutura"
        required: true
        default: "apply"
        type: choice
        options:
          - apply
          - destroy

permissions:
  contents: read
  pull-requests: write

# Define o diretório de execução padrão para o Lab 16
defaults:
  run:
    working-directory: ./lab16-cicd

jobs:
  # ---------------------------------------------------------
  # Job 1: Quality Gate & DevSecOps (CI)
  # ---------------------------------------------------------
  quality_and_security:
    name: "1. Quality Gate & Lint"
    runs-on: ubuntu-latest

    steps:
      - name: "Clonar o Repositório"
        uses: actions/checkout@v4

      - name: "Instalar Terraform"
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.8.5"

      - name: "Verificar Formatação (fmt)"
        run: terraform fmt -check

      - name: "Inicializar sem Backend (Validação)"
        run: terraform init -backend=false

      - name: "Validar Sintaxe HCL"
        run: terraform validate

      - name: "Scanner de Segurança (Trivy / IaC)"
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: "config"
          scan-dir: "lab16-cicd"
          hide-progress: true
          format: "table"
          exit-code: "0"

  # ---------------------------------------------------------
  # Job 2: Plan, Apply ou Destroy na AWS (CD)
  # ---------------------------------------------------------
  deploy_aws:
    name: "2. Deploy / Destroy na AWS"
    needs: quality_and_security
    if: github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch')
    runs-on: ubuntu-latest

    steps:
      - name: "Clonar o Repositório"
        uses: actions/checkout@v4

      - name: "Configurar Credenciais da AWS"
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-session-token: ${{ secrets.AWS_SESSION_TOKEN }}
          aws-region: ${{ secrets.AWS_REGION || 'us-east-1' }}

      - name: "Sincronizar Estado Remoto (S3)"
        run: |
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          BUCKET_NAME="tfstate-lab16-${ACCOUNT_ID}"
          echo "BUCKET_NAME=${BUCKET_NAME}" >> $GITHUB_ENV
          
          # Cria o bucket S3 de persistencia de estado se nao existir
          aws s3 mb s3://${BUCKET_NAME} --region ${{ secrets.AWS_REGION || 'us-east-1' }} || true
          
          # Baixa o estado do Terraform se existir
          aws s3 cp s3://${BUCKET_NAME}/terraform.tfstate terraform.tfstate || echo "Primeira execucao: sem estado previo."

      - name: "Instalar Terraform"
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.8.5"

      - name: "Terraform Init"
        run: terraform init

      - name: "Executar Terraform Apply"
        if: ${{ github.event.inputs.action != 'destroy' }}
        run: |
          terraform plan -out=tfplan
          terraform apply -auto-approve tfplan

      - name: "Executar Terraform Destroy"
        if: ${{ github.event.inputs.action == 'destroy' }}
        run: terraform destroy -auto-approve

      - name: "Persistir Estado no S3"
        if: always()
        run: |
          if [ -f terraform.tfstate ]; then
            aws s3 cp terraform.tfstate s3://${BUCKET_NAME}/terraform.tfstate
          fi
```

---

### Passo 6: Disparar o Deploy e Acompanhar a Execução

1. Faça uma pequena alteração para testar o gatilho da esteira (por exemplo, personalize a mensagem HTML no bloco `user_data` do arquivo `lab16-cicd/main.tf`).
2. Realize o commit e push diretamente para a branch `main` do **seu fork**:
   ```bash
   git add .
   git commit -m "feat(ci): disparo do deploy automatizado via GitHub Actions"
   git push origin main
   ```
3. No GitHub, navegue até a aba **Actions** do seu fork.
4. Clique na execução do workflow `Terraform CI/CD Pipeline (Lab 16)` e acompanhe em tempo real:
   - **Quality Gate & Lint:** Valida a formatação e roda o scanner de segurança.
   - **Deploy / Destroy na AWS:** Sincroniza o estado no S3, conecta na sua AWS Academy, executa o `terraform plan` e finaliza o `terraform apply`.

---

## 🔍 Pontos de Validação Prática

1. **Inspecionar os Logs da Execução:**
   - Abra os detalhes do Job `2. Deploy / Destroy na AWS` no GitHub Actions e expanda a etapa `Executar Terraform Apply`.
   - Localize o valor do output `web_url` (ex: `http://54.x.x.x`).
2. **Testar a Aplicação Web no Navegador:**
   - Acesse o endereço IP público no navegador para ver a página servida pelo Nginx.
3. **Console da AWS:**
   - Acesse o Console da AWS no serviço **EC2** da sua conta da AWS Academy e confirme que a instância `Servidor-CI-CD-dev` foi criada com as tags gerenciadas pela esteira.

---

## 🧹 Limpeza do Ambiente (Desprovisionamento)

Para garantir que os recursos não continuem consumindo créditos da AWS Academy após a aula, você pode destruir a infraestrutura de duas formas:

### Método 1: Destruição Automatizada pelo GitHub Actions (Recomendado)
1. No seu fork no GitHub, acesse a aba **Actions**.
2. No menu lateral esquerdo, clique no workflow **Terraform CI/CD Pipeline (Lab 16)**.
3. Clique no botão **Run workflow** (no lado direito).
4. No campo **Ação a executar na infraestrutura**, selecione **`destroy`**.
5. Clique em **Run workflow**. O pipeline baixará o estado do S3 e executará o `terraform destroy -auto-approve` na AWS.

### Método 2: Destruição via Terminal (Codespaces)
Caso prefira rodar pelo terminal, sincronize o arquivo de estado e destrua:
```bash
cd lab16-cicd
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 cp s3://tfstate-lab16-${ACCOUNT_ID}/terraform.tfstate terraform.tfstate
terraform destroy
```
