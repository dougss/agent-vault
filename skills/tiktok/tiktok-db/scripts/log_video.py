#!/usr/bin/env python3
"""Registra video publicado no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, sql_escape


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_video.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    title = sql_escape(data.get("title", ""))
    description = sql_escape(data.get("description", ""))
    fmt = sql_escape(data.get("format", ""))
    hook_type = sql_escape(data.get("hook_type", ""))
    products = data.get("products", [])
    products_sql = "ARRAY[" + ",".join(f"'{sql_escape(p)}'" for p in products) + "]" if products else "'{}'::text[]"
    posted_at = data.get("posted_at", "NOW()")
    tiktok_id = data.get("tiktok_video_id")

    tiktok_id_sql = f"'{sql_escape(tiktok_id)}'" if tiktok_id else "NULL"

    sql = f"""
    INSERT INTO videos (tiktok_video_id, title, description, format, hook_type, products, posted_at)
    VALUES ({tiktok_id_sql}, '{title}', '{description}', '{fmt}', '{hook_type}', {products_sql}, '{posted_at}')
    RETURNING id, title;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    parts = result["output"].split("|")
    print(json.dumps({"success": True, "id": parts[0], "title": parts[1] if len(parts) > 1 else title}, ensure_ascii=False))


if __name__ == "__main__":
    main()
