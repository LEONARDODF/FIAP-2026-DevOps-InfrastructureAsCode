# LAB 18: Orquestração Zero-Touch (Terraform + Ansible Integrados)

Neste laboratório prático, você aprenderá a construir um fluxo de automação contínua **Zero-Touch (Sem Intervenção Manual)**, unificando o **HashiCorp Terraform** e o **Red Hat Ansible** em um único comando de execução.

Você verá como o Terraform pode:
1. Provisionar a infraestrutura de computação e rede na **AWS**.
2. Gerar dinamicamente o arquivo de inventário do Ansible (`inventory.ini`) contendo o IP público real.
3. Aguardar a liberação da porta SSH na máquina virtual.
4. Invocar automaticamente o **Ansible Playbook** via provisionador `local-exec`, entregando o servidor 100% configurado.

---

## 🎯 Objetivos de Aprendizado
- Integrar o ciclo de vida do Terraform com ferramentas de gerenciamento de configuração externa.
- Utilizar o provider `local` do Terraform (`local_file`) para gerar artefatos e arquivos de inventário sob demanda.
- Utilizar `null_resource`, `remote-exec` (para checagem de prontidão de rede) e `local-exec` (para orquestração de scripts).
- Executar um provisionamento de infraestrutura e aplicação ponta a ponta em um único comando (`terraform apply`).

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 0: Instalação do Ansible no Codespaces (Se necessário)
Caso o comando `ansible` não esteja instalado no seu terminal do Codespaces, execute:
```bash
sudo apt update && sudo apt install -y ansible
```
*Verifique a instalação com `ansible --version`.*

---

### Passo 1: Preparação da Chave SSH

1. No terminal do seu Codespaces, navegue até a pasta do laboratório:
   ```bash
   cd lab18-zero-touch
   ```
2. Garanta que a sua chave privada SSH da AWS Academy (`labsuser.pem`) esteja presente nesta pasta.
3. Ajuste as permissões de segurança da chave (obrigatório para que o SSH e o Ansible consigam utilizá-la):
   ```bash
   chmod 400 labsuser.pem
   ```

---

### Passo 2: Analisar a Mecânica no `main.tf`

Abra o arquivo `main.tf` e observe como os componentes conversam entre si:

1. **Geração Automática do Inventário (`local_file.ansible_inventory`):**
   ```hcl
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
   ```
   *O Terraform substitui `${aws_instance.web_server.public_ip}` no momento em que a máquina é criada e salva o `inventory.ini` pronto no disco.*

2. **Gatilho e Disparo Automático (`null_resource.trigger_ansible`):**
   - **`remote-exec`:** Conecta via SSH na máquina recém-criada para garantir que o sistema operacional finalizou o boot antes de chamar o Ansible.
   - **`local-exec`:** Dispara o comando `ansible-playbook -i inventory.ini playbook.yml` diretamente no seu terminal local.

---

### Passo 3: Executar o Provisionamento Zero-Touch

1. Inicialize o Terraform:
   ```bash
   terraform init
   ```
2. Execute o provisionamento:
   ```bash
   terraform apply
   ```
   *Digite **`yes`** e pressione `Enter`.*

3. **Acompanhe os logs no terminal:**
   - O Terraform criará o Security Group e a Instância EC2.
   - Criará o arquivo `inventory.ini` localmente.
   - Aguardará a resposta do SSH da instância.
   - O Ansible assumirá o terminal automaticamente, executando as tarefas do `playbook.yml` e aplicando o template Jinja2 no Nginx.
   - O Terraform finalizará exibindo a URL final no output:
     ```hcl
     Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

     Outputs:
     web_url = "http://54.x.x.x"
     ```

---

## 🔍 Pontos de Validação Prática

1. **Validar o Arquivo Gerado:**
   - Inspecione o arquivo `inventory.ini` gerado na pasta e confirme que o IP da sua instância AWS foi inserido automaticamente.
2. **Acessar a Aplicação Web:**
   - Abra o navegador e acesse a URL exibida no output `web_url` (ex: `http://54.x.x.x`).
   - Você verá a página web do **Pipeline Zero-Touch** exibindo o Hostname, IP privado e métricas do sistema operacional coletadas pelo Ansible.

---

## 🧹 Limpeza do Ambiente

Para desprovisionar todos os recursos da AWS de forma limpa:

```bash
terraform destroy
```
*Digite **`yes`** para confirmar a destruição da instância e do Security Group.*
