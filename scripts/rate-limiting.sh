#!/bin/bash
# ============================================================================
# Rate Limiting e Controle de Tráfego
# ============================================================================
# Demonstra o rate limiting do gateway (10 req/s + burst 5).
# Envia requisições em rajada para mostrar o bloqueio (429).
# ============================================================================

GATEWAY="http://localhost:8000"

printf "═══════════════════════════════════════════════════════════════\n"
printf "  DEMO: Rate Limiting — Controle de Tráfego\n"
printf "═══════════════════════════════════════════════════════════════\n"
printf "\n"
printf "  Configuração:\n"
printf "    • Rate: 10 requisições/segundo por IP\n"
printf "    • Burst: 5 (buffer de requisições extras)\n"
printf "    • Policy: nodelay (burst é atendido imediatamente)\n"
printf "\n"

# --- Enviar rajada ---
printf "[1/3] Enviando 40 requisições em rajada...\n"
printf "\n"

SUCCESS=0
RATE_LIMITED=0
OTHER=0

for i in $(seq 1 40); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" ${GATEWAY}/api/alunos)
  if [ "$CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  elif [ "$CODE" = "429" ]; then
    RATE_LIMITED=$((RATE_LIMITED + 1))
  else
    OTHER=$((OTHER + 1))
  fi

  if [ $((i % 10)) -eq 0 ]; then
    printf "  Enviadas: %d/40 | ✅ %d aceitas | 🚫 %d bloqueadas\n" "$i" "$SUCCESS" "$RATE_LIMITED"
  fi
done

printf "\n"
printf "[2/3] Resultado final:\n"
printf "  ─────────────────────────────────────────────\n"
printf "  ✅ Aceitas (200):        %d\n" "$SUCCESS"
printf "  🚫 Bloqueadas (429):    %d\n" "$RATE_LIMITED"
if [ $OTHER -gt 0 ]; then
  printf "  ⚠ Outros:              %d\n" "$OTHER"
fi
printf "  ─────────────────────────────────────────────\n"
printf "\n"

# --- Mostrar a resposta de rate limit ---
printf "[3/3] Corpo da resposta quando rate limited:\n"
printf "\n"
for i in $(seq 1 60); do
  RESPONSE=$(curl -s -w "\n%{http_code}" ${GATEWAY}/api/alunos)
  CODE=$(echo "$RESPONSE" | tail -1)
  if [ "$CODE" = "429" ]; then
    BODY=$(echo "$RESPONSE" | head -1)
    printf "  HTTP 429 Too Many Requests\n"
    printf "  Body: %s\n" "$BODY"
    break
  fi
done
printf "\n"

printf "═══════════════════════════════════════════════════════════════\n"
printf "✓ Conclusão:\n"
printf "  • O gateway protege os backends contra sobrecarga\n"
printf "  • Após 10 req/s + 5 burst, novas requisições recebem 429\n"
printf "  • O rate limit é por IP (binary_remote_addr)\n"
printf "  • Isso previne DDoS e garante fair use entre clientes\n"
printf "═══════════════════════════════════════════════════════════════\n"
