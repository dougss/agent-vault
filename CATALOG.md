# Agent Vault — Catalogo de Assets

> 172 arquivos | 12 agentes | 27 skills | 18 scripts | 12 cron jobs
> Atualizado: 2026-03-24

## Agentes

| ID                | Link                                                   | Descricao                                                     | Tags                              |
| ----------------- | ------------------------------------------------------ | ------------------------------------------------------------- | --------------------------------- |
| madclaw           | [agents/madclaw/](agents/madclaw/)                     | Orquestrador principal, roteamento hibrido para especialistas | `orchestration`, `personal`       |
| english-tutor     | [agents/english-tutor/](agents/english-tutor/)         | Kai — professor de ingles pessoal via Telegram                | `english`, `personal`, `telegram` |
| health-coach      | [agents/health-coach/](agents/health-coach/)           | VitaClaw — saude, nutricao, treino, TRT                       | `health`, `personal`, `telegram`  |
| finance-advisor   | [agents/finance-advisor/](agents/finance-advisor/)     | Consultor financeiro: gastos, investimentos, metas            | `finance`, `personal`             |
| researcher        | [agents/researcher/](agents/researcher/)               | Pesquisa profunda multi-fonte com citacoes                    | `research`, `personal`            |
| planner           | [agents/planner/](agents/planner/)                     | Planejamento estrategico com analise de opcoes                | `planning`, `personal`            |
| prompt-engineer   | [agents/prompt-engineer/](agents/prompt-engineer/)     | Engenharia de prompts para qualquer modelo                    | `engineering`, `personal`         |
| knowledge-forge   | [agents/knowledge-forge/](agents/knowledge-forge/)     | Ingestao de fontes e geracao de agentes                       | `knowledge`, `personal`           |
| image-gen         | [agents/image-gen/](agents/image-gen/)                 | Geracao de imagens via Bailian DashScope / OpenAI             | `media`, `personal`               |
| video-gen         | [agents/video-gen/](agents/video-gen/)                 | Producao de video via Bailian + ffmpeg + edge-tts             | `media`, `personal`               |
| task-orchestrator | [agents/task-orchestrator/](agents/task-orchestrator/) | Decomposicao e execucao de tarefas complexas                  | `orchestration`, `personal`       |
| harness-engineer  | [agents/harness-engineer/](agents/harness-engineer/)   | Implementacao autonoma via Slack (coding agent)               | `automation`, `engineering`       |

## Skills — Shared

| Skill              | Link                                                                   | Descricao                                      | Usado por                                     |
| ------------------ | ---------------------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------- |
| delegation         | [skills/shared/delegation/](skills/shared/delegation/)                 | Workflow para delegar projetos a coding agents | madclaw                                       |
| lifeos-chat        | [skills/shared/lifeos-chat/](skills/shared/lifeos-chat/)               | Chat com banco Life OS (queries PostgreSQL)    | madclaw                                       |
| memory-hygiene     | [skills/shared/memory-hygiene/](skills/shared/memory-hygiene/)         | Manutencao de memoria do agente                | todos                                         |
| obsidian           | [skills/shared/obsidian/](skills/shared/obsidian/)                     | Leitura/escrita no vault Obsidian              | madclaw, researcher, planner, health, finance |
| summarize          | [skills/shared/summarize/](skills/shared/summarize/)                   | Resumo de URLs, arquivos, YouTube              | madclaw, researcher, planner                  |
| skill-creator      | [skills/shared/skill-creator/](skills/shared/skill-creator/)           | Criacao de novos skills OpenClaw               | madclaw, prompt-engineer                      |
| nano-banana-pro    | [skills/shared/nano-banana-pro/](skills/shared/nano-banana-pro/)       | Geracao de imagem via Gemini                   | madclaw, image-gen                            |
| agent-task-tracker | [skills/shared/agent-task-tracker/](skills/shared/agent-task-tracker/) | Tracking de tarefas entre agentes              | task-orchestrator                             |
| executing-plans    | [skills/shared/executing-plans/](skills/shared/executing-plans/)       | Execucao de planos estruturados                | task-orchestrator                             |

## Skills — Health

| Skill      | Link                                                   | Descricao                                            | Scripts                                                                     |
| ---------- | ------------------------------------------------------ | ---------------------------------------------------- | --------------------------------------------------------------------------- |
| macro-calc | [skills/health/macro-calc/](skills/health/macro-calc/) | Calculadora de macros (TACO UNICAMP, 597 alimentos)  | `calc_macros.py`                                                            |
| health-db  | [skills/health/health-db/](skills/health/health-db/)   | Persistencia PostgreSQL (refeicoes, treino, medidas) | `db.py`, `log_meal.py`, `log_workout.py`, `log_body.py`, `query_summary.py` |

## Skills — Finance

| Skill               | Link                                                                       | Descricao                                                 | Scripts                                                                                                                                             |
| ------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| finai-db            | [skills/finance/finai-db/](skills/finance/finai-db/)                       | Queries no banco Finno (transacoes, cartoes, assinaturas) | `db_finai.py`, `query_monthly.py`, `query_spending.py`, `query_investments.py`, `query_credit_cards.py`, `query_subscriptions.py`, `query_trend.py` |
| finance-goals       | [skills/finance/finance-goals/](skills/finance/finance-goals/)             | Metas financeiras e patrimonio liquido                    | `db_lifeos.py`, `create_goal.py`, `query_goals.py`, `query_net_worth.py`, `snapshot_net_worth.py`                                                   |
| investment-analysis | [skills/finance/investment-analysis/](skills/finance/investment-analysis/) | Analise de investimentos (knowledge-based)                | —                                                                                                                                                   |
| portfolio-review    | [skills/finance/portfolio-review/](skills/finance/portfolio-review/)       | Review de portfolio (knowledge-based)                     | —                                                                                                                                                   |

## Skills — English

| Skill       | Link                                                       | Descricao                                 | Scripts  |
| ----------- | ---------------------------------------------------------- | ----------------------------------------- | -------- |
| english-srs | [skills/english/english-srs/](skills/english/english-srs/) | Spaced repetition system para vocabulario | `srs.py` |

## Skills — Media

| Skill           | Link                                                           | Descricao                               | Scripts                                                       |
| --------------- | -------------------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------- |
| bailian-image   | [skills/media/bailian-image/](skills/media/bailian-image/)     | Geracao de imagem via Alibaba DashScope | `generate_image.py`                                           |
| nano-banana-pro | [skills/media/nano-banana-pro/](skills/media/nano-banana-pro/) | Geracao de imagem via Gemini            | `generate_image.py`                                           |
| ai-video-gen    | [skills/media/ai-video-gen/](skills/media/ai-video-gen/)       | Producao de video com voiceover         | `generate_video.py`, `add_voiceover.py`, `images_to_video.py` |

## Skills — Research

| Skill              | Link                                                                       | Descricao                     | Scripts            |
| ------------------ | -------------------------------------------------------------------------- | ----------------------------- | ------------------ |
| deep-research-pro  | [skills/research/deep-research-pro/](skills/research/deep-research-pro/)   | Pesquisa profunda multi-fonte | —                  |
| bailian-web-search | [skills/research/bailian-web-search/](skills/research/bailian-web-search/) | Busca web via Bailian MCP     | `mcp-websearch.sh` |
| arxiv-cli-tools    | [skills/research/arxiv-cli-tools/](skills/research/arxiv-cli-tools/)       | Busca de papers no arXiv      | —                  |

## Skills — Planning

| Skill               | Link                                                                         | Descricao                              | Scripts |
| ------------------- | ---------------------------------------------------------------------------- | -------------------------------------- | ------- |
| brainstorming       | [skills/planning/brainstorming/](skills/planning/brainstorming/)             | Framework de brainstorming estruturado | —       |
| writing-plans       | [skills/planning/writing-plans/](skills/planning/writing-plans/)             | Escrita de planos de implementacao     | —       |
| excalidraw          | [skills/planning/excalidraw/](skills/planning/excalidraw/)                   | Geracao de diagramas Excalidraw        | —       |
| excalidraw-obsidian | [skills/planning/excalidraw-obsidian/](skills/planning/excalidraw-obsidian/) | Integração Excalidraw + Obsidian       | —       |

## Skills — Automation

| Skill           | Link                                                                     | Descricao                                      | Scripts                                 |
| --------------- | ------------------------------------------------------------------------ | ---------------------------------------------- | --------------------------------------- |
| ai-daily-digest | [skills/automation/ai-daily-digest/](skills/automation/ai-daily-digest/) | Curadoria diaria de noticias AI (Miniflux RSS) | `fetch_miniflux.py`, `collect_feeds.py` |

## Scripts — Harness

| Script               | Link                                                                         | Descricao                           |
| -------------------- | ---------------------------------------------------------------------------- | ----------------------------------- |
| harness-plan.sh      | [scripts/harness/harness-plan.sh](scripts/harness/harness-plan.sh)           | Gera prd.json via Claude Code       |
| harness-loop.sh      | [scripts/harness/harness-loop.sh](scripts/harness/harness-loop.sh)           | Loop de execucao (preflight + run)  |
| harness-review.sh    | [scripts/harness/harness-review.sh](scripts/harness/harness-review.sh)       | Review automatico (Gate 1 + Gate 2) |
| harness-status.sh    | [scripts/harness/harness-status.sh](scripts/harness/harness-status.sh)       | Status de projetos                  |
| harness-stop.sh      | [scripts/harness/harness-stop.sh](scripts/harness/harness-stop.sh)           | Para execucao                       |
| harness-resume.sh    | [scripts/harness/harness-resume.sh](scripts/harness/harness-resume.sh)       | Retoma execucao                     |
| harness-notify.sh    | [scripts/harness/harness-notify.sh](scripts/harness/harness-notify.sh)       | Notificacao Telegram/Slack          |
| harness-show-plan.sh | [scripts/harness/harness-show-plan.sh](scripts/harness/harness-show-plan.sh) | Mostra plano formatado              |
| common.sh            | [scripts/harness/lib/common.sh](scripts/harness/lib/common.sh)               | Funcoes compartilhadas              |
| topo-sort.py         | [scripts/harness/lib/topo-sort.py](scripts/harness/lib/topo-sort.py)         | Ordenacao topologica                |

## Scripts — Server

| Script          | Link                                                             | Descricao                          |
| --------------- | ---------------------------------------------------------------- | ---------------------------------- |
| status.sh       | [scripts/server/status.sh](scripts/server/status.sh)             | Health check completo              |
| backup.sh       | [scripts/server/backup.sh](scripts/server/backup.sh)             | Backup Postgres + Redis + OpenClaw |
| deploy.sh       | [scripts/server/deploy.sh](scripts/server/deploy.sh)             | Deploy de projetos                 |
| api-spending.sh | [scripts/server/api-spending.sh](scripts/server/api-spending.sh) | Relatorio de gastos com APIs       |

## Scripts — Utilities

| Script             | Link                                                                         | Descricao                                |
| ------------------ | ---------------------------------------------------------------------------- | ---------------------------------------- |
| migrate.sh         | [scripts/utilities/migrate.sh](scripts/utilities/migrate.sh)                 | Migra assets do sistema live para o repo |
| validate.sh        | [scripts/utilities/validate.sh](scripts/utilities/validate.sh)               | Valida portabilidade                     |
| install.sh         | [scripts/utilities/install.sh](scripts/utilities/install.sh)                 | Instala assets em ferramentas alvo       |
| pre-commit-hook.sh | [scripts/utilities/pre-commit-hook.sh](scripts/utilities/pre-commit-hook.sh) | Bloqueia commits com secrets             |

## Configs

| Config              | Link                                                                               | Ferramenta  | Descricao                  |
| ------------------- | ---------------------------------------------------------------------------------- | ----------- | -------------------------- |
| CLAUDE.md           | [configs/claude-code/CLAUDE.md](configs/claude-code/CLAUDE.md)                     | Claude Code | Instrucoes globais         |
| server-CLAUDE.md    | [configs/claude-code/server-CLAUDE.md](configs/claude-code/server-CLAUDE.md)       | Claude Code | Instrucoes do servidor     |
| settings.json       | [configs/claude-code/settings.json](configs/claude-code/settings.json)             | Claude Code | Permissoes, hooks, plugins |
| settings.local.json | [configs/claude-code/settings.local.json](configs/claude-code/settings.local.json) | Claude Code | Overrides locais           |

## Cron Jobs

| Job                        | Schedule                | Agente        | Link                             |
| -------------------------- | ----------------------- | ------------- | -------------------------------- |
| Relatorio Matinal          | `30 7 * * *`            | main          | [cron/jobs.json](cron/jobs.json) |
| AI Daily Digest 8h         | `0 8 * * *`             | main          | [cron/jobs.json](cron/jobs.json) |
| AI Daily Digest 12h        | `0 12 * * *`            | main          | [cron/jobs.json](cron/jobs.json) |
| AI Daily Digest 18h        | `0 18 * * *`            | main          | [cron/jobs.json](cron/jobs.json) |
| Daily Review               | `30 20 * * *`           | health-coach  | [cron/jobs.json](cron/jobs.json) |
| English Wake-up            | `30 6 * * 1-5`          | english-tutor | [cron/jobs.json](cron/jobs.json) |
| English Micro-dose Lunch   | `30 12 * * 1-5`         | english-tutor | [cron/jobs.json](cron/jobs.json) |
| English Micro-dose Evening | `0 18 * * 1-5`          | english-tutor | [cron/jobs.json](cron/jobs.json) |
| English Daily Vocab        | `0 21 * * *`            | english-tutor | [cron/jobs.json](cron/jobs.json) |
| English Weekend Casual     | `0 10 * * 6`            | english-tutor | [cron/jobs.json](cron/jobs.json) |
| API Spending Semanal       | `0 20 * * 0`            | main          | [cron/jobs.json](cron/jobs.json) |
| API Spending Diario        | `0 21 * * *` (disabled) | main          | [cron/jobs.json](cron/jobs.json) |
