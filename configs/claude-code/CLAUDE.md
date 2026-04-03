# CLAUDE.md — User-level (Claude Code)

> Instrucoes globais para todas as sessoes do Claude Code neste Mac Mini.
> Para infraestrutura detalhada do servidor, ver `~/server/CLAUDE.md`.
> Atualizado: 2026-03-18

## Nexus — Workflow Skills (OBRIGATORIO)

<EXTREMELY-IMPORTANT>
Ao iniciar QUALQUER sessao (incluindo esta), voce DEVE:
1. Chamar `nexus_list` para descobrir skills disponiveis
2. Chamar `nexus_get("using-nexus")` para carregar as instrucoes de uso

Se qualquer skill se aplica a tarefa (mesmo 1% de chance), carregue com `nexus_get(name)` ANTES de qualquer acao.
Isso nao e opcional. Isso nao e negociavel.
</EXTREMELY-IMPORTANT>

## Identity & Communication

- Responda sempre em portugues brasileiro, exceto codigo e nomes tecnicos
- Seja direto e tecnico — sem explicacoes desnecessarias
- Se algo falhar, tente resolver sozinho antes de me perguntar

## Referencia rapida

- **Servidor:** Mac Mini M4, macOS Tahoe 26, IP 192.168.1.100
- **Infra completa:** `~/server/CLAUDE.md` (fonte da verdade para Docker, portas, databases)
- **Projetos:** `~/server/apps/` (cada um com seu proprio CLAUDE.md)
- **Knowledge Base:** `~/Obsidian-Mind/` (vault Obsidian, regras em `~/Obsidian-Mind/CLAUDE.md`)

## Knowledge Base

Base de conhecimento pessoal em Obsidian:
Localizacao: ~/Obsidian-Mind

Quando eu pedir para "registrar", "documentar", "anotar na base",
"salvar no vault", "adicionar ao knowledge base", "registra isso",
"salva na KB", ou qualquer variacao:
→ Execute o procedimento descrito em ~/.claude/skills/knowledge-base.md

Sempre inclua o contexto de onde a informacao veio:

- Nome do projeto atual (leia CLAUDE.md local se existir)
- Diretorio de trabalho
- Data

## OpenClaw

- **Versao:** 2026.3.2
- **Voice (Telegram):** STT via whisper-cpp local + TTS via edge-tts (pt-BR-FranciscaNeural)
- **Dashboard:** via SSH tunnel do iMac Pro (`ssh -L 18789:127.0.0.1:18789 mini`)
- **Docs de voz:** `~/server/docs/openclaw-voice.md`
- **Agentes:** 11 total (MadClaw + 10 especialistas) — detalhes em `~/server/CLAUDE.md`
- **Workspaces:** `~/.openclaw/workspace/` (main) + `~/.openclaw/workspaces/<id>/` (especialistas)
- **ClawPort:** dashboard em `http://192.168.1.100:3001` — agents.json em `~/.openclaw/workspace/clawport/`
- **VitaClaw:** bot dedicado @vita_claw_bot — health tracking (macros TACO + DB PostgreSQL + daily review 20:30)

## Apps ativas

| App      | Acesso                    | Comandos                                                   |
| -------- | ------------------------- | ---------------------------------------------------------- |
| Life OS  | DESLIGADO (2026-03-07)    | `cd ~/server/apps/life-os && make server-up` (se precisar) |
| Finno    | http://192.168.1.100:3000 | Stack Supabase isolada, repo: dougss/finno                 |
| ClawPort | http://192.168.1.100:3001 | LaunchAgent `dev.clawport.ui` (nativo, auto-start)         |

## Postgres compartilhado (pgvector)

- `127.0.0.1:5432` — databases: `main` (owner: admin), `life_os` (owner: life_os)
- Criar novo DB: `docker exec postgres psql -U admin -d postgres -c "CREATE ROLE <app> LOGIN PASSWORD '<pass>' CREATEDB; CREATE DATABASE <app> OWNER <app>;"`

## Portas ocupadas

80, 3000, 3001, 3080, 5432, 5433, 6379, 8000, 8081, 8443, 9000, 18789

**Proximas disponiveis:** 3002+, 8001+, 8082+
