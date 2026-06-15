# Microsserviço de Cursos

Serviço responsável pelo cadastro e consulta de cursos. Escrito em Go (`net/http`
+ `database/sql`), com PostgreSQL em schema próprio (`cursos`).

## Estrutura

```
services/cursos/
├── main.go
├── go.mod / go.sum
├── Dockerfile
├── migrations/
│   └── 001_create_cursos.sql
└── internal/
    ├── handler/      # handlers HTTP (request/response)
    ├── middleware/    # logging estruturado e CORS
    ├── model/         # entidades de domínio
    ├── repository/     # acesso a dados (database/sql)
    └── database/       # conexão e migrations
```

As migrations são aplicadas automaticamente na inicialização do serviço
(idempotentes, via `CREATE ... IF NOT EXISTS`).

## Variáveis de ambiente

| Variável      | Default     | Descrição                         |
|---------------|-------------|------------------------------------|
| `DB_HOST`     | `localhost` | Host do PostgreSQL                 |
| `DB_PORT`     | `5432`      | Porta do PostgreSQL                |
| `DB_USER`     | `cursos`    | Usuário do banco                   |
| `DB_PASSWORD` | `cursos`    | Senha do banco                     |
| `DB_NAME`     | `cursos_db` | Nome do banco de dados             |
| `PORT`        | `8080`      | Porta HTTP exposta pelo serviço    |

## Rodando isoladamente

### Com Docker Compose (recomendado)

A partir de `/infra`:

```bash
docker compose up --build cursos-db cursos-service
```

O serviço ficará disponível em `http://localhost:8080` apenas dentro da rede
Docker `gateway-network` (não há porta publicada no host). Para acessá-lo de
fora, use o gateway: `http://localhost/api/cursos`.

### Local (sem Docker)

Requer um PostgreSQL acessível e Go 1.23+:

```bash
export DB_HOST=localhost DB_PORT=5432 DB_USER=cursos DB_PASSWORD=cursos DB_NAME=cursos_db PORT=8081
go run .
```

## Endpoints

### `GET /health`
Health check do serviço.

```bash
curl http://localhost:8081/health
```

```json
{"status": "ok", "service": "cursos"}
```

### `POST /cursos`
Cadastra um novo curso. `nome` é obrigatório.

```bash
curl -X POST http://localhost:8081/cursos \
  -H "Content-Type: application/json" \
  -d '{"nome": "Arquitetura de Software", "descricao": "Disciplina do 5º período", "carga_horaria": 80}'
```

Resposta `201 Created`:

```json
{
  "id": "b3f1c2e0-...",
  "nome": "Arquitetura de Software",
  "descricao": "Disciplina do 5º período",
  "carga_horaria": 80,
  "criado_em": "2026-06-15T12:00:00Z"
}
```

Resposta `400 Bad Request` (campo obrigatório ausente):

```json
{"error": "o campo 'nome' é obrigatório"}
```

### `GET /cursos`
Lista todos os cursos cadastrados.

```bash
curl http://localhost:8081/cursos
```

### `GET /cursos/{id}`
Busca um curso pelo ID.

```bash
curl http://localhost:8081/cursos/b3f1c2e0-1234-5678-9abc-def012345678
```

Resposta `404 Not Found` (ID inexistente ou inválido):

```json
{"error": "curso não encontrado"}
```

## Via API Gateway

Com a stack completa rodando (`docker compose up` em `/infra`):

```bash
curl http://localhost/api/cursos
curl -X POST http://localhost/api/cursos -H "Content-Type: application/json" \
  -d '{"nome": "Banco de Dados II", "carga_horaria": 60}'
curl http://localhost/api/cursos/<id>
```

> Use `https://localhost/...` (com `-k` para o certificado autoassinado) caso
> acesse via HTTPS, conforme configurado em `infra/nginx/conf.d/gateway.conf`.
