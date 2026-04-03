# CLAUDE.md — Mac Mini Server

> Este arquivo dá contexto ao Claude Code sobre o ambiente onde ele está rodando.
> Localização: ~/server/CLAUDE.md e ~/CLAUDE.md

## Quem sou eu

Este é um **Mac Mini (Apple Silicon)** rodando **macOS Tahoe (26)**, configurado como servidor local headless.

- **Hostname:** macmini / macmini.local
- **IP:** 192.168.1.100 (fixo via DHCP reservation)
- **Usuário:** macmini
- **Dono:** Douglas Souza (dev@dssdev.com.br)

## O que roda aqui

### Nativo (macOS)

- **Node.js 22** (via Homebrew node@22) + npm
- **OpenClaw 2026.3.2** — AI assistant via Telegram (@MadzixClawBot)
  - Gateway: ws://127.0.0.1:18789 (loopback only, auth token)
  - Model: anthropic/claude-sonnet-4-5 (primary, agentes usam Bailian)
  - Elevated exec: full (auto-approve, restrito ao Telegram ID do dono)
  - Memory skill: habilitado
  - LaunchAgents: ai.openclaw.gateway + ai.openclaw.node (auto-start)
  - **Voice (Telegram)**: STT via whisper-cpp local + TTS via edge-tts (pt-BR-FranciscaNeural)
  - Docs de voz: `~/server/docs/openclaw-voice.md`
  - **12 agentes** (main + 11 especialistas) — ver seção "OpenClaw — Agentes" abaixo
- **Harness v3** — Orquestrador inteligente de features (TypeScript)
  - Código: `~/server/apps/harness/`
  - CLI: `harness start/status/logs/stop/approve/reject/show-plan`
  - DB: PostgreSQL `harness` (127.0.0.1:5432, user: harness)
  - Usa Claude Code CLI (`claude -p`) como cérebro + GitHub Spec Kit para specs
  - Fluxo: Discovery → Spec → Plan → Approve → Implement (TDD) → Review → PR
- **whisper-cpp 1.8.3** — STT local (Metal acceleration)
  - CLI: `/opt/homebrew/bin/whisper-cli`
  - Modelo: `~/.openclaw/models/whisper/ggml-medium.bin` (1.4GB, multilingual)

### Docker — Infra Compartilhada (docker-compose.infra.yml)

| Container | Imagem                     | Porta | Bind                   |
| --------- | -------------------------- | ----- | ---------------------- |
| nginx     | nginx:alpine               | 80    | 0.0.0.0 (landing page) |
| postgres  | **pgvector/pgvector:pg16** | 5432  | 127.0.0.1              |
| redis     | redis:7-alpine             | 6379  | 127.0.0.1              |
| portainer | portainer/portainer-ce     | 9000  | 127.0.0.1              |
| miniflux  | miniflux/miniflux:latest   | 8081  | 0.0.0.0 (RSS reader)   |

### Docker — Apps

**Life OS** — Sistema pessoal multi-agentes (LangChain + Next.js) — **DESLIGADO (2026-03-07)**

- Funcionalidade de saúde migrada para VitaClaw (OpenClaw)
- Banco PostgreSQL `life_os` mantido (usado pelo VitaClaw health-db)
- Para religar: `cd ~/server/apps/life-os && make server-up`
- Compose: `~/server/apps/life-os/docker/docker-compose.server.yml`

**Finno** (ex-FinAI) — App financeiro pessoal (Supabase stack)

- **Produção:** https://finnoapp.com.br (Vercel + Supabase Cloud)
- **Dev:** http://192.168.1.100:3000 (Docker local)
- Código: `~/server/apps/finno/`
- Repo: github.com/dougss/finno
- Supabase Cloud: `pgfucswjpnxvyfmaafae` (sa-east-1, São Paulo)
- Dev usa Docker local, qualquer PC na rede aponta para `192.168.1.100:8000`

| Container (dev)  | Porta              | Descrição                      |
| ---------------- | ------------------ | ------------------------------ |
| finno-frontend-1 | 0.0.0.0:3000       | Frontend                       |
| finno-kong-1     | 0.0.0.0:8000, 8443 | API Gateway                    |
| finno-db-1       | 0.0.0.0:5433       | Postgres próprio (Supabase 17) |
| finno-auth-1     | interna            | Auth service                   |
| finno-rest-1     | interna (3000)     | REST API                       |

**ClawPort** — Dashboard para gerenciamento de agentes OpenClaw (nativo)

- Acesso: http://192.168.1.100:3001
- Instalação: npm global (`clawport-ui@0.8.5`), não é fork
- Pacote: `/opt/homebrew/lib/node_modules/clawport-ui/`
- Config: `/opt/homebrew/lib/node_modules/clawport-ui/.env.local`
- LaunchAgent: `dev.clawport.ui` (auto-start, KeepAlive)
- Logs: `~/server/logs/clawport.log`
- Conecta no OpenClaw gateway em `127.0.0.1:18789`
- Lê workspace de `~/.openclaw/workspace`
- Porta: 3001 (Next.js 16 production)
- IMPORTANTE: `OPENCLAW_LOG_LEVEL=silent` no env (evita plugin stdout poluir JSON)

**Nexus v2** — Skill-driven workflows para Claude Code (MCP server + CLI, zero runtime)

- Código: `~/server/apps/nexus/`
- Stack: Markdown skills + Node.js MCP stdio server + Node.js CLI (zero deps, sem Docker, sem DB)
- MCP stdio (Claude Code local): `~/.claude.json` → `bin/nexus-mcp`
- MCP HTTP/SSE (Cursor remoto): `http://192.168.1.100:3005/sse` — LaunchAgent `dev.nexus.mcp`
- Tools: `nexus_list` (lista skills) + `nexus_get(name)` (carrega SKILL.md)
- 13 skills em `skills/<name>/SKILL.md` — lidas do disco em cada chamada
- CLI: `node bin/nexus validate` / `node bin/nexus graph`
- Instrução global em `~/.claude/CLAUDE.md`: chama nexus_list + nexus_get("using-nexus") em toda sessão

**Claw Engine** — Model-agnostic coding agent factory (DAG orchestrator)

- Acesso: http://192.168.1.100:3004
- Código: `~/server/apps/claw-engine/`
- Stack: Node.js + TypeScript + Fastify + BullMQ + Drizzle ORM + React + Vite + @xyflow/react
- DB: PostgreSQL `claw_engine` (127.0.0.1:5432, user: claw_engine)
- LaunchAgent: `dev.claw-engine.server` (auto-start, KeepAlive)
- Logs: `~/server/logs/claw-engine.log`
- Porta: 3004 (Fastify HTTP + SSE + React dashboard)
- CLI: `cd ~/server/apps/claw-engine && npm run claw -- <command>`

## Estrutura de diretórios

```
~/server/                    # Raiz do servidor
├── apps/                    # Código-fonte dos projetos (git repos)
├── data/                    # Volumes Docker persistentes
│   ├── postgres/
│   └── redis/
├── configs/                 # Configs compartilhadas
│   ├── nginx/nginx.conf
│   ├── nginx/sites/*.conf
│   └── sshd_hardened.conf
├── scripts/                 # Automação
│   ├── deploy.sh            # Deploy de projetos (arg: nome)
│   ├── backup.sh            # Backup Postgres + Redis + OpenClaw
│   ├── status.sh            # Health check completo
│   ├── add-project.sh       # Scaffold de novo projeto
│   └── harden-ssh.sh        # Aplicar hardening SSH
├── logs/openclaw/
├── backups/                 # Backups (rotação 7 dias)
├── docker-compose.infra.yml
├── .env                     # Secrets do Docker (NÃO commitar)
└── CLAUDE.md                # Este arquivo

~/.openclaw/                 # Config do OpenClaw (chmod 700)
├── openclaw.json            # Config principal (chmod 600)
├── workspace/               # Workspace do agente principal (MadClaw)
├── workspaces/              # Workspaces dos agentes especialistas
│   ├── prompt-engineer/     # Prompt Engineer
│   ├── task-orchestrator/   # Task Manager
│   ├── image-gen/           # Image Generator
│   ├── video-gen/           # Video Producer
│   ├── researcher/          # Researcher
│   ├── planner/             # Planner
│   ├── knowledge-forge/     # Knowledge Forge
│   ├── health-coach/        # Health Coach
│   ├── finance-advisor/     # Finance Advisor
│   ├── english-tutor/       # Kai — English Tutor
│   ├── harness-engineer/   # Harness Engineer (coding autônomo)
│   └── tiktok-coach/       # TikTok Coach (Liz)
├── agents/                  # Estado e sessões de cada agente
├── credentials/             # Tokens de channels (chmod 700)
├── secrets/.env             # API keys (chmod 600) — DASHSCOPE_API_KEY, LIFE_OS_DB_PASS, FINAI_USER_ID
├── logs/openclaw.log        # Gateway logs (chmod 600)
└── canvas/                  # Canvas host files
```

## OpenClaw — Agentes Especialistas

MadClaw (main) orquestra 12 agentes especialistas via roteamento híbrido (automático + manual).
Workspaces isolados em `~/.openclaw/workspaces/<id>/`. Bots dedicados: @vita_claw_bot (health), @KaiEnglishClawBot (english), @LizTikTokBot (tiktok), Harness (Slack).

| ID                | Nome                    | Modelo                   | Função                                                                  |
| ----------------- | ----------------------- | ------------------------ | ----------------------------------------------------------------------- |
| main              | MadClaw                 | bailian/qwen3.5-plus     | Orquestrador principal, delega para especialistas                       |
| prompt-engineer   | Prompt Engineer         | bailian/qwen3-coder-plus | Engenharia de prompts para qualquer modelo                              |
| task-orchestrator | Task Manager            | bailian/qwen3.5-plus     | Decomposição e execução de tarefas complexas                            |
| image-gen         | Image Generator         | bailian/qwen3.5-plus     | Geração de imagens via Bailian DashScope / OpenAI                       |
| video-gen         | Video Producer          | bailian/qwen3.5-plus     | Produção de vídeo via Bailian + ffmpeg + edge-tts                       |
| researcher        | Researcher              | bailian/kimi-k2.5        | Pesquisa profunda multi-fonte com citações                              |
| planner           | Planner                 | bailian/qwen3.5-plus     | Planejamento estratégico com análise de opções                          |
| knowledge-forge   | Knowledge Forge         | bailian/qwen3.5-plus     | Ingestão de fontes e geração de agentes (estilo NotebookLM)             |
| health-coach      | Health Coach (VitaClaw) | bailian/qwen3.5-plus     | Saúde, treino, dieta, TRT — bot dedicado @vita_claw_bot                 |
| finance-advisor   | Finance Advisor         | bailian/qwen3.5-plus     | Consultor financeiro: gastos, investimentos, patrimônio, metas, cartões |
| english-tutor     | Kai — English Tutor     | bailian/qwen3.5-plus     | Professor de inglês pessoal — bot dedicado @KaiEnglishClawBot           |
| harness-engineer  | Harness Engineer        | bailian/qwen3-coder-plus | Implementação autônoma via Slack (DM dedicado, sem MadClaw)             |
| tiktok-coach      | TikTok Coach (Liz)      | bailian/qwen3.5-plus     | Coaching de vendas TikTok Shop — bot dedicado @LizTikTokBot             |

**Comandos úteis:**

```bash
openclaw agents list              # Listar todos os agentes
openclaw agents list --bindings   # Ver regras de roteamento
openclaw agent --agent <id> --message "..." --verbose on  # Testar agente específico
```

**Skills instaladas (principais):**

- MadClaw: delegation, lifeos-chat, nano-banana-pro, obsidian, skill-creator, summarize
- Researcher: deep-research-pro, bailian-web-search, arxiv-cli-tools, summarize, obsidian
- Planner: brainstorming, writing-plans, excalidraw, excalidraw-obsidian
- Knowledge Forge: summarize, skill-creator, obsidian, excalidraw, excalidraw-obsidian
- Health Coach: macro-calc, health-db, summarize, obsidian
- Finance Advisor: finai-db, finance-goals, investment-analysis, portfolio-review, summarize, obsidian
- English Tutor: english-srs, summarize, obsidian
- Harness Engineer: memory-hygiene (orquestra via shell scripts, não usa skills de coding)
- Todos: memory-hygiene

### VitaClaw — Health Coach System

Bot Telegram dedicado para tracking de saúde, nutrição e treino.

- **Bot:** @vita_claw_bot (account: health, binding → health-coach agent)
- **Skills:**
  - `macro-calc` — Calculadora de macronutrientes (TACO UNICAMP, 597 alimentos, busca determinística por 120 aliases)
  - `health-db` — Persistência no PostgreSQL (`life_os` DB: nutrition_logs, workouts, workout_sets, body_measurements)
- **Cron:** Daily Review às 20:30 (America/Sao_Paulo) — compara realizado vs protocolo, persiste após aprovação
- **Dados:**
  - Protocolo anual: `~/Obsidian-Mind/03-Resources/health/PROTOCOLO_ANUAL_2026.md`
  - Daily logs: `~/Obsidian-Mind/03-Resources/health/daily-logs/YYYY-MM-DD.md`
  - Perfil paciente: `~/.openclaw/workspaces/health-coach/SOUL.md`
  - Scripts: `~/.openclaw/workspaces/health-coach/skills/macro-calc/scripts/calc_macros.py`
  - DB scripts: `~/.openclaw/workspaces/health-coach/skills/health-db/scripts/`
- **DB access:** via `docker exec postgres psql -U life_os -d life_os` (psql não instalado no host)
- **Senha DB:** `~/.openclaw/secrets/.env` (LIFE_OS_DB_PASS)

## OpenClaw — Config keys válidas (v2026.2.23)

Usar `openclaw config set` para alterações. Keys testadas e funcionando:

```
gateway.bind                          → "loopback"
gateway.port                          → 18789
gateway.auth.mode                     → "token"
gateway.auth.token                    → "<token>"
agents.defaults.elevatedDefault       → "full" | "on" | "ask" | "off"
agents.defaults.model.primary         → "anthropic/claude-opus-4-6"
tools.deny                            → ["browser", "canvas"]
tools.elevated.enabled                → true/false
tools.elevated.allowFrom.telegram     → ["telegram-user-id"]
skills.entries.memory.enabled         → true/false
logging.level                         → "info" | "debug" | "warn" | "error"
logging.file                          → "/path/to/log"
logging.redactSensitive               → "tools" | "all" | "none"
diagnostics.enabled                   → true/false
channels.telegram.dmPolicy            → "pairing" | "allowlist" | "open"
channels.telegram.groupPolicy         → "allowlist"
```

Keys que NÃO existem (não usar):
`tools.elevated.default`, `tools.elevated.autoApprove`, `tools.elevated.approval`,
`tools.exec.approvals`, `tools.browser.enabled`, `logging.logToolCalls`,
`logging.logMessages`, `logging.redactSecrets`, `skills.autoEnable`

## Infraestrutura do Servidor

### Postgres Compartilhado (pgvector/pgvector:pg16)

Container `postgres` em `127.0.0.1:5432` — volume: `~/server/data/postgres`

**Databases:**
| Database | Owner | Descrição |
|----------|-------|-----------|
| `main` | `admin` | Database padrão do servidor (uso geral) |
| `life_os` | `life_os` | Life OS + VitaClaw health tracking (extensões: pgvector, uuid-ossp) |
| `miniflux` | `miniflux` | Miniflux RSS reader (extensão: hstore) |
| `harness` | `harness` | Harness v3 orchestrator (extensão: uuid-ossp) |
| `tiktok_coach` | `tiktok_coach` | TikTok Coach (métricas, vendas, planos, learnings) |
| `claw_engine` | `claw_engine` | Claw Engine DAG orchestrator (extensão: uuid-ossp) |

**Users:**
| User | Permissões | Usado por |
|------|-----------|-----------|
| `admin` | Superuser | Administração geral, database `main` |
| `life_os` | LOGIN, CREATEDB | Life OS backend + VitaClaw health-db scripts |
| `miniflux` | LOGIN, CREATEDB | Miniflux RSS reader |
| `harness` | LOGIN | Harness v3 orchestrator |
| `tiktok_coach` | LOGIN | TikTok Coach agent DB scripts |
| `claw_engine` | LOGIN | Claw Engine DAG orchestrator |

### Redis Compartilhado (redis:7-alpine)

Container `redis` em `127.0.0.1:6379` — volume: `~/server/data/redis`

### Mapa de Portas

| Porta | Bind      | Serviço                      | App             |
| ----- | --------- | ---------------------------- | --------------- |
| 80    | 0.0.0.0   | Nginx (landing page)         | Infra           |
| 3000  | 0.0.0.0   | Frontend                     | Finno           |
| 3080  | —         | LIVRE (era Life OS)          | —               |
| 5432  | 127.0.0.1 | PostgreSQL (pgvector)        | Compartilhado   |
| 5433  | 0.0.0.0   | PostgreSQL (Supabase)        | Finno           |
| 6379  | 127.0.0.1 | Redis                        | Compartilhado   |
| 8000  | 0.0.0.0   | Kong API Gateway             | Finno           |
| 8443  | 0.0.0.0   | Kong HTTPS                   | Finno           |
| 9000  | 127.0.0.1 | Portainer                    | Infra           |
| 18789 | 127.0.0.1 | OpenClaw Gateway + Dashboard | OpenClaw        |
| 3001  | 0.0.0.0   | ClawPort Dashboard           | ClawPort        |
| 8081  | 0.0.0.0   | Miniflux RSS reader          | Infra           |
| 37777 | 0.0.0.0   | Claude-Mem Worker            | OpenClaw Plugin |
| 3002  | —         | LIVRE                        | —               |
| 3003  | 0.0.0.0   | Excalidraw Canvas Server     | MCP Excalidraw  |
| 3004  | 0.0.0.0   | Claw Engine API + Dashboard  | Claw Engine     |
| 3005  | 0.0.0.0   | Nexus MCP HTTP/SSE           | Nexus           |

**Próximas portas disponíveis:** 3002, 3006+, 8001+, 8082+

### Redes Docker

| Rede                     | Usada por                                               |
| ------------------------ | ------------------------------------------------------- |
| `server_default`         | Postgres, Redis, Nginx, Portainer (infra compartilhada) |
| `docker_life-os-network` | Life OS — REMOVIDA (containers desligados)              |
| `finno_default`          | Finno (todos os containers)                             |

### Adicionando Nova App

1. Criar user/database: `docker exec postgres psql -U admin -d postgres -c "CREATE ROLE <app> WITH LOGIN PASSWORD '<pass>' CREATEDB; CREATE DATABASE <app> OWNER <app>;"`
2. Extensões: `docker exec postgres psql -U admin -d <app> -c "CREATE EXTENSION IF NOT EXISTS vector;"`
3. De dentro do Docker: `host.docker.internal:5432` (Postgres) e `host.docker.internal:6379` (Redis)
4. Do host: `localhost:5432` / `localhost:6379`
5. Escolher porta disponível (ver tabela acima)
6. Atualizar este CLAUDE.md com a nova app e portas

## Segurança — REGRAS

1. **SSH:** Key-only (sem senha), root desabilitado, max 3 tentativas
2. **Firewall:** macOS firewall ON + stealth mode
3. **Docker:** Postgres, Redis, Portainer bind em 127.0.0.1
4. **OpenClaw:** Gateway em loopback, auth token, elevated restrito ao dono
5. **Secrets:** Nunca hardcode API keys. Usar ~/.openclaw/secrets/.env ou ~/server/.env
6. **Permissões:** ~/.openclaw = 700, arquivos de config/log = 600
7. **Backup:** Automático diário às 3h (cron)

## Comandos úteis

```bash
# Status geral
~/server/scripts/status.sh

# Deploy de projeto
~/server/scripts/deploy.sh <nome-do-projeto>

# Backup manual
~/server/scripts/backup.sh

# Docker
cd ~/server && docker compose -f docker-compose.infra.yml up -d
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# OpenClaw
openclaw status
openclaw logs --follow
openclaw security audit --deep
openclaw config get tools.elevated
openclaw gateway restart

# Harness Engineering v2.1 (Research + Spec Kit + Superpowers)
~/server/scripts/harness/harness-plan.sh <proj> "<desc>"           # Research + specs + approval gate
~/server/scripts/harness/harness-plan.sh <proj> "<desc>" --auto-approve  # Sem esperar aprovação
~/server/scripts/harness/harness-spec.sh <proj> "<desc>"           # Só gerar specs (com research)
~/server/scripts/harness/harness-spec.sh <proj> "<desc>" --skip-research  # Specs sem research
~/server/scripts/harness/harness-show-plan.sh <proj>               # Mostrar tasks para aprovação
~/server/scripts/harness/harness-approve.sh <proj>                 # Aprovar plan pendente
~/server/scripts/harness/harness-reject.sh <proj>                  # Rejeitar plan pendente
~/server/scripts/harness/harness-run.sh <proj>                     # Executar (via nohup)
~/server/scripts/harness/harness-status.sh [<proj>]                # Status
~/server/scripts/harness/harness-stop.sh <proj>                    # Parar
~/server/scripts/harness/harness-resume.sh <proj>                  # Retomar
~/server/scripts/harness/harness-review.sh <proj> <pr-number>      # Review automático

# Nginx reload
docker exec nginx-proxy nginx -s reload
```

## Acesso remoto

Este servidor é acessado via SSH do iMac Pro (PC principal do Douglas).

- SSH config: `Host mini` → macmini@macmini.local
- VS Code Remote SSH funciona
- Claude Code funciona via SSH

**Para acessar Portainer ou OpenClaw Dashboard remotamente:**

```bash
ssh -L 9000:127.0.0.1:9000 -L 18789:127.0.0.1:18789 mini
# Depois abrir http://localhost:9000 ou http://localhost:18789
```

## Ao trabalhar neste servidor

- Sempre verificar com `docker ps` antes de mexer em containers
- Sempre fazer backup antes de mudanças grandes: `~/server/scripts/backup.sh`
- Novos projetos: usar `~/server/scripts/add-project.sh` (cria scaffold completo)
- Nunca expor portas em 0.0.0.0 sem necessidade (apenas Nginx :80)
- Usar `openclaw config set` para mudar configs (nunca editar JSON manualmente)
- Manter este CLAUDE.md atualizado com novos serviços
