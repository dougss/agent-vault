---
name: tiktok-db
description: Persiste e consulta dados de videos, metricas, vendas, plano e learnings no PostgreSQL
metadata:
  openclaw:
    requires:
      bins: [python3, docker]
---

# TikTok Database

Acesso ao banco `tiktok_coach` no PostgreSQL compartilhado.

## Scripts disponiveis

### log_video.py — Registrar video publicado

```bash
python3 scripts/log_video.py '{
  "title": "Review BumBum Cream",
  "format": "transformation",
  "hook_type": "before_after",
  "products": ["BumBum Cream"],
  "posted_at": "2026-03-27T18:00:00"
}'
```

Formatos validos: transformation, tutorial, unboxing, grwm, trend, review, pov, comparison, humor, live
Hook types: question, before_after, shock, comparison, storytelling, trending_sound

### log_metrics.py — Registrar metricas de video

```bash
python3 scripts/log_metrics.py '{
  "video_title": "Review BumBum Cream",
  "views": 15000,
  "likes": 890,
  "comments": 67,
  "shares": 34,
  "saves": 156,
  "source": "manual"
}'
```

Pode identificar video por titulo (busca parcial) ou por tiktok_video_id.
Source validos: manual, screenshot, api_sync, scraper

### log_sale.py — Registrar venda

```bash
python3 scripts/log_sale.py '{
  "product_name": "BumBum Cream",
  "order_amount": 89.90,
  "commission_amount": 13.49,
  "video_title": "Review BumBum Cream"
}'
```

### query_performance.py — Consultar performance

```bash
python3 scripts/query_performance.py '{"type": "summary", "days": 7}'
python3 scripts/query_performance.py '{"type": "top_videos", "days": 30, "limit": 10}'
python3 scripts/query_performance.py '{"type": "by_format", "days": 30}'
python3 scripts/query_performance.py '{"type": "by_product", "days": 30}'
python3 scripts/query_performance.py '{"type": "daily_trend", "days": 14}'
```

### query_learnings.py — Consultar learnings ativos

```bash
python3 scripts/query_learnings.py '{"min_confidence": 0.5}'
python3 scripts/query_learnings.py '{"category": "format"}'
```

### manage_plan.py — Gerenciar plano

```bash
python3 scripts/manage_plan.py '{"action": "get_active"}'
python3 scripts/manage_plan.py '{"action": "get_today_tasks"}'
python3 scripts/manage_plan.py '{"action": "complete_task", "task_id": "uuid"}'
python3 scripts/manage_plan.py '{"action": "create_phase", "name": "...", "goal": "...", "start_date": "2026-03-28", "end_date": "2026-04-10", "metrics_target": {"daily_views": 5000}}'
python3 scripts/manage_plan.py '{"action": "add_tasks", "phase_id": "uuid", "tasks": [{"day_number": 1, "date": "2026-03-28", "task": "...", "type": "video"}]}'
```

## Conexao

PostgreSQL via docker exec no container `postgres`, banco `tiktok_coach`, user `tiktok_coach`.
Senha: via `~/.openclaw/secrets/.env` (TIKTOK_COACH_DB_PASS).
