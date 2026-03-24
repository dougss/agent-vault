---
name: lifeos_chat
description: Send messages to the Life OS multi-agent system for health/fitness, finance, and life purpose tracking and analysis.
metadata: { "openclaw": { "emoji": "🧠" } }
---

# Life OS Chat

Send messages to **Life OS**, a personal multi-agent system running locally on this server. Life OS has specialized agents that already know everything about Doug (profile, goals, training history, financial data, etc).

## When to use

Use this skill when the user's message is about **any** of these domains:

### Health & Fitness (health_fitness agent)
- Treino, exercício, carga, série, rep, academia, musculação
- Dieta, refeição, caloria, proteína, macro, suplemento
- Peso corporal, medida, BF%, cintura, composição corporal
- TRT, Durateston, suplementação hormonal
- "treino feito", "fiz leg hoje", "comi X"

### Finance (finance agent)
- Gasto, transação, salário, investimento, patrimônio, budget
- "gastei X", "quanto gastei", "como estão minhas finanças"
- Carteira de investimentos, metas financeiras, assinaturas
- Cartão de crédito, faturas, receitas

### Life Purpose (life_purpose agent)
- Meta de vida, objetivo, progresso, milestone, reflexão
- "como estão minhas metas", "quero definir um objetivo"
- Áreas da vida, planejamento de longo prazo

## When NOT to use

- Perguntas gerais de conhecimento → responde direto
- Código, deploy, servidor, docker → responde direto
- Config do próprio MadClaw/OpenClaw → responde direto
- Conversas casuais → responde direto

## How to use

Run this command to send a message to Life OS:

```bash
curl -sS --max-time 120 -X POST http://localhost:3080/api/chat \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg msg "$MESSAGE" '{"message": $msg, "thread_id": "telegram-douglas"}')"
```

Replace `$MESSAGE` with the user's exact message. **Do NOT rephrase or add context** — Life OS already knows Doug's full profile.

### Step by step:

1. **Check health first** (optional but recommended on first call per session):
   ```bash
   curl -sS --max-time 5 http://localhost:3080/health
   ```
   Expected: `{"status":"ok"}`. If it fails, tell the user: "Life OS está offline. Tente de novo em alguns minutos."

2. **Send the message**:
   ```bash
   curl -sS --max-time 120 -X POST http://localhost:3080/api/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "treino push feito, supino 40kg×10×4", "thread_id": "telegram-douglas"}'
   ```

3. **Parse the response**: The JSON response has a `reply` field with the agent's answer.
   ```json
   {
     "reply": "Treino registrado. Volume total: 1.600kg...",
     "thread_id": "telegram-douglas"
   }
   ```

4. **Present the reply**: Show the `reply` content to the user. If it's very long, summarize the key points for Telegram (short messages work better).

### Important notes:

- **Thread ID**: Always use `"telegram-douglas"` — this maintains conversation continuity across messages.
- **Timeout**: The API can take 30-120 seconds because the LLM processes the request. Use `--max-time 120`.
- **No reformatting**: Send the user's message exactly as written. Life OS handles routing automatically.
- **Base URL**: `http://localhost:3080` (nginx reverse proxy to the Life OS backend).

## Available agents

Life OS automatically routes to the right agent. You don't need to specify which one. The supervisor handles routing based on message content:

| Agent | Handles |
|-------|---------|
| health_fitness | Treinos (PPL 6x/semana), dieta (3000kcal/200g proteína), medidas, TRT, suplementação |
| finance | Transações, budget, investimentos, patrimônio, metas financeiras (lê dados do finAI) |
| life_purpose | Metas de vida, milestones, reflexões, progresso por área |
