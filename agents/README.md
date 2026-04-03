# Agents

Definicoes completas de 13 agentes de IA. Cada agente e uma pasta com arquivos Markdown que definem sua personalidade, instrucoes e capacidades.

## Arquivos padrao por agente

| Arquivo        | Proposito                                  | Obrigatorio |
| -------------- | ------------------------------------------ | ----------- |
| `SOUL.md`      | Personalidade, valores, tom de comunicacao | Sim         |
| `AGENTS.md`    | Instrucoes operacionais detalhadas         | Sim         |
| `IDENTITY.md`  | Nome, emoji, descricao curta               | Sim         |
| `TOOLS.md`     | Lista de ferramentas disponiveis           | Sim         |
| `USER.md`      | Perfil do usuario (contexto sobre o dono)  | Sim         |
| `BOOTSTRAP.md` | Instrucoes de inicializacao (raro)         | Nao         |
| `HEARTBEAT.md` | Formato de heartbeat (raro)                | Nao         |

## Origem

Estes arquivos vem dos workspaces do OpenClaw (`~/.openclaw/workspace/` e `~/.openclaw/workspaces/<id>/`).

## Como adaptar para outra ferramenta

**Claude Code:** Combine SOUL.md + AGENTS.md em um `CLAUDE.md` no diretorio do projeto.

**Cursor:** Extraia as instrucoes relevantes para `.cursorrules`.

**Copilot:** Use o conteudo de AGENTS.md como instrucoes customizadas.

## Agentes

- `madclaw/` — Orquestrador principal (MadClaw)
- `english-tutor/` — Kai, professor de ingles
- `health-coach/` — VitaClaw, coach de saude
- `finance-advisor/` — Consultor financeiro
- `researcher/` — Pesquisador multi-fonte
- `planner/` — Planejador estrategico
- `prompt-engineer/` — Engenheiro de prompts
- `knowledge-forge/` — Gerador de conhecimento
- `image-gen/` — Gerador de imagens
- `video-gen/` — Produtor de video
- `task-orchestrator/` — Gerente de tarefas
- `harness-engineer/` — Engenheiro de coding autonomo
- `tiktok-coach/` — TikTok Coach (Liz)
