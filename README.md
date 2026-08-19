# ToggleMaster - Fase 2 (Microsserviços)

## Sobre o projeto

O ToggleMaster é um sistema de **feature flags**, um "interruptor" que controla se uma funcionalidade de
um aplicativo está ligada ou desligada, sem precisar publicar uma versão
nova do app toda vez que se quer testar ou desligar algo.

Este projeto foi desenvolvido para o **Tech Challenge Fase 2** da
POSTECH, evoluindo o ToggleMaster (que na Fase 1 era um monólito) para
uma arquitetura de **5 microsserviços independentes**, conteinerizados
com Docker e orquestrados via **Kubernetes na AWS (EKS)**.


## Arquitetura dos microsserviços

| Serviço | Linguagem | O que faz | Onde guarda dados |
|---|---|---|---|
| **auth-service** | Go | Gera e valida as chaves de API que autenticam as requisições ao sistema | PostgreSQL |
| **flag-service** | Python | CRUD das definições das feature flags (criar, listar, ativar/desativar) | PostgreSQL |
| **targeting-service** | Python | Gerencia as regras de segmentação (para quais usuários uma flag está ativa) | PostgreSQL |
| **evaluation-service** | Go | O "caminho quente" (hot path) — recebe a pergunta "essa flag deve aparecer para este usuário?" e responde em tempo real, com alta performance | Redis (cache) |
| **analytics-service** | Python | Consome os eventos de avaliação de uma fila e salva um histórico para análise | SQS + DynamoDB |

### Fluxo resumido de uma requisição

Um sistema externo (com uma chave de API válida) pergunta ao
`evaluation-service` se uma flag deve aparecer para um usuário. O
`auth-service` valida a chave. O `evaluation-service` consulta o Redis
(cache) — se não tiver a configuração da flag em cache, busca no
`flag-service` e no `targeting-service`, guarda em cache, e calcula o
resultado (`true`/`false`) para aquele usuário. Ao mesmo tempo, envia um
evento para a fila SQS, que o `analytics-service` processa e salva no
DynamoDB, formando um histórico de todas as avaliações realizadas.

## Rodando localmente

O ambiente local usa Docker Compose para subir os 5 microsserviços mais
4 bancos de dados locais (2 instâncias PostgreSQL, Redis, e DynamoDB
Local) — 9 containers no total.

**Pré-requisito:** crie um arquivo `.env` na raiz do projeto com:
POSTGRES_PASSWORD=sua_senha_aqui


Cada microsserviço também tem seu próprio arquivo `.env` interno (não
incluído neste repositório por segurança) — consulte o `README.md` de
cada serviço para as variáveis necessárias.

**Subir o ambiente:**
```bash
docker compose up -d
```

**Conferir que os 9 containers estão rodando:**
```bash
docker compose ps
```

## Infraestrutura na nuvem (AWS)

A implantação em nuvem usa a **Opção B** do desafio (conta AWS pessoal),
com os seguintes recursos:

- **EKS**: cluster Kubernetes gerenciado, criado via `eksctl`
- **ECR**: armazena as imagens Docker dos 5 microsserviços
- **RDS**: 3 instâncias PostgreSQL independentes (uma para cada serviço
  que precisa de banco relacional)
- **ElastiCache (Redis)**: cache do `evaluation-service`
- **DynamoDB**: armazena os eventos de análise
- **SQS**: fila de mensagens entre `evaluation-service` e
  `analytics-service`
- **Nginx Ingress Controller**: expõe os serviços externamente via Load
  Balancer, roteando `/auth`, `/flags`, `/rules` e `/evaluate` para os
  respectivos serviços
- **HorizontalPodAutoscaler (HPA)**: escala automaticamente o
  `evaluation-service` e o `analytics-service` com base no uso de CPU

Todos os manifestos Kubernetes estão na pasta [`k8s/`](./k8s).

## Estrutura do repositório

.
├── auth-service/ # Código-fonte + Dockerfile
├── flag-service/ # Código-fonte + Dockerfile
├── targeting-service/ # Código-fonte + Dockerfile
├── evaluation-service/ # Código-fonte + Dockerfile
├── analytics-service/ # Código-fonte + Dockerfile
├── k8s/ # Manifestos Kubernetes (Deployments, Services, Ingress, HPA, etc.)
├── docker-compose.yml # Sobe o ambiente local completo
└── .gitignore


## Código-fonte original

Código-fonte base dos 5 microsserviços fornecido pelo desafio,
disponível em: https://github.com/FIAP-TCs

