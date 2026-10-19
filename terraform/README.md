# ToggleMaster - Fase 3 (Infraestrutura como Código, CI/CD e GitOps)

## Sobre o projeto

O ToggleMaster é um sistema de **feature flags**, um "interruptor" que controla se uma funcionalidade de um aplicativo está ligada ou desligada, sem precisar publicar uma versão nova do app toda vez que se quer testar ou desligar algo.

Este projeto foi desenvolvido para o **Tech Challenge Fase 3** da POSTECH. Ele parte da arquitetura de **5 microsserviços** construída na Fase 2 e automatiza todo o caminho até a nuvem:

- **Infraestrutura como Código (Terraform):** toda a infraestrutura da AWS é descrita em código e criada com um comando, em vez de configurada manualmente no console.
- **CI/CD com DevSecOps (GitHub Actions):** a cada alteração no código, um pipeline testa, verifica a segurança, constrói as imagens e as publica no ECR automaticamente.
- **GitOps (ArgoCD):** os manifestos Kubernetes ficam em um repositório Git próprio, e o ArgoCD mantém o cluster sempre igual ao que está nesse repositório.

## Arquitetura dos microsserviços

| Serviço | Linguagem | O que faz | Onde guarda dados |
|---|---|---|---|
| **auth-service** | `Go` | Gera e valida as chaves de API que autenticam as requisições ao sistema | PostgreSQL |
| **flag-service** | `Python` | CRUD das definições das feature flags (criar, listar, ativar/desativar) | PostgreSQL |
| **targeting-service** | `Python` | Gerencia as regras de segmentação (para quais usuários uma flag está ativa) | PostgreSQL |
| **evaluation-service** | `Go` | O "caminho quente" (hot path): recebe a pergunta "essa flag deve aparecer para este usuário?" e responde em tempo real, com alta performance | Redis (cache) |
| **analytics-service** | `Python` | Consome os eventos de avaliação de uma fila e salva um histórico para análise | SQS + DynamoDB |

### Fluxo resumido de uma requisição

Um sistema externo (com uma chave de API válida) pergunta ao `evaluation-service` se uma flag deve aparecer para um usuário. O `evaluation-service` consulta o Redis (cache); se não tiver a configuração da flag em cache, busca no `flag-service` e no `targeting-service` (que validam a chave no `auth-service`), guarda em cache e calcula o resultado (`true`/`false`) para aquele usuário. Ao mesmo tempo, envia um evento para a fila SQS, que o `analytics-service` processa e salva no DynamoDB, formando um histórico de todas as avaliações realizadas.

## Rodando localmente

O ambiente local usa Docker Compose para subir os 5 microsserviços mais 5 bancos de dados/serviços locais (3 instâncias PostgreSQL, Redis e DynamoDB Local): 10 containers no total.

> **Nota:** mantemos 3 instâncias PostgreSQL separadas (uma por serviço) para manter consistência com a arquitetura da nuvem, onde cada serviço tem seu próprio banco RDS independente.

**Pré-requisitos:**

1. Crie um arquivo `.env` na raiz do projeto com:

   ```
   POSTGRES_PASSWORD=sua_senha_aqui
   ```

2. Cada microsserviço também precisa do seu próprio arquivo `.env` (não incluído neste repositório por segurança). Consulte o `README.md` de cada serviço para as variáveis necessárias.

**Subir o ambiente:**

```bash
docker compose up -d
```

**Conferir que os 10 containers estão rodando:**

```bash
docker compose ps
```

Na primeira execução, os bancos PostgreSQL são criados automaticamente e as tabelas são geradas pelos scripts `db/init.sql` de cada serviço.

## Estrutura do repositório

- `auth-service/`: código-fonte + Dockerfile
- `flag-service/`: código-fonte + Dockerfile
- `targeting-service/`: código-fonte + Dockerfile
- `evaluation-service/`: código-fonte + Dockerfile
- `analytics-service/`: código-fonte + Dockerfile
- `k8s/`: manifestos Kubernetes da Fase 2 (serão migrados para o repositório de GitOps)
- `docker-compose.yml`: sobe o ambiente local completo

## Código-fonte original

Código-fonte base dos 5 microsserviços fornecido pelo desafio, disponível em: https://github.com/FIAP-TCs
