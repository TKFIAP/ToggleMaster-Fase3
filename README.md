# ToggleMaster - Fase 3 (Infraestrutura como Código, CI/CD e GitOps)

## Sobre o projeto

O ToggleMaster é um sistema de **feature flags**, um "interruptor" que controla se uma funcionalidade de um aplicativo está ligada ou desligada, sem precisar publicar uma versão nova do app toda vez que se quer testar ou desligar algo.

Este projeto foi desenvolvido para o **Tech Challenge Fase 3** da POSTECH. Ele parte da arquitetura de **5 microsserviços** da Fase 2, conteinerizados com Docker e orquestrados via **Kubernetes na AWS (EKS)**, e automatiza todo o caminho até a nuvem, seguindo a regra *"se não está no código, não existe"*:

- **Infraestrutura como Código** com Terraform
- **Pipeline de CI/CD com DevSecOps** no GitHub Actions
- **Deploy por GitOps** com ArgoCD

## Arquitetura dos microsserviços

| Serviço | Linguagem | O que faz | Onde guarda dados |
|---|---|---|---|
| **auth-service** | `Go` | Gera e valida as chaves de API que autenticam as requisições ao sistema | PostgreSQL |
| **flag-service** | `Python` | CRUD das definições das feature flags (criar, listar, ativar/desativar) | PostgreSQL |
| **targeting-service** | `Python` | Gerencia as regras de segmentação (para quais usuários uma flag está ativa) | PostgreSQL |
| **evaluation-service** | `Go` | O "caminho quente" (hot path): recebe a pergunta "essa flag deve aparecer para este usuário?" e responde em tempo real, com alta performance | Redis (cache) |
| **analytics-service** | `Python` | Consome os eventos de avaliação de uma fila e salva um histórico para análise | SQS + DynamoDB |

### Fluxo resumido de uma requisição

Um sistema externo (com uma chave de API válida) pergunta ao `evaluation-service` se uma flag deve aparecer para um usuário. O `auth-service` valida a chave. O `evaluation-service` consulta o Redis (cache); se não tiver a configuração da flag em cache, busca no `flag-service` e no `targeting-service`, guarda em cache e calcula o resultado (`true`/`false`) para aquele usuário. Ao mesmo tempo, envia um evento para a fila SQS, que o `analytics-service` processa e salva no DynamoDB, formando um histórico de todas as avaliações realizadas.

## Rodando localmente

O ambiente local usa Docker Compose para subir os 5 microsserviços mais 5 bancos de dados/serviços locais (3 instâncias PostgreSQL, Redis e DynamoDB Local): 10 containers no total.

> **Nota:** mantemos 3 instâncias PostgreSQL separadas, uma por serviço, para manter consistência com a arquitetura da nuvem, onde cada serviço também tem seu próprio banco RDS independente.

**Pré-requisito:** crie um arquivo `.env` na raiz do projeto com `POSTGRES_PASSWORD=sua_senha_aqui`. Cada microsserviço também tem seu próprio arquivo `.env` interno (não incluído neste repositório por segurança).

**Subir o ambiente:**
```bash
docker compose up -d
```

**Conferir que os 10 containers estão rodando:**
```bash
docker compose ps
```

## Infraestrutura na nuvem (AWS)

A implantação em nuvem usa a **Opção A** do desafio (AWS Academy). Toda a infraestrutura é criada por **Terraform** (pasta [`terraform/`](./terraform)), organizado em módulos:

- **networking** — VPC, sub-redes públicas e privadas, Internet Gateway e tabela de rotas
- **eks** — cluster Kubernetes gerenciado e node group
- **databases** — 3 instâncias RDS PostgreSQL (uma por serviço), ElastiCache (Redis) e a tabela DynamoDB `ToggleMasterAnalytics`
- **messaging** — fila SQS entre o `evaluation-service` e o `analytics-service`
- **ecr** — 5 repositórios para as imagens Docker
- **addons** — instala no cluster, via Helm: **Nginx Ingress Controller** (Load Balancer que roteia `/auth`, `/flags`, `/rules` e `/evaluate`), **metrics-server** (usado pelo HPA) e **ArgoCD**

O estado do Terraform fica em um **bucket S3** (backend remoto, com `use_lockfile`). Como o AWS Academy não permite criar permissões de IAM, o Terraform usa uma role já existente (padrão: `LabRole`).

O **HorizontalPodAutoscaler (HPA)** escala automaticamente o `evaluation-service` e o `analytics-service` com base no uso de CPU.

## Pipeline de CI/CD (DevSecOps)

Cada microsserviço tem seu workflow em [`.github/workflows/`](./.github/workflows), que roda a cada push e Pull Request na `main`:

1. **Build e testes** — compila o código e roda os testes unitários
2. **Lint** — golangci-lint (Go) e flake8 (Python)
3. **Segurança** — SCA com Trivy nas dependências e SAST com gosec (Go) e bandit (Python); uma vulnerabilidade **crítica** faz o pipeline falhar
4. **Imagem Docker** — build, scan da imagem com Trivy e envio ao **ECR** com a tag `v1.0.0-<commit>`
5. **Atualizar o GitOps** — troca a tag da imagem no manifesto da pasta `gitops/`

O envio ao ECR e a atualização do GitOps só acontecem com a variável do repositório `DEPLOY_ENABLED = true`.

## Entrega contínua (GitOps com ArgoCD)

Os manifestos Kubernetes ficam na pasta [`gitops/`](./gitops) (Deployments, Services, ConfigMap, Ingress e HPA). O arquivo [`argocd/application.yaml`](./argocd/application.yaml) diz ao ArgoCD para vigiar essa pasta e sincronizar o cluster automaticamente.

Fluxo de uma mudança: **commit no código → pipeline aprova e publica a imagem → pipeline atualiza a tag em `gitops/` → ArgoCD sincroniza o cluster**. Ninguém roda `kubectl apply` manualmente.

## Como subir o ambiente

Os nomes entre `< >` são de escolha de quem sobe o ambiente.

1. Criar `terraform/terraform.tfvars` com `db_password = "<SENHA>"` (opcionais: `aws_profile` e `iam_role_name`).
2. Criar o bucket S3 que guarda o estado do Terraform e criar a infraestrutura:
   ```bash
   aws s3 mb s3://<NOME_DO_BUCKET> --region us-east-1 --profile <SEU_PERFIL>
   cd terraform
   terraform init -backend-config="bucket=<NOME_DO_BUCKET>" -backend-config="key=fase3/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="profile=<SEU_PERFIL>" -backend-config="use_lockfile=true"
   terraform apply
   ```
3. Trocar o marcador `CONTA_AWS` pelo ID da conta nos arquivos de `gitops/`, criar o Secret `togglemaster-secrets` (modelo em `gitops/secrets.yaml.example`) e as tabelas (`db/init.sql` de cada serviço).
4. No GitHub, cadastrar os secrets de acesso à AWS, ligar `DEPLOY_ENABLED = true` e rodar os 5 pipelines.
5. Para apagar tudo: `terraform destroy`.

## Desafios e decisões

- **Custo:** o AWS Academy oferece um crédito limitado. Usamos máquinas pequenas, não usamos NAT Gateway (os bancos e o Redis ficam em sub-redes privadas, sem acesso pela internet) e rodamos `terraform destroy` ao fim de cada sessão. Como tudo está em código, recriar o ambiente leva poucos comandos.
- **O Load Balancer e o `terraform destroy`:** a porta de entrada da aplicação (ingress-nginx) cria um Load Balancer na AWS, mas quem cria é o Kubernetes, e não o Terraform. Na primeira versão do projeto, o ingress-nginx era instalado à mão, e percebemos que o Terraform não saberia que esse Load Balancer existe: no `destroy`, a rede não poderia ser apagada enquanto ele existisse, e ele continuaria gerando custo. A solução foi o módulo `addons`: o próprio Terraform instala o ingress-nginx, o metrics-server e o ArgoCD com o Helm, e no `destroy` remove tudo na ordem certa, esperando o Load Balancer sumir antes de apagar o cluster e a rede.

## Estrutura do repositório

- `auth-service/` — Código-fonte + Dockerfile
- `flag-service/` — Código-fonte + Dockerfile
- `targeting-service/` — Código-fonte + Dockerfile
- `evaluation-service/` — Código-fonte + Dockerfile
- `analytics-service/` — Código-fonte + Dockerfile
- `terraform/` — Infraestrutura como código (módulos em `terraform/modules/`)
- `.github/workflows/` — Pipelines de CI/CD, um por serviço
- `gitops/` — Manifestos Kubernetes vigiados pelo ArgoCD
- `argocd/` — Configuração da Application do ArgoCD
- `docker-compose.yml` — Sobe o ambiente local completo

## Código-fonte original

Código-fonte base dos 5 microsserviços fornecido pelo desafio, disponível em: https://github.com/FIAP-TCs
