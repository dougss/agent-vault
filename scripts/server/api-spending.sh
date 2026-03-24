#!/bin/bash
set -euo pipefail

# Carregar API keys
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/.env.api-keys" ] && source "$SCRIPT_DIR/.env.api-keys" 2>/dev/null || true

REPORT_TYPE="${1:-daily}"
LABEL=$(echo $REPORT_TYPE | sed "s|daily|Diário|;s|weekly|Semanal|")

# Anthropic API só retorna dias COMPLETOS (dados de hoje não existem ainda)
# Daily: ontem 00:00 UTC → hoje 00:00 UTC (último dia completo)
# Weekly: 7 dias atrás → hoje 00:00 UTC
if [ "$REPORT_TYPE" = "weekly" ]; then
  ANTH_START=$(date -u -v-7d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d "-7 days" +%Y-%m-%dT00:00:00Z)
  ANTH_END=$(date -u +%Y-%m-%dT00:00:00Z)
  REPORT_DATE="$(date -v-7d +%d/%m)–$(date -v-1d +%d/%m)"
else
  ANTH_START=$(date -u -v-1d +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -d "-1 day" +%Y-%m-%dT00:00:00Z)
  ANTH_END=$(date -u +%Y-%m-%dT00:00:00Z)
  REPORT_DATE="$(date -v-1d +%d/%m)"
fi

SPENDING=""
BALANCES=""

# === GASTOS ===
if [ -n "${ANTHROPIC_ADMIN_KEY:-}" ]; then
  ANTH_COST=$(curl -s --max-time 30 \
    "https://api.anthropic.com/v1/organizations/cost_report?starting_at=${ANTH_START}&ending_at=${ANTH_END}" \
    -H "anthropic-version: 2023-06-01" \
    -H "x-api-key: ${ANTHROPIC_ADMIN_KEY}" | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'error' in d:
    print('ERR')
else:
    t=sum(float(r.get('amount',0)) for b in d.get('data',[]) for r in b.get('results',[]))
    print(f'{t/100:.2f}')
" 2>/dev/null || echo "ERR")
  [ "$ANTH_COST" != "ERR" ] && SPENDING+="🟣 Anthropic: \$${ANTH_COST}\n"
fi

if [ -n "${OPENAI_ADMIN_KEY:-}" ]; then
  OAI_START=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${ANTH_START}" +%s 2>/dev/null || date -d "${ANTH_START}" +%s)
  OAI_END=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${ANTH_END}" +%s 2>/dev/null || date -d "${ANTH_END}" +%s)
  OAI_COST=$(curl -s --max-time 30 \
    "https://api.openai.com/v1/organization/costs?start_time=${OAI_START}&end_time=${OAI_END}&bucket_width=1d" \
    -H "Authorization: Bearer ${OPENAI_ADMIN_KEY}" | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
if 'error' in d:
    print('ERR')
else:
    t=0
    for b in d.get('data',[]):
        for r in b.get('results',[]):
            a=r.get('amount',{})
            if isinstance(a,dict): t+=float(a.get('value',0))
            else: t+=float(a)
    print(f'{t:.2f}')
" 2>/dev/null || echo "ERR")
  [ "$OAI_COST" != "ERR" ] && SPENDING+="🟢 OpenAI: \$${OAI_COST}\n"
fi

# === SALDOS ===
if [ -n "${MOONSHOT_API_KEY:-}" ]; then
  KIMI_BAL=$(curl -s --max-time 30 \
    "https://api.moonshot.ai/v1/users/me/balance" \
    -H "Authorization: Bearer ${MOONSHOT_API_KEY}" | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
b=d.get('data',{}).get('available_balance',d.get('data',{}).get('balance',d.get('balance',0)))
print(f'{float(b):.2f}')
" 2>/dev/null || echo "ERR")
  [ "$KIMI_BAL" != "ERR" ] && BALANCES+="🟡 Moonshot: \$${KIMI_BAL}\n"
fi

# === OUTPUT ===
echo -e "📊 Report ${LABEL} — ${REPORT_DATE}\n"

if [ -n "$SPENDING" ]; then
  echo -e "💸 Gastos:\n${SPENDING}"
fi

if [ -n "$BALANCES" ]; then
  echo -e "💰 Saldos:\n${BALANCES}"
fi

echo -e "🔵 Google: free tier\n⚫ Ollama: local"
