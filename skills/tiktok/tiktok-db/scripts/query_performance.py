#!/usr/bin/env python3
"""Consulta performance de videos no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql


QUERIES = {
    "summary": """
        SELECT
            COUNT(DISTINCT v.id) as total_videos,
            ROUND(AVG(vm.views)) as avg_views,
            ROUND(AVG(CASE WHEN vm.views > 0 THEN (vm.likes + vm.comments + vm.shares + vm.saves)::NUMERIC / vm.views * 100 ELSE 0 END), 2) as avg_engagement_pct,
            COALESCE(SUM(s.cnt), 0) as total_sales,
            COALESCE(SUM(s.commission), 0) as total_commission
        FROM videos v
        LEFT JOIN LATERAL (
            SELECT * FROM video_metrics WHERE video_id = v.id ORDER BY captured_at DESC LIMIT 1
        ) vm ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as cnt, SUM(commission_amount) as commission FROM sales WHERE video_id = v.id
        ) s ON TRUE
        WHERE v.posted_at > NOW() - INTERVAL '{days} days';
    """,
    "top_videos": """
        SELECT v.title, v.format, vm.views, vm.likes,
            CASE WHEN vm.views > 0 THEN ROUND((vm.likes + vm.comments + vm.shares + vm.saves)::NUMERIC / vm.views * 100, 2) ELSE 0 END as engagement_pct,
            COALESCE(s.cnt, 0) as sales
        FROM videos v
        LEFT JOIN LATERAL (
            SELECT * FROM video_metrics WHERE video_id = v.id ORDER BY captured_at DESC LIMIT 1
        ) vm ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as cnt FROM sales WHERE video_id = v.id
        ) s ON TRUE
        WHERE v.posted_at > NOW() - INTERVAL '{days} days'
        ORDER BY vm.views DESC NULLS LAST
        LIMIT {limit};
    """,
    "by_format": """
        SELECT v.format, COUNT(*) as videos,
            ROUND(AVG(vm.views)) as avg_views,
            ROUND(AVG(CASE WHEN vm.views > 0 THEN (vm.likes + vm.comments + vm.shares + vm.saves)::NUMERIC / vm.views * 100 ELSE 0 END), 2) as avg_engagement_pct,
            COALESCE(SUM(s.cnt), 0) as total_sales
        FROM videos v
        LEFT JOIN LATERAL (
            SELECT * FROM video_metrics WHERE video_id = v.id ORDER BY captured_at DESC LIMIT 1
        ) vm ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as cnt FROM sales WHERE video_id = v.id
        ) s ON TRUE
        WHERE v.posted_at > NOW() - INTERVAL '{days} days'
        GROUP BY v.format
        ORDER BY avg_views DESC;
    """,
    "by_product": """
        SELECT unnest(v.products) as product, COUNT(*) as videos,
            ROUND(AVG(vm.views)) as avg_views,
            COALESCE(SUM(s.cnt), 0) as total_sales
        FROM videos v
        LEFT JOIN LATERAL (
            SELECT * FROM video_metrics WHERE video_id = v.id ORDER BY captured_at DESC LIMIT 1
        ) vm ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as cnt FROM sales WHERE video_id = v.id
        ) s ON TRUE
        WHERE v.posted_at > NOW() - INTERVAL '{days} days'
        GROUP BY product
        ORDER BY total_sales DESC;
    """,
    "daily_trend": """
        SELECT v.posted_at::date as day, COUNT(*) as videos,
            ROUND(AVG(vm.views)) as avg_views,
            COALESCE(SUM(s.cnt), 0) as sales
        FROM videos v
        LEFT JOIN LATERAL (
            SELECT * FROM video_metrics WHERE video_id = v.id ORDER BY captured_at DESC LIMIT 1
        ) vm ON TRUE
        LEFT JOIN LATERAL (
            SELECT COUNT(*) as cnt FROM sales WHERE video_id = v.id
        ) s ON TRUE
        WHERE v.posted_at > NOW() - INTERVAL '{days} days'
        GROUP BY day
        ORDER BY day DESC;
    """
}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: query_performance.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])
    query_type = data.get("type", "summary")
    days = data.get("days", 7)
    limit = data.get("limit", 10)

    if query_type not in QUERIES:
        print(json.dumps({"error": f"Tipo invalido: {query_type}. Validos: {list(QUERIES.keys())}"}))
        sys.exit(1)

    sql = QUERIES[query_type].format(days=days, limit=limit)
    result = run_sql(sql)

    if "error" in result:
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    print(json.dumps({"type": query_type, "days": days, "data": result["output"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
