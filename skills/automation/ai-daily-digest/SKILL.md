---
name: ai-daily-digest
description: "Coleta notícias diárias de AI via Miniflux (RSS reader), filtra por relevância pessoal e entrega um digest curado via Telegram. Use quando o cron disparar a tarefa de digest diário."
metadata:
  openclaw:
    requires:
      bins: [python3]
---

# AI Daily Digest

Newsletter diária sobre AI, curada e filtrada por relevância pessoal.

## Como executar

### 1. Coletar itens do Miniflux

```bash
python3 scripts/fetch_miniflux.py
```

O script consulta a API do Miniflux (`http://127.0.0.1:8081`) para obter entries não lidos e retorna JSON no stdout.

**Fallback:** Se o Miniflux estiver indisponível (erro de conexão), use o script legado:

```bash
python3 scripts/collect_feeds.py
```

### 2. Ler o perfil do destinatário

Leia o arquivo `references/user-profile.md` para entender o contexto de filtragem e priorização.

### 3. Analisar e gerar o digest

Com base nos itens coletados e no perfil do destinatário:

- **Organize em seções:**
  - 📦 **Release Notes** — atualizações de Claude, Claude Code, Cursor, Anthropic SDKs, OpenClaw, Alibaba Cloud/Qwen. SEMPRE priorizar esta seção — se houver release note, ela aparece primeiro
  - 🔧 **Ferramentas que uso** — Cursor, Claude, Claude Code, MCP servers, dev tools
  - 🧠 **Novos modelos** — lançamentos, benchmarks, comparações
  - 🛠 **Open-source / Self-hosted** — projetos que rodam em Docker/Mac Mini
  - 🔥 **Tendências** — movimentos gerais do ecossistema AI

- **Regras de curadoria:**
  - Máximo 15 itens total, priorizando fontes "high priority"
  - Cada item: **título** (com link), 1-2 frases de por que é relevante **pro destinatário**
  - Se algo é breaking (novo modelo Claude, breaking change Cursor, etc), marcar com ⚡
  - Se não houver itens suficientes em uma seção, omita a seção
  - Finalize com **💡 Dica do dia** — algo acionável (ferramenta, config, workflow)

- **Formato:** Tudo em português brasileiro, markdown compatível com Telegram

### 4. Enviar via Telegram

Envie o digest formatado como mensagem Telegram usando a ferramenta de mensagem do OpenClaw.

Formato do header:

```
📰 AI Daily Digest — DD/MM/YYYY

[conteúdo das seções]

💡 Dica do dia: [dica acionável]
```

### 5. Marcar como lidos no Miniflux

Após enviar o digest com sucesso, marque os entries como lidos:

```bash
cat data/last_entry_ids.json | python3 scripts/fetch_miniflux.py --mark-read
```

Isso evita que os mesmos itens apareçam no digest do dia seguinte.
