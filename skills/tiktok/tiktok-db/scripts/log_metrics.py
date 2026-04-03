#!/usr/bin/env python3
"""Registra metricas de video no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, sql_escape


def find_video(identifier):
    """Encontra video por titulo (busca parcial) ou tiktok_video_id."""
    escaped = sql_escape(identifier)
    result = run_sql(f"SELECT id, title FROM videos WHERE tiktok_video_id = '{escaped}' LIMIT 1;")
    if "error" not in result and result["output"]:
        parts = result["output"].split("|")
        return parts[0], parts[1]
    result = run_sql(f"SELECT id, title FROM videos WHERE title ILIKE '%{escaped}%' ORDER BY posted_at DESC LIMIT 1;")
    if "error" not in result and result["output"]:
        parts = result["output"].split("|")
        return parts[0], parts[1]
    return None, None


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_metrics.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    video_id = data.get("video_id")
    if not video_id:
        identifier = data.get("video_title") or data.get("tiktok_video_id", "")
        video_id, video_title = find_video(identifier)
        if not video_id:
            print(json.dumps({"error": f"Video nao encontrado: {identifier}"}, ensure_ascii=False))
            sys.exit(1)

    views = data.get("views", 0)
    likes = data.get("likes", 0)
    comments = data.get("comments", 0)
    shares = data.get("shares", 0)
    saves = data.get("saves", 0)
    source = sql_escape(data.get("source", "manual"))

    sql = f"""
    INSERT INTO video_metrics (video_id, source, views, likes, comments, shares, saves)
    VALUES ('{video_id}', '{source}', {views}, {likes}, {comments}, {shares}, {saves})
    RETURNING id;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    avg_result = run_sql("""
    SELECT ROUND(AVG(views)) as avg_views, ROUND(AVG(likes)) as avg_likes
    FROM video_metrics
    WHERE captured_at > NOW() - INTERVAL '7 days';
    """)

    avg_views, avg_likes = 0, 0
    if "error" not in avg_result and avg_result["output"]:
        parts = avg_result["output"].split("|")
        avg_views = int(parts[0]) if parts[0] else 0
        avg_likes = int(parts[1]) if parts[1] and len(parts) > 1 else 0

    views_diff = ((views - avg_views) / avg_views * 100) if avg_views > 0 else 0
    engagement = (likes + comments + shares + saves) / views * 100 if views > 0 else 0

    print(json.dumps({
        "success": True,
        "video_id": video_id,
        "views": views,
        "engagement_rate": round(engagement, 2),
        "avg_views_7d": avg_views,
        "vs_avg_pct": round(views_diff, 1)
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
