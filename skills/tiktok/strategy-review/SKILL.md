---
name: strategy-review
description: Reavaliacao estrategica profunda via claude -p (Claude Code CLI)
metadata:
  openclaw:
    requires:
      bins: [claude, python3, docker]
---

# Strategy Review

Dispara analise profunda usando Claude Code CLI (`claude -p`) com dados completos do banco.
Retorna diagnostico, ajustes no plano e acoes prioritarias.

## Uso

```bash
bash ~/.openclaw/workspaces/tiktok-coach/skills/strategy-review/scripts/run_review.sh
```

## Triggers

- Manual: usuaria pede reavaliacao
- Cron semanal: domingo 20h
- Anomalia: queda >40% ou subida >200% em views vs media 7d

## Output

O script retorna texto com:

- Diagnostico (o que funciona / o que nao)
- Ajustes recomendados no plano
- Metas atualizadas
- 3 acoes prioritarias imediatas
