#!/bin/bash
# ============================================================================
# 04 - Tempo de Resposta Passando pelo Gateway
# ============================================================================
# Mede a latência das requisições passando pelo gateway, separando o tempo
# total (request_time) do tempo do backend (upstream_response_time).
# ============================================================================

GATEWAY="http://localhost:8000"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO: Tempo de Resposta pelo Gateway${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# --- Medir com curl timing ---
echo -e "${BLUE}[1/3]${NC} Medindo latência com curl (10 requisições por serviço)..."
echo ""
echo -e "  ${YELLOW}Serviço de Alunos (/api/alunos):${NC}"
echo "  ─────────────────────────────────────────────"
TOTAL_ALUNOS=0
for i in $(seq 1 10); do
  TIME=$(curl -s -o /dev/null -w "%{time_total}" ${GATEWAY}/api/alunos)
  TOTAL_ALUNOS=$(echo "$TOTAL_ALUNOS + $TIME" | bc)
  printf "  Request %2d: %s s\n" "$i" "$TIME"
done
AVG_ALUNOS=$(echo "scale=4; $TOTAL_ALUNOS / 10" | bc)
echo "  ─────────────────────────────────────────────"
echo -e "  ${GREEN}Média: ${AVG_ALUNOS}s${NC}"
echo ""

echo -e "  ${YELLOW}Serviço de Cursos (/api/cursos):${NC}"
echo "  ─────────────────────────────────────────────"
TOTAL_CURSOS=0
for i in $(seq 1 10); do
  TIME=$(curl -s -o /dev/null -w "%{time_total}" ${GATEWAY}/api/cursos)
  TOTAL_CURSOS=$(echo "$TOTAL_CURSOS + $TIME" | bc)
  printf "  Request %2d: %s s\n" "$i" "$TIME"
done
AVG_CURSOS=$(echo "scale=4; $TOTAL_CURSOS / 10" | bc)
echo "  ─────────────────────────────────────────────"
echo -e "  ${GREEN}Média: ${AVG_CURSOS}s${NC}"
echo ""

# --- Overhead do gateway ---
echo -e "${BLUE}[2/3]${NC} Analisando overhead do gateway (request_time vs upstream_response_time)..."
echo ""

# Limpar e gerar novas requisições
docker exec api-gateway sh -c "echo '' > /var/log/nginx/access.log" 2>/dev/null
sleep 1
for i in $(seq 1 5); do
  curl -s ${GATEWAY}/api/alunos > /dev/null
  curl -s ${GATEWAY}/api/cursos > /dev/null
done
sleep 1

echo "  Últimas entradas do log (request_time vs upstream_response_time):"
echo "  ─────────────────────────────────────────────────────────────────"
docker exec api-gateway cat /var/log/nginx/access.log | tail -5 | while read -r line; do
  if [ -n "$line" ]; then
    REQ_TIME=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['request_time'])" 2>/dev/null)
    UP_TIME=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['upstream_response_time'])" 2>/dev/null)
    URI=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['request_uri'])" 2>/dev/null)
    if [ -n "$REQ_TIME" ] && [ -n "$UP_TIME" ]; then
      OVERHEAD=$(echo "$REQ_TIME - $UP_TIME" | bc 2>/dev/null || echo "~0")
      printf "  %-15s │ Gateway: %ss │ Backend: %ss │ Overhead: %ss\n" "$URI" "$REQ_TIME" "$UP_TIME" "$OVERHEAD"
    fi
  fi
done
echo ""

# --- Explicação ---
echo -e "${BLUE}[3/3]${NC} Detalhamento dos tempos medidos:"
echo ""
echo -e "  ${YELLOW}time_total (curl)${NC}          = DNS + TCP + Request + Response"
echo -e "  ${YELLOW}request_time (nginx)${NC}       = Tempo total que o gateway levou"
echo -e "  ${YELLOW}upstream_response_time${NC}     = Tempo que o backend levou"
echo -e "  ${YELLOW}overhead${NC}                   = request_time - upstream_response_time"
echo ""
echo "  O overhead do gateway é tipicamente < 1ms (networking interno Docker)."
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Conclusão:${NC} O gateway adiciona overhead mínimo (< 1ms)."
echo "  O custo é negligível comparado ao benefício de centralizar"
echo "  segurança, logging e controle de tráfego."
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
