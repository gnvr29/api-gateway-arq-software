# ─── Build Stage ────────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/cursos-service .

# ─── Final Stage ────────────────────────────────────────────────────────────
FROM alpine:3.20

WORKDIR /app

COPY --from=builder /app/bin/cursos-service .

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O- http://localhost:${PORT}/health || exit 1

ENTRYPOINT ["./cursos-service"]
