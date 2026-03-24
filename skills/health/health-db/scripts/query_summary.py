#!/usr/bin/env python3
"""Consulta historico de saude no PostgreSQL para resumos e tendencias."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, DEFAULT_USER_ID


def query_nutrition(days):
    sql = f"""
    SELECT
        DATE(logged_at) as dia,
        COUNT(*) as refeicoes,
        SUM(calories) as kcal_total,
        SUM(protein_g) as prot_total,
        SUM(carbs_g) as carbs_total,
        SUM(fat_g) as fat_total
    FROM nutrition_logs
    WHERE user_id = '{DEFAULT_USER_ID}'
      AND logged_at >= NOW() - interval '{days} days'
      AND is_active = true
    GROUP BY DATE(logged_at)
    ORDER BY dia DESC;
    """
    return run_sql(sql)


def query_weekly(days):
    sql = f"""
    SELECT 'nutrition' as tipo,
        COUNT(DISTINCT DATE(logged_at)) as dias_registrados,
        ROUND(AVG(daily_kcal)) as avg_kcal,
        ROUND(AVG(daily_prot)) as avg_prot
    FROM (
        SELECT DATE(logged_at) as dt,
            SUM(calories) as daily_kcal,
            SUM(protein_g) as daily_prot
        FROM nutrition_logs
        WHERE user_id = '{DEFAULT_USER_ID}'
          AND logged_at >= NOW() - interval '{days} days'
          AND is_active = true
        GROUP BY DATE(logged_at)
    ) daily
    UNION ALL
    SELECT 'treinos',
        COUNT(*)::numeric,
        ROUND(AVG(duration_minutes)),
        NULL
    FROM workouts
    WHERE user_id = '{DEFAULT_USER_ID}'
      AND started_at >= NOW() - interval '{days} days'
      AND is_active = true;
    """
    return run_sql(sql)


def query_body_trend(days):
    sql = f"""
    SELECT
        DATE(measured_at) as dia,
        weight_kg,
        body_fat_pct,
        waist_cm
    FROM body_measurements
    WHERE user_id = '{DEFAULT_USER_ID}'
      AND measured_at >= NOW() - interval '{days} days'
      AND is_active = true
    ORDER BY measured_at DESC;
    """
    return run_sql(sql)


def query_workout_volume(days):
    sql = f"""
    SELECT
        w.title,
        DATE(w.started_at) as dia,
        w.duration_minutes,
        COUNT(ws.id) as total_sets,
        SUM(ws.reps * ws.weight_kg) as volume_kg
    FROM workouts w
    LEFT JOIN workout_sets ws ON ws.workout_id = w.id
    WHERE w.user_id = '{DEFAULT_USER_ID}'
      AND w.started_at >= NOW() - interval '{days} days'
      AND w.is_active = true
    GROUP BY w.id, w.title, w.started_at, w.duration_minutes
    ORDER BY w.started_at DESC;
    """
    return run_sql(sql)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: query_summary.py '{\"type\": \"weekly\", \"days\": 7}'"}, ensure_ascii=False))
        sys.exit(1)

    data = json.loads(sys.argv[1])
    query_type = data.get("type", "weekly")
    days = data.get("days", 7)

    queries = {
        "weekly": query_weekly,
        "nutrition": query_nutrition,
        "body_trend": query_body_trend,
        "workout_volume": query_workout_volume,
    }

    if query_type not in queries:
        print(json.dumps({"error": f"Tipo invalido. Use: {list(queries.keys())}"}, ensure_ascii=False))
        sys.exit(1)

    result = queries[query_type](days)
    if "error" in result:
        print(json.dumps({"success": False, "error": result["error"]}, ensure_ascii=False))
        sys.exit(1)

    print(json.dumps({
        "success": True,
        "type": query_type,
        "days": days,
        "data": result["output"]
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
