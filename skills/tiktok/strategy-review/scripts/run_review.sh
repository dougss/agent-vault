#!/usr/bin/env bash
# Strategy Review — monta contexto do DB e chama claude -p
set -euo pipefail

SCRIPTS_DIR="$HOME/.openclaw/workspaces/tiktok-coach/skills/tiktok-db/scripts"

echo "Coletando dados..." >&2

# Coletar dados do DB
SUMMARY=$(python3 "$SCRIPTS_DIR/query_performance.py" '{"type": "summary", "days": 14}' 2>/dev/null || echo '{"data": "sem dados"}')
TOP_VIDEOS=$(python3 "$SCRIPTS_DIR/query_performance.py" '{"type": "top_videos", "days": 30, "limit": 10}' 2>/dev/null || echo '{"data": "sem dados"}')
BY_FORMAT=$(python3 "$SCRIPTS_DIR/query_performance.py" '{"type": "by_format", "days": 30}' 2>/dev/null || echo '{"data": "sem dados"}')
BY_PRODUCT=$(python3 "$SCRIPTS_DIR/query_performance.py" '{"type": "by_product", "days": 30}' 2>/dev/null || echo '{"data": "sem dados"}')
DAILY_TREND=$(python3 "$SCRIPTS_DIR/query_performance.py" '{"type": "daily_trend", "days": 14}' 2>/dev/null || echo '{"data": "sem dados"}')
LEARNINGS=$(python3 "$SCRIPTS_DIR/query_learnings.py" '{"min_confidence": 0.3}' 2>/dev/null || echo '{"learnings": "sem dados"}')
PLAN=$(python3 "$SCRIPTS_DIR/manage_plan.py" '{"action": "get_active"}' 2>/dev/null || echo '{"output": "sem plano ativo"}')

# Ler SOUL.md
SOUL=$(cat "$HOME/.openclaw/workspaces/tiktok-coach/SOUL.md" 2>/dev/null || echo "Sem SOUL.md")

# Montar prompt
read -r -d '' PROMPT << 'PROMPT_END' || true
Voce e uma consultora estrategica de vendas no TikTok Shop Brasil. Analise os dados abaixo e retorne:

1. **DIAGNOSTICO** — O que esta funcionando e o que nao esta. Seja especifica com numeros.
2. **AJUSTES NO PLANO** — O que mudar na estrategia atual (formatos, frequencia, produtos, horarios).
3. **METAS ATUALIZADAS** — Metas realistas para as proximas 2 semanas baseadas na tendencia.
4. **3 ACOES PRIORITARIAS** — Acoes concretas e imediatas (nao genericas).
5. **NOVOS LEARNINGS** — Padroes que voce detectou nos dados que devem ser salvos como learnings.
   Para cada learning, retorne no formato: CATEGORY|INSIGHT|CONFIDENCE (0.0-1.0)
   Categorias: format, timing, product, hook, audience

Responda em portugues brasileiro, direta e objetiva. Sem introducoes desnecessarias.
PROMPT_END

# Montar full prompt
FULL_PROMPT="$PROMPT

## Perfil da Criadora
$SOUL

## Resumo 14 dias
$SUMMARY

## Top 10 Videos (30 dias)
$TOP_VIDEOS

## Performance por Formato
$BY_FORMAT

## Performance por Produto
$BY_PRODUCT

## Tendencia Diaria (14 dias)
$DAILY_TREND

## Learnings Ativos
$LEARNINGS

## Plano Atual
$PLAN"

echo "Chamando Claude para analise..." >&2

# Chamar claude -p
RESULT=$(echo "$FULL_PROMPT" | claude -p --output-format text 2>/dev/null)

echo "$RESULT"
