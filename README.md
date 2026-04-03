# Agent Vault

Repositorio centralizado de todos os assets agenticos pessoais: agentes de IA, skills, automacoes, configs e scripts.

**Principio:** agnóstico de ferramenta. Tudo aqui funciona com OpenClaw, Claude Code, Cursor, Copilot, ou qualquer outra ferramenta de IA — os assets sao em Markdown e scripts portaveis.

## Estrutura

```
agent-vault/
├── agents/          # Definicoes de agentes (personalidade, instrucoes, ferramentas)
├── skills/          # Habilidades reutilizaveis com scripts e prompts
│   ├── shared/      # Skills genericos (obsidian, summarize, delegation)
│   ├── health/      # Saude, nutricao, treino (VitaClaw)
│   ├── finance/     # Financas pessoais (Finno)
│   ├── english/     # Aprendizado de ingles (Kai)
│   ├── media/       # Geracao de imagem e video
│   ├── research/    # Pesquisa e busca
│   ├── planning/    # Brainstorming e planejamento
│   └── automation/  # Automacoes (daily digest, crons)
├── scripts/         # Scripts de automacao
│   ├── harness/     # Harness engineering (coding autonomo)
│   ├── server/      # Manutencao do servidor
│   └── utilities/   # Ferramentas do repo (migrate, validate, install)
├── configs/         # Configuracoes de ferramentas de IA
│   ├── claude-code/ # CLAUDE.md, settings.json, hooks
│   └── openclaw/    # Config templates do OpenClaw
├── cron/            # Jobs agendados (OpenClaw cron)
├── templates/       # Templates reutilizaveis (harness, specs)
└── docs/            # Documentacao adicional
```

## Quick Start

```bash
# 1. Clonar
git clone git@github.com:dougss/agent-vault.git
cd agent-vault

# 2. Copiar e preencher variaveis de ambiente
cp .env.example .env
# Editar .env com suas API keys

# 3. Instalar hooks de seguranca
./scripts/utilities/install.sh hooks

# 4. Instalar assets em uma ferramenta
./scripts/utilities/install.sh openclaw      # Copia *.md dos agentes (skills via migrate)
./scripts/utilities/install.sh claude-code   # Instala configs do Claude Code
./scripts/utilities/install.sh harness       # Instala harness scripts

# 5. Validar portabilidade
./scripts/utilities/validate.sh
```

## Fluxo: migrate vs install

- **`migrate.sh`** (na máquina onde o OpenClaw está instalado): copia de `~/.openclaw` para este repositório, com sanitização. Use para **atualizar o vault** com o que está no disco.
- **`install.sh openclaw`**: copia apenas os **Markdown dos agentes** para `~/.openclaw/workspace` e `workspaces/<id>/`. Skills completas entram no vault pelo migrate, não por este install.
- **Harness v3**: app canônico em `~/server/apps/harness`; `scripts/harness/` aqui espelha os wrappers do servidor.
- **Nexus** (`~/server/apps/nexus`): skills de processo (MCP / Claude Code), separadas das skills OpenClaw.

## Agentes

13 agentes com personalidades e instrucoes proprias:

| Agente                  | Funcao                                            | Tags                        |
| ----------------------- | ------------------------------------------------- | --------------------------- |
| **MadClaw** (main)      | Orquestrador principal, delega para especialistas | `personal`, `orchestration` |
| **Health Coach**        | Saude, treino, dieta, TRT (VitaClaw)              | `personal`, `health`        |
| **Finance Advisor**     | Gastos, investimentos, patrimonio                 | `personal`, `finance`       |
| **English Tutor** (Kai) | Professor de ingles pessoal                       | `personal`, `english`       |
| **Researcher**          | Pesquisa multi-fonte com citacoes                 | `personal`, `research`      |
| **Planner**             | Planejamento estrategico                          | `personal`, `planning`      |
| **Prompt Engineer**     | Engenharia de prompts                             | `personal`, `engineering`   |
| **Knowledge Forge**     | Ingestao de fontes, geracao de agentes            | `personal`, `knowledge`     |
| **Image Generator**     | Geracao de imagens via APIs                       | `personal`, `media`         |
| **Video Producer**      | Producao de video                                 | `personal`, `media`         |
| **Task Manager**        | Decomposicao de tarefas complexas                 | `personal`, `orchestration` |
| **Harness Engineer**    | Implementacao autonoma via Slack                  | `automation`, `engineering` |
| **TikTok Coach** (Liz)  | TikTok Shop, metricas, planos                     | `personal`, `commerce`        |

Cada agente tem:

- `SOUL.md` — Personalidade e valores
- `AGENTS.md` — Instrucoes operacionais
- `IDENTITY.md` — Nome e identificacao
- `TOOLS.md` — Ferramentas disponiveis
- `USER.md` — Perfil do usuario

## Skills

30+ skills organizados por dominio. Cada skill contem:

- `SKILL.md` — Descricao, triggers, instrucoes
- `scripts/` — Scripts executaveis (Python, bash)
- `_meta.json` — Metadados de instalacao (quando aplicavel)

## Cron Jobs

12 jobs agendados via OpenClaw:

- **Relatorio Matinal** (7:30) — Status do servidor
- **AI Daily Digest** (8h, 12h, 18h) — Curadoria de noticias AI
- **Daily Review** (20:30) — Review de saude/nutricao
- **English Wake-up** (6:30 seg-sex) — Ping matinal de ingles
- **English Micro-doses** (12:30, 18h seg-sex) — Exercicios rapidos
- **English Daily Vocab** (21h) — Vocabulario diario
- **English Weekend Casual** (10h sab) — Conversa casual
- **API Spending** (semanal) — Custos de APIs

## Seguranca

- **Pre-commit hook** bloqueia commits com API keys, tokens, senhas
- **Sanitizacao** automatica substitui secrets por `${VARIABLE_NAME}`
- **`.env.example`** documenta todas as variaveis necessarias
- **`.gitignore`** impede .env, credentials, databases
- **Validacao** via `scripts/utilities/validate.sh`

## Portabilidade

Os assets sao em Markdown puro e scripts Python/bash. Para adaptar a outra ferramenta:

| Origem (OpenClaw) | Equivalente Claude Code      | Equivalente Cursor    |
| ----------------- | ---------------------------- | --------------------- |
| `SOUL.md`         | Secao em `CLAUDE.md`         | `.cursorrules`        |
| `AGENTS.md`       | `CLAUDE.md` do projeto       | `.cursorrules`        |
| `SKILL.md`        | Skill em `~/.claude/skills/` | Nao tem (usar prompt) |
| `TOOLS.md`        | `settings.json` permissions  | Nao tem               |
| Cron jobs         | `crontab` + Claude Code CLI  | Nao tem               |

## Variaveis de Ambiente

Ver `.env.example` para lista completa. Principais:

- `OPENAI_API_KEY` — OpenAI API
- `GEMINI_API_KEY` — Google Gemini
- `DASHSCOPE_API_KEY` — Alibaba DashScope (imagens)
- `BRAVE_API_KEY` — Brave Search
- `LIFE_OS_DB_PASS` — PostgreSQL (health/finance)
- `TELEGRAM_CHAT_ID` — Delivery de mensagens
- `MINIFLUX_API_KEY` — RSS reader

## Contribuindo

Este e um repo pessoal. Para usar como base para o seu proprio:

1. Fork
2. Remova os agentes/skills que nao precisa
3. Adicione os seus em `agents/` e `skills/`
4. Preencha `.env` com suas credenciais
5. Rode `validate.sh` para verificar

---

Mantido por Douglas Souza (dev@dssdev.com.br)
