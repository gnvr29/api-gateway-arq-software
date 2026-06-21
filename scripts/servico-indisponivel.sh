#!/bin/bash
# ============================================================================
# 06 - Tratamento de Erro: Serviço Interno Indisponível
# ============================================================================
# Demonstra o comportamento do gateway quando um backend está fora do ar.
# Para o serviço de alunos, faz requisições, e mostra o erro retornado.
# ============================================================================

GATEWAY="http://localhost:8000"
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO: Tratamento de Erro — Serviço Indisponível${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# --- Estado inicial: tudo funcionando ---
echo -e "${BLUE}[1/5]${NC} Verificando estado inicial (todos os serviços UP)..."
echo ""
echo "  GET /api/alunos:"
RESPONSE=$(curl -s -w " (HTTP %{http_code})" ${GATEWAY}/api/alunos)
echo -e "  ${GREEN}${RESPONSE}${NC}"
echo ""
echo "  GET /api/cursos:"
RESPONSE=$(curl -s -w " (HTTP %{http_code})" ${GATEWAY}/api/cursos)
echo -e "  ${GREEN}${RESPONSE}${NC}"
echo ""

# --- Derrubar o serviço de alunos ---
echo -e "${BLUE}[2/5]${NC} Derrubando o serviço de alunos..."
docker stop alunos-service > /dev/null 2>&1
sleep 2
echo -e "  ${RED}✗ alunos-service parado${NC}"
echo ""

# --- Testar com serviço indisponível ---
echo -e "${BLUE}[3/5]${NC} Testando requisições com alunos-service indisponível..."
echo ""
echo "  GET /api/alunos (serviço DOWN):"
RESPONSE=$(curl -s -w "\n%{http_code}" ${GATEWAY}/api/alunos)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
echo -e "  ${RED}Status: ${HTTP_CODE} (502 Bad Gateway)${NC}"
echo "  Body: ${BODY}"
echo ""

echo "  GET /api/cursos (serviço UP — não afetado):"
RESPONSE=$(curl -s -w "\n%{http_code}" ${GATEWAY}/api/cursos)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
echo -e "  ${GREEN}Status: ${HTTP_CODE} (continua funcionando)${NC}"
echo "  Body: ${BODY}"
echo ""

# --- Mostrar log do erro ---
echo -e "${BLUE}[4/5]${NC} Log do gateway mostrando o erro:"
echo ""
docker exec api-gateway cat /var/log/nginx/error.log | tail -3 | sed 's/^/  /'
echo ""

# --- Restaurar o serviço ---
echo -e "${BLUE}[5/5]${NC} Restaurando o serviço de alunos..."
docker start alunos-service > /dev/null 2>&1
echo "  Aguardando healthcheck..."
sleep 10
echo ""

echo "  GET /api/alunos (após restauração):"
RESPONSE=$(curl -s -w "\n%{http_code}" ${GATEWAY}/api/alunos)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
echo -e "  ${GREEN}Status: ${HTTP_CODE} (recuperado!)${NC}"
echo "  Body: ${BODY}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Conclusão:${NC}"
echo "  • Quando um backend cai, o gateway retorna 502 Bad Gateway"
echo "  • Outros serviços NÃO são afetados (isolamento)"
echo "  • O NGINX detecta falhas (max_fails=3) e remove o backend do pool"
echo "  • Quando o serviço volta, ele é reintegrado automaticamente"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
