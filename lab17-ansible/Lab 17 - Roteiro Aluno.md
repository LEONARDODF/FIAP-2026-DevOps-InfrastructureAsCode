# LAB 17: Automação Multi-Host com Ansible & Templates Jinja2

Neste laboratório prático, você aprenderá a implementar o modelo de **Automação Híbrida** amplamente utilizado em ambientes corporativos:
- **Terraform:** Provisiona a infraestrutura na nuvem (múltiplas instâncias EC2 e Security Group).
- **Ansible:** Assume a governança do sistema operacional, configurando simultaneamente todos os servidores em paralelo com templates dinâmicos (**Jinja2**) e garantindo **Idempotência**.

---

## 🎯 Objetivos de Aprendizado
- Compreender a divisão clara de responsabilidades entre Terraform (orquestrador de infraestrutura) e Ansible (gerenciador de configuração).
- Estruturar e gerenciar inventários estáticos de múltiplos hosts no Ansible.
- Utilizar **Ansible Facts** e **Templates Jinja2 (`.j2`)** para gerar configurações dinâmicas personalizadas por máquina.
- Compreender e testar na prática o conceito de **Idempotência** do Ansible.

---

## 🏃‍♂️ Guia Passo a Passo

### Passo 0: Instalação do Ansible no Codespaces (Se necessário)
Caso o comando `ansible` não esteja instalado no seu terminal do Codespaces, execute:
```bash
sudo apt update && sudo apt install -y ansible
```
*Verifique a instalação com `ansible --version`.*

---

### Passo 1: Provisionar a Infraestrutura com Terraform

1. No terminal do seu Codespaces, navegue até a pasta do Terraform:
   ```bash
   cd lab17-ansible/terraform
   ```
2. Inicialize o Terraform:
   ```bash
   terraform init
   ```
3. Aplique o provisionamento para criar os 2 servidores na AWS:
   ```bash
   terraform apply
   ```
   *Digite **`yes`** e pressione `Enter`.*

4. Ao concluir, o Terraform exibirá no output os IPs públicos das instâncias criadas:
   ```hcl
   Outputs:
   public_ips = [
     "54.210.xx.xx",
     "3.85.yy.yy",
   ]
   ```
   *Mantenha esses IPs visíveis para o próximo passo.*

---

### Passo 2: Configurar a Chave SSH e o Inventário do Ansible

1. Navegue para a pasta do Ansible:
   ```bash
   cd ../ansible
   ```
2. **Copiar a Chave SSH:** Garanta que o arquivo da sua chave privada da AWS Academy (`labsuser.pem`) esteja presente nesta pasta `ansible/`.
3. Ajuste as permissões de segurança da chave SSH (obrigatório para conexões SSH):
   ```bash
   chmod 400 labsuser.pem
   ```
4. Abra o arquivo `inventory.ini` e substitua os placeholders pelos IPs públicos reais gerados pelo Terraform:
   ```ini
   [webservers]
   servidor-01 ansible_host=54.210.xx.xx
   servidor-02 ansible_host=3.85.yy.yy

   [webservers:vars]
   ansible_user=ubuntu
   ansible_ssh_private_key_file=./labsuser.pem
   ansible_ssh_common_args='-o StrictHostKeyChecking=no'
   ```

---

### Passo 3: Testar a Conectividade via Ansible (Ping)

Antes de rodar o playbook completo, teste a comunicação com todas as máquinas em paralelo utilizando o módulo `ping` do Ansible:

```bash
ansible webservers -i inventory.ini -m ping
```

*Se a saída retornar `"ping": "pong"` em verde para ambos os servidores, a conectividade SSH está perfeita!*

---

### Passo 4: Analisar o Playbook e o Template Jinja2

1. Inspecione o arquivo `playbook.yml`:
   - Ele coleta os dados das máquinas (`gather_facts: true`).
   - Atualiza o repositório `apt` e instala o `nginx`.
   - Copia e renderiza o template `templates/index.html.j2` para o diretório `/var/www/html/index.html`.
2. Inspecione o template `templates/index.html.j2`:
   - Note as variáveis como `{{ inventory_hostname }}`, `{{ ansible_hostname }}`, `{{ ansible_default_ipv4.address }}` e `{{ ansible_memtotal_mb }}`.
   - O Ansible substituirá automaticamente essas tags pelos valores reais de cada servidor individualmente!

---

### Passo 5: Executar o Playbook de Configuração

Execute o playbook nos dois servidores em paralelo:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

Observe o relatório final da execução:
```text
PLAY RECAP *********************************************************************
servidor-01                : ok=5    changed=4    unreachable=0    failed=0
servidor-02                : ok=5    changed=4    unreachable=0    failed=0
```
*Note que as tarefas foram executadas com sucesso (`changed=4`), configurando ambos os nós simultaneamente.*

---

### Passo 6: O Teste de Ouro — Idempotência na Prática

Execute **exatamente o mesmo comando** do playbook novamente sem alterar nada:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

Observe o resultado no terminal:
```text
PLAY RECAP *********************************************************************
servidor-01                : ok=5    changed=0    unreachable=0    failed=0
servidor-02                : ok=5    changed=0    unreachable=0    failed=0
```

> [!NOTE]
> **Por que `changed=0`?** 
> Diferente de um script Shell que executaria tudo do zero novamente (reinstalando pacotes e reiniciando serviços à toa), o Ansible verifica o estado atual do sistema operacional e percebe que tudo já está conforme o desejado. Isso é **Idempotência**.

---

## 🔍 Pontos de Validação Prática

1. Abra o seu navegador e acesse as URLs de cada servidor:
   - `http://<IP_DO_SERVIDOR_01>`
   - `http://<IP_DO_SERVIDOR_02>`
2. **Observe a diferença nas páginas:**
   - Cada página exibirá seu próprio **Hostname**, seu próprio **IP Privado** e suas métricas reais de hardware, provando que o template Jinja2 renderizou os dados específicos de cada nó.

---

## 🧹 Limpeza do Ambiente

Para destruir os servidores e o Security Group da AWS:

1. Volte para a pasta do Terraform:
   ```bash
   cd ../terraform
   ```
2. Execute a destruição:
   ```bash
   terraform destroy
   ```
   *Digite **`yes`** para confirmar.*
