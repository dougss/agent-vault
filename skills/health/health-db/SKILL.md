---
name: health-db
description: Persiste dados de saude (refeicoes, treinos, medidas) no PostgreSQL e consulta historico
metadata:
  openclaw:
    requires:
      bins: [python3, docker]
---

# Health Database Logger

Persiste dados de saude no PostgreSQL compartilhado (banco `life_os`, tabelas ja existentes do Life OS).
Usado apos aprovacao do usuario no daily review das 20:30.

## Scripts disponiveis

### log_meal.py — Registrar refeicao

**meal_type validos:** breakfast, lunch, dinner, snack, pre_workout, post_workout

```bash
python3 scripts/log_meal.py '{
  "meal_type": "breakfast",
  "description": "2 fatias pao integral, 20g requeijao, 4 ovos",
  "calories": 469,
  "protein_g": 32,
  "carbs_g": 26.5,
  "fat_g": 24.2,
  "logged_at": "2026-03-07T08:00:00"
}'
```

### log_workout.py — Registrar treino
```bash
python3 scripts/log_workout.py '{
  "title": "Push 1",
  "workout_type": "strength",
  "duration_minutes": 80,
  "started_at": "2026-03-07T06:00:00",
  "exercises": [
    {"name": "Supino reto com halter", "sets": [{"reps": 8, "weight_kg": 50}, {"reps": 6, "weight_kg": 50}]},
    {"name": "Desenvolvimento", "sets": [{"reps": 10, "weight_kg": 25}, {"reps": 10, "weight_kg": 25}]}
  ]
}'
```

### log_body.py — Registrar medidas corporais
```bash
python3 scripts/log_body.py '{
  "weight_kg": 99.2,
  "body_fat_pct": null,
  "waist_cm": 100.5,
  "notes": "pos-cafe, antes treino"
}'
```

### query_summary.py — Consultar historico
```bash
python3 scripts/query_summary.py '{"type": "weekly", "days": 7}'
python3 scripts/query_summary.py '{"type": "nutrition", "days": 7}'
python3 scripts/query_summary.py '{"type": "body_trend", "days": 30}'
python3 scripts/query_summary.py '{"type": "workout_volume", "days": 14}'
```

## Quando usar

- **NAO use em tempo real** — dados sao acumulados na memoria/Obsidian durante o dia
- **Use no daily review** — apos aprovacao do usuario, persista os dados aprovados
- **Use para consultas** — "como foi minha semana?", "tendencia de peso", etc.

## Conexao

PostgreSQL via docker exec no container `postgres`, banco `life_os`, user `life_os`.
Senha: via `~/.openclaw/secrets/.env` (LIFE_OS_DB_PASS).

## Mapeamento de refeicoes

| Portugues | meal_type DB |
|-----------|-------------|
| cafe / cafe da manha | breakfast |
| almoco | lunch |
| jantar | dinner |
| lanche | snack |
| pre-treino | pre_workout |
| pos-treino | post_workout |
