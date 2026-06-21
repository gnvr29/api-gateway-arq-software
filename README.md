# API Gateway — Arquitetura de Software

API Gateway baseado em Nginx que roteia tráfego para os microserviços de **Alunos** e **Cursos**, com rate limiting, security headers, load balancing e stack de observabilidade (Loki + Promtail + Grafana).

---

## Arquitetura

```
Client (HTTP :8000)
     │
     ▼
┌─────────────────┐
│  Nginx (80)     │ ← Rate limiting, routing, security headers
└──────┬──────────┘
       │
       ├──── /api/alunos ──→ alunos_service (upstream, least_conn)
       │
       └──── /api/cursos ──→ cursos_service (upstream, least_conn)
                                    │
                                    ▼
                            ┌──────────────┐
                            │  PostgreSQL   │
                            └──────────────┘
                            (alunos_db, cursos_db)
```

**Observabilidade:**
```
Nginx JSON logs → Promtail → Loki → Grafana (dashboard)
```

---

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
```

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e [Docker Compose](https://docs.docker.com/compose/install/) instalados
- Portas disponíveis: `8000`, `3000`, `3100`, `5432`

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
