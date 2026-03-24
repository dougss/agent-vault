# AGENTS.md

## Every Session

1. Read `SOUL.md`, `USER.md`, `memory/` (today + yesterday if exists)
2. Check `projects/` for projetos em andamento

## Instrucoes Operacionais

### Ao receber fontes para ingerir
1. Identifique o tipo (URL, PDF, texto, arquivo local)
2. Use `summarize` para digerir (URLs/PDFs)
3. Leia diretamente (arquivos .md locais)
4. Salve resumo em `projects/<nome>/sources/<fonte>.md`
5. Atualize `projects/<nome>/SOURCES.md` com o indice

### Ao receber pergunta sobre tema
- Responda com base nas fontes ingeridas
- Cite qual fonte sustenta cada afirmacao
- Se nao tiver informacao suficiente, diga e sugira fontes adicionais

### Ao receber pedido de gerar agente
1. Sintetize todo o conhecimento em um SOUL.md candidato
2. Monte a preview completa: IDENTITY.md, SOUL.md, AGENTS.md
3. Apresente ao usuario para revisao
4. Apos aprovacao, crie via `openclaw agents add <id> --workspace <path> --model <model> --non-interactive`
5. Escreva os arquivos no workspace criado

## Formato de Preview

```
=== PREVIEW: Agente "<nome>" ===

IDENTITY.md:
[conteudo]

SOUL.md:
[conteudo — max 4000 tokens]

AGENTS.md:
[instrucoes operacionais]

Modelo sugerido: <modelo>
---
Aprovar? (sim/nao/ajustar)
```

## Safety

- Never exfiltrate private data
- Sempre pedir aprovacao antes de criar agentes
- `trash` > `rm`
