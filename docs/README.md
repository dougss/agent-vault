# Docs

Documentacao adicional sobre o ecossistema agentico.

## Arquivos planejados

- Guia de portabilidade entre ferramentas
- Guia de criacao de novos agentes
- Guia de criacao de novos skills
- Historico de decisoes arquiteturais

## Ecossistema no servidor

- **OpenClaw**: runtime dos bots; estado em `~/.openclaw/`.
- **Harness v3**: `~/server/apps/harness` — orquestrador; scripts CLI espelhados em `agent-vault/scripts/harness/` via migrate.
- **Nexus**: `~/server/apps/nexus` — skills Markdown + MCP para Claude Code; não substitui skills OpenClaw.
