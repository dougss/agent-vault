# Scripts

Scripts de automacao organizados por dominio.

## Categorias

### `harness/`

Sistema de coding autonomo (Harness Engineering). Orquestra Claude Code para implementar tarefas de um PRD automaticamente.

- `harness-plan.sh` — Gera prd.json a partir de descricao
- `harness-loop.sh` — Loop de execucao (preflight + run)
- `harness-review.sh` — Review automatico (tsc + vitest + eslint + LLM)
- `harness-status.sh` — Status de execucao
- `harness-stop.sh` / `harness-resume.sh` — Controle de fluxo
- `harness-notify.sh` — Notificacoes via Telegram/Slack
- `harness-show-plan.sh` — Visualiza plano formatado
- `lib/common.sh` — Funcoes compartilhadas
- `lib/topo-sort.py` — Ordenacao topologica de dependencias
- `templates/` — Templates de AGENTS.md e CLAUDE.md para harness

### `server/`

Scripts de manutencao do servidor Mac Mini.

- `status.sh` — Health check completo
- `backup.sh` — Backup Postgres + Redis + OpenClaw
- `deploy.sh` — Deploy de projetos
- `api-spending.sh` — Relatorio de gastos com APIs

### `utilities/`

Ferramentas do repositorio.

- `migrate.sh` — Copia assets do sistema live para o repo
- `validate.sh` — Valida portabilidade (paths, secrets)
- `install.sh` — Instala assets em ferramentas alvo
- `pre-commit-hook.sh` — Bloqueia commits com secrets
