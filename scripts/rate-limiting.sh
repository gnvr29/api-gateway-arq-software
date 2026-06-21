#!/bin/bash
# ============================================================================
# 07 - Rate Limiting e Controle de Tráfego
# ============================================================================
# Demonstra o rate limiting do gateway (30 req/s + burst 20).
# Envia requisições em rajada para mostrar o bloqueio (429).
# ============================================================================

GATEWAY="http://localhost:8000"
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO: Rate Limiting — Controle de Tráfego${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Configuração:${NC}"
echo "    • Rate: 30 requisições/segundo por IP"
echo "    • Burst: 20 (buffer de requisições extras)"
echo "    • Policy: nodelay (burst é atendido imediatamente)"
echo ""

# --- Enviar rajada ---
echo -e "${BLUE}[1/3]${NC} Enviando 80 requisições em rajada..."
echo ""

SUCCESS=0
RATE_LIMITED=0
OTHER=0

for i in $(seq 1 80); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" ${GATEWAY}/api/alunos)
  if [ "$CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  elif [ "$CODE" = "429" ]; then
    RATE_LIMITED=$((RATE_LIMITED + 1))
  else
    OTHER=$((OTHER + 1))
  fi

  # Barra de progresso simples
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Enviadas: ${i}/80 | ✅ ${SUCCESS} aceitas | 🚫 ${RATE_LIMITED} bloqueadas"
  fi
done

echo ""
echo -e "${BLUE}[2/3]${NC} Resultado final:"
echo "  ─────────────────────────────────────────────"
echo -e "  ${GREEN}✅ Aceitas (200):        ${SUCCESS}${NC}"
echo -e "  ${RED}🚫 Bloqueadas (429):    ${RATE_LIMITED}${NC}"
if [ $OTHER -gt 0 ]; then
  echo -e "  ${YELLOW}⚠ Outros:              ${OTHER}${NC}"
fi
echo "  ─────────────────────────────────────────────"
echo ""

# --- Mostrar a resposta de rate limit ---
echo -e "${BLUE}[3/3]${NC} Corpo da resposta quando rate limited:"
echo ""
# Forçar um 429
for i in $(seq 1 100); do
  RESPONSE=$(curl -s -w "\n%{http_code}" ${GATEWAY}/api/alunos)
  CODE=$(echo "$RESPONSE" | tail -1)
  if [ "$CODE" = "429" ]; then
    BODY=$(echo "$RESPONSE" | head -1)
    echo "  HTTP 429 Too Many Requests"
    echo "  Body: ${BODY}"
    break
  fi
done
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Conclusão:${NC}"
echo "  • O gateway protege os backends contra sobrecarga"
echo "  • Após 30 req/s + 20 burst, novas requisições recebem 429"
echo "  • O rate limit é por IP (binary_remote_addr)"
echo "  • Isso previne DDoS e garante fair use entre clientes"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
