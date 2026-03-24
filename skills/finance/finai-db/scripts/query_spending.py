#!/usr/bin/env python3
"""Gastos por categoria com periodo e detalhamento."""

import sys
import json
import argparse
from datetime import datetime

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_spending(category=None, start_date=None, end_date=None):
    user_id = get_finai_user_id()

    now = datetime.now()
    if start_date is None:
        start_date = now.strftime("%Y-%m-01")
    if end_date is None:
        # Ultimo dia do mes atual
        if now.month == 12:
            end_date = f"{now.year}-12-31"
        else:
            from datetime import date
            next_month = date(now.year, now.month + 1, 1)
            last_day = next_month - __import__("datetime").timedelta(days=1)
            end_date = last_day.strftime("%Y-%m-%d")

    where = (
        f"t.user_id = '{user_id}' "
        f"AND t.purchase_date >= '{start_date}' "
        f"AND t.purchase_date <= '{end_date}'"
    )
    if category:
        where += f" AND LOWER(c.name) LIKE LOWER('%{category}%')"

    # Por categoria
    cat_sql = (
        f"SELECT c.name, COALESCE(SUM(t.value), 0), COUNT(t.id) "
        f"FROM transactions t "
        f"LEFT JOIN categories c ON t.category_id = c.id "
        f"WHERE {where} "
        f"GROUP BY c.name ORDER BY SUM(t.value) DESC"
    )
    cat_result = run_sql(cat_sql)

    categories = []
    total = 0.0
    if cat_result.get("output"):
        for line in cat_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                name = parts[0].strip() or "Sem categoria"
                val = float(parts[1].strip() or "0")
                count = int(parts[2].strip() or "0")
                total += val
                categories.append({"name": name, "total": round(val, 2), "count": count})

    # Detalhamento por transacao (top 20)
    detail_where = where
    detail_sql = (
        f"SELECT t.name, t.value, t.purchase_date, c.name "
        f"FROM transactions t "
        f"LEFT JOIN categories c ON t.category_id = c.id "
        f"WHERE {detail_where} "
        f"ORDER BY t.value DESC LIMIT 20"
    )
    detail_result = run_sql(detail_sql)

    transactions = []
    if detail_result.get("output"):
        for line in detail_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                transactions.append({
                    "name": parts[0].strip(),
                    "value": float(parts[1].strip() or "0"),
                    "date": parts[2].strip(),
                    "category": parts[3].strip() or "Sem categoria"
                })

    result = {
        "period": f"{start_date} a {end_date}",
        "filter": category or "todas",
        "total": round(total, 2),
        "categories": categories,
        "top_transactions": transactions
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", default=None)
    parser.add_argument("--start", default=None)
    parser.add_argument("--end", default=None)
    args = parser.parse_args()
    query_spending(args.category, args.start, args.end)
