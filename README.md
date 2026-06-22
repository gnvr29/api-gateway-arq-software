# API Gateway — Arquitetura de Software

API Gateway baseado em Nginx que roteia tráfego para os microserviços de **Alunos** e **Cursos**, com rate limiting, security headers, load balancing e stack de observabilidade (Loki + Promtail + Grafana).

---

## Arquitetura

<div align="center">
  <img width="728" height="1079" alt="Diagrama de Arquitetura" src="https://github.com/user-attachments/assets/7199c254-ee85-45a8-961c-4c6a91a0f8f3" />
  <br/>
  <br/>
</div>

> O sistema utiliza um **API Gateway (Nginx)** como único ponto de entrada, responsável por rate limiting, load balancing e segurança. As requisições são roteadas para dois microsserviços independentes em **Go** (Alunos e Cursos), cada um com seu próprio banco de dados isolado no **PostgreSQL**. Em paralelo, os logs gerados pelo Gateway são coletados pelo **Promtail**, armazenados no **Loki** e visualizados em tempo real pelo **Grafana**.

## Estrutura de Pastas

```
infra/
├── docker-compose.yml              # Orquestra todos os containers
├── nginx/
│   ├── nginx.conf                  # Config principal (workers, log format JSON, rate limits)
│   ├── conf.d/
│   │   ├── upstream.conf           # Definição dos backends (load balancing)
│   │   └── gateway.conf            # Server block, rotas
│   └── snippets/
│       ├── proxy-headers.conf      # Headers padrão de proxy (X-Real-IP, X-Forwarded-For)
│       ├── security-headers.conf   # X-Frame-Options, X-Content-Type-Options
│       └── cors.conf               # CORS (incluir em locations que precisem)
├── postgres/
│   └── init/
│       └── 01-init.sql             # Cria users e databases na primeira execução
├── promtail/
│   └── promtail-config.yml         # Scrape dos logs do Nginx → Loki
├── loki/
│   └── loki-config.yml             # Storage engine de logs
└── grafana/
    └── provisioning/
        ├── dashboards/
        │   ├── dashboards.yml      # Provider config para auto-load
        │   └── nginx-dashboard.json # Dashboard pré-configurado
        └── datasources/
            └── loki.yml            # Auto-provisiona Loki como datasource

services/
├── alunos/                         # Serviço de alunos (Go, porta 8081)
└── cursos/                         # Serviço de cursos (Go, porta 8080)

bruno-collection/                   # Coleção Bruno para testar a API
├── gateway/                        # Health check e rota inexistente (via gateway)
├── alunos/                         # CRUD de alunos via gateway (/api/alunos)
├── alunos-direto/                  # CRUD de alunos direto no serviço (porta 8081, sem gateway)
├── cursos/                         # CRUD de cursos via gateway (/api/cursos)
├── cursos-direto/                  # CRUD de cursos direto no serviço (porta 8082, sem gateway)
└── environments/
    └── Local.bru                   # baseUrl (gateway) e *DirectUrl (serviços) locais

scripts/                            # Scripts de demo do comportamento do gateway
├── rate-limiting.sh                # Rajada de requisições para mostrar o 429
├── servico-indisponivel.sh         # Para um backend e mostra o erro retornado
└── tempo-resposta.sh               # Mede latência total vs upstream
```

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e [Docker Compose](https://docs.docker.com/compose/install/) instalados
- Portas disponíveis: `8000`, `3000`, `3100`, `5432`, `8081`, `8082`

---

## Como Rodar

### 1. Subir a stack

```bash
cd infra
docker compose up -d --build
```

O `--build` garante que os serviços Go sejam compilados a partir do Dockerfile.

### 2. Verificar que tudo está rodando

```bash
docker compose ps
```

Todos os containers devem estar `healthy` ou `running`.

### 3. Testar o gateway

```bash
# Health check do gateway
curl http://localhost:8000/health

# Listar alunos (via gateway)
curl http://localhost:8000/api/alunos

# Criar um aluno
curl -X POST http://localhost:8000/api/alunos \
  -H "Content-Type: application/json" \
  -d '{"nome": "Gabriel", "email": "gabriel@test.com", "matricula": "2024001"}'

# Buscar aluno por ID (substituir pelo UUID retornado no POST)
curl http://localhost:8000/api/alunos/00000000-0000-0000-0000-000000000001

# Listar cursos
curl http://localhost:8000/api/cursos

# Criar um curso
curl -X POST http://localhost:8000/api/cursos \
  -H "Content-Type: application/json" \
  -d '{"nome": "Arquitetura de Software", "descricao": "Patterns e práticas"}'

# Buscar curso por ID (substituir pelo UUID retornado no POST)
curl http://localhost:8000/api/cursos/00000000-0000-0000-0000-000000000001
```

---

## Acessar Serviços

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| API Gateway | http://localhost:8000 | — |
| Alunos Service (direto, sem gateway) | http://localhost:8081 | — |
| Cursos Service (direto, sem gateway) | http://localhost:8082 | — |
| Grafana | http://localhost:3000 | admin / admin |
| Loki API | http://localhost:3100 | — |
| PostgreSQL | localhost:5432 | postgres / postgres |

---

## Rotas do API Gateway

| Método | Rota | Serviço destino |
|--------|------|-----------------|
| GET | `/health` | Gateway (responde direto) |
| GET | `/api/alunos` | alunos-service → `GET /alunos` |
| GET | `/api/alunos/{id}` | alunos-service → `GET /alunos/{id}` |
| POST | `/api/alunos` | alunos-service → `POST /alunos` |
| GET | `/api/cursos` | cursos-service → `GET /cursos` |
| GET | `/api/cursos/{id}` | cursos-service → `GET /cursos/{id}` |
| POST | `/api/cursos` | cursos-service → `POST /cursos` |

---

## Testando com Bruno

Em vez de `curl`, é possível usar a coleção [Bruno](https://www.usebruno.com/) em `bruno-collection/`:

1. Abrir o Bruno e fazer "Open Collection" apontando para a pasta `bruno-collection/`
2. Selecionar o ambiente **Local** (já provisionado com as URLs abaixo)
3. Rodar as requests organizadas por pasta:
   - `gateway/` — health check e rota inexistente
   - `alunos/` e `cursos/` — CRUD via gateway (`http://localhost:8000/api/...`)
   - `alunos-direto/` e `cursos-direto/` — mesmo CRUD batendo direto no serviço (`http://localhost:8081` / `http://localhost:8082`), útil para comparar latência e comportamento com/sem gateway

---

## Funcionalidades do Gateway

### Rate Limiting
- **Zone `general`**: 30 req/s por IP (burst de 20), aplicada a todos os endpoints
- **Zone `auth`**: 5 req/s por IP (burst de 10), disponível para endpoints de autenticação

Quando o limite é excedido, o client recebe `429 Too Many Requests`.

### Load Balancing
- Algoritmo: `least_conn` (envia para o backend com menos conexões ativas)
- Health check: se um backend falhar 3 vezes em 30s, é removido do pool temporariamente
- Pronto para scaling horizontal: basta adicionar mais `server` entries em `upstream.conf`

### Security Headers
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `server_tokens off` (não expõe versão do Nginx)

### Structured Logging (JSON)
Cada request gera um log JSON com:
```json
{
  "time": "2024-01-15T10:30:00+00:00",
  "remote_addr": "172.20.0.1",
  "request_method": "GET",
  "request_uri": "/api/alunos",
  "status": 200,
  "body_bytes_sent": 245,
  "request_time": 0.012,
  "upstream_response_time": "0.010",
  "upstream_addr": "172.20.0.3:8081",
  "request_id": "abc123..."
}
```

---

## Observabilidade (Grafana + Loki)

### Pipeline
1. Nginx escreve logs em JSON para `/var/log/nginx/access.log`
2. Promtail lê os logs e extrai labels (`status`, `method`)
3. Promtail envia para Loki
4. Grafana consulta Loki via LogQL

### Acessar logs no Grafana
1. Abrir http://localhost:3000 (admin/admin)
2. O dashboard **"API Gateway — NGINX"** já está provisionado automaticamente
3. Ir em **Dashboards** → clicar em "API Gateway — NGINX"
4. O dashboard mostra:
   - Total de requisições, erros, rate limits e 502s
   - Requisições por status code ao longo do tempo
   - Requisições por rota e método HTTP
   - Tempo de resposta do gateway vs upstream (latência)
   - Logs em tempo real (access + error)

Para queries manuais, ir em **Explore** → selecionar datasource **Loki**:
   ```logql
   {job="nginx"} | json
   {job="nginx"} | json | status >= 400
   {job="nginx"} | json | request_uri =~ "/api/alunos.*"
   {job="nginx"} | json | status = 429
   ```

---

## Banco de Dados

O PostgreSQL é compartilhado mas com **isolamento lógico**:

| Serviço | User | Database | Porta interna |
|---------|------|----------|---------------|
| alunos | `alunos` | `alunos_db` | 5432 |
| cursos | `cursos` | `cursos_db` | 5432 |

As migrations rodam automaticamente quando cada serviço inicia.

### Conectar manualmente (debug)

```bash
# Via docker
docker exec -it postgres psql -U alunos -d alunos_db

# Via psql local
psql -h localhost -U alunos -d alunos_db
```

---

## Scripts de Demonstração

A pasta `scripts/` contém shell scripts que demonstram, na prática, funcionalidades do gateway (rodar com a stack já no ar):

```bash
# Rajada de requisições para mostrar rate limiting (429)
./scripts/rate-limiting.sh

# Para um backend e mostra como o gateway responde (502/erro tratado)
./scripts/servico-indisponivel.sh

# Mede latência total (gateway) vs tempo de upstream
./scripts/tempo-resposta.sh
```

---

## Comandos Úteis

```bash
# Subir tudo
docker compose up -d --build

# Ver logs de um serviço
docker compose logs -f nginx
docker compose logs -f alunos-service

# Rebuild de um serviço específico
docker compose up -d --build alunos-service

# Parar tudo
docker compose down

# Parar e limpar volumes (reset total, perde dados)
docker compose down -v

# Testar config do Nginx sem reiniciar
docker exec api-gateway nginx -t

# Reload do Nginx (aplica mudanças de config sem downtime)
docker exec api-gateway nginx -s reload
```

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `502 Bad Gateway` | Backend ainda não subiu. Verificar `docker compose logs alunos-service` |
| `429 Too Many Requests` | Rate limit atingido. Aguardar ou ajustar em `nginx.conf` |
| Container postgres reiniciando | Volume já existe com dados antigos. `docker compose down -v` para reset |
| Migrations falhando | Verificar se o init script criou o database corretamente |

---

## Próximos Passos

- [ ] Adicionar autenticação (JWT validation via `auth_request`)
- [ ] Adicionar TLS para ambientes de produção (Let's Encrypt)
- [ ] Circuit breaker com timeouts mais agressivos por serviço
