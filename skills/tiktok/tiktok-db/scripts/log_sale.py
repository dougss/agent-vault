#!/usr/bin/env python3
"""Registra venda no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, sql_escape


def find_video_by_title(title):
    """Busca video por titulo parcial."""
    escaped = sql_escape(title)
    result = run_sql(f"SELECT id FROM videos WHERE title ILIKE '%{escaped}%' ORDER BY posted_at DESC LIMIT 1;")
    if "error" not in result and result["output"]:
        return result["output"].strip()
    return None


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_sale.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    product_name = sql_escape(data["product_name"])
    order_amount = data.get("order_amount", 0)
    commission_amount = data.get("commission_amount", 0)
    commission_status = sql_escape(data.get("commission_status", "pending"))
    order_status = sql_escape(data.get("order_status", "completed"))
    source = sql_escape(data.get("source", "manual"))
    tiktok_order_id = data.get("tiktok_order_id")

    video_id = data.get("video_id")
    if not video_id and data.get("video_title"):
        video_id = find_video_by_title(data["video_title"])

    video_id_sql = f"'{video_id}'" if video_id else "NULL"
    order_id_sql = f"'{sql_escape(tiktok_order_id)}'" if tiktok_order_id else "NULL"

    sql = f"""
    INSERT INTO sales (tiktok_order_id, video_id, product_name, order_amount, commission_amount, commission_status, order_status, source)
    VALUES ({order_id_sql}, {video_id_sql}, '{product_name}', {order_amount}, {commission_amount}, '{commission_status}', '{order_status}', '{source}')
    RETURNING id;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    today_result = run_sql("SELECT COUNT(*), COALESCE(SUM(commission_amount), 0) FROM sales WHERE sold_at::date = CURRENT_DATE;")
    today_sales, today_commission = 0, 0
    if "error" not in today_result and today_result["output"]:
        parts = today_result["output"].split("|")
        today_sales = int(parts[0]) if parts[0] else 0
        today_commission = float(parts[1]) if len(parts) > 1 and parts[1] else 0

    print(json.dumps({
        "success": True,
        "product": data["product_name"],
        "commission": commission_amount,
        "today_total_sales": today_sales,
        "today_total_commission": round(today_commission, 2)
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
