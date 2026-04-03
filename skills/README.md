# Skills

Habilidades reutilizaveis para agentes de IA. Cada skill e uma pasta contendo instrucoes (SKILL.md) e opcionalmente scripts executaveis.

## Estrutura de um skill

```
skill-name/
├── SKILL.md          # Instrucoes, triggers, formato de resposta
├── scripts/          # Scripts executaveis (Python, bash)
│   └── main.py
├── references/       # Material de referencia (raro)
├── _meta.json        # Metadados de instalacao OpenClaw (raro)
└── requirements.txt  # Dependencias Python (se aplicavel)
```

## Categorias

| Categoria     | Skills | Descricao                                         |
| ------------- | ------ | ------------------------------------------------- |
| `shared/`     | 10+    | Skills genericos usados por multiplos agentes       |
| `health/`     | 2      | Nutricao (TACO), treino, medidas corporais        |
| `finance/`    | 4      | Queries de banco, metas, analise de investimentos |
| `english/`    | 1      | Spaced repetition para vocabulario                |
| `media/`      | 3      | Geracao de imagem (Bailian, Gemini) e video       |
| `research/`   | 3      | Pesquisa web, arXiv, deep research                |
| `planning/`   | 4      | Brainstorming, planos, diagramas Excalidraw       |
| `automation/` | 1      | AI Daily Digest (RSS curadoria)                   |
| `tiktok/`       | 2      | TikTok Shop, métricas, DB (tiktok-coach)          |

## Como usar em outra ferramenta

1. Leia o `SKILL.md` — contem as instrucoes que o agente segue
2. Copie os `scripts/` para um local acessivel
3. Adapte os paths nos scripts (use variaveis de ambiente)
4. Injete as instrucoes do SKILL.md no contexto do seu agente

## Dependencias comuns

- Python 3.11+
- `psycopg2-binary` (skills de banco)
- `requests` (skills de API)
- `ffmpeg` (skills de video)
