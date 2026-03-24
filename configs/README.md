# Configs

Configuracoes de ferramentas de IA, sanitizadas e prontas para adaptar.

## Claude Code (`claude-code/`)

- `CLAUDE.md` — Instrucoes globais (user-level)
- `server-CLAUDE.md` — Instrucoes do servidor (project-level)
- `settings.json` — Permissoes, hooks, plugins
- `settings.local.json` — Overrides locais
- `skills/` — Skills customizados do Claude Code

**Para instalar:** `./scripts/utilities/install.sh claude-code`

## OpenClaw (`openclaw/`)

Configuracoes de referencia do OpenClaw. A config real (`openclaw.json`) contem API keys e NAO e versionada. Use `.env.example` como guia.

**Keys validas:** ver lista em `server-CLAUDE.md` secao "Config keys validas".
