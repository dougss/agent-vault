# OpenClaw — referência (sem segredos)

A configuração **ativa** do OpenClaw fica em `~/.openclaw/openclaw.json` (e credenciais em `~/.openclaw/credentials/`, `~/.openclaw/secrets/.env`). **Não** versione esses arquivos.

Para alterar opções suportadas, use o CLI:

```bash
openclaw config set <key> <value>
openclaw config get <key>
```

## Chaves válidas (referência)

Testadas e documentadas no ambiente do servidor:

- `gateway.bind` → `"loopback"`
- `gateway.port` → `18789`
- `gateway.auth.mode` → `"token"`
- `gateway.auth.token` → `<token>`
- `agents.defaults.elevatedDefault` → `"full"` | `"on"` | `"ask"` | `"off"`
- `agents.defaults.model.primary` → modelo primário (ex.: Anthropic)
- `tools.deny` → lista (ex.: `["browser", "canvas"]`)
- `tools.elevated.enabled` → `true` / `false`
- `tools.elevated.allowFrom.telegram` → lista de IDs
- `skills.entries.memory.enabled` → `true` / `false`
- `logging.level` → `"info"` | `"debug"` | `"warn"` | `"error"`
- `logging.file` → caminho do arquivo de log
- `logging.redactSensitive` → `"tools"` | `"all"` | `"none"`
- `diagnostics.enabled` → `true` / `false`
- `channels.telegram.dmPolicy` → `"pairing"` | `"allowlist"` | `"open"`
- `channels.telegram.groupPolicy` → `"allowlist"`

Evite inventar chaves que não existem na sua versão do OpenClaw; prefira `openclaw config` e a documentação oficial da release.

## Relação com este repositório

- **Agentes e skills:** o fluxo canônico é `scripts/utilities/migrate.sh` (live → vault) e, na outra direção, `scripts/utilities/install.sh openclaw` (vault → workspaces), conforme o README na raiz.
- **Cron:** export em `cron/jobs.json` é um snapshot; a fonte de verdade em runtime é o OpenClaw no Mac.
