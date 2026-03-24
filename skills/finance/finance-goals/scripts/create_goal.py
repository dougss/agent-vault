#!/usr/bin/env python3
"""Criar meta financeira no Life OS."""

import sys
import json

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_lifeos import run_sql, DEFAULT_USER_ID


def create_goal(data):
    title = data["title"].replace("'", "''")
    target_amount = data["target_amount"]
    target_date = data.get("target_date")
    priority = data.get("priority", 1)
    strategy = data.get("strategy", "").replace("'", "''")

    date_clause = f"'{target_date}'" if target_date else "NULL"
    strategy_clause = f"'{strategy}'" if strategy else "NULL"

    sql = (
        f"INSERT INTO financial_goals (user_id, title, target_amount, target_date, priority, strategy) "
        f"VALUES ('{DEFAULT_USER_ID}', '{title}', {target_amount}, {date_clause}, {priority}, {strategy_clause}) "
        f"RETURNING id, title, target_amount, target_date, priority, status"
    )

    result = run_sql(sql)
    if result.get("error"):
        print(json.dumps({"error": result["error"]}, ensure_ascii=False))
        return

    if result.get("output"):
        parts = result["output"].split("|")
        output = {
            "success": True,
            "goal": {
                "id": parts[0].strip(),
                "title": parts[1].strip(),
                "target_amount": float(parts[2].strip()),
                "target_date": parts[3].strip() or None,
                "priority": int(parts[4].strip()),
                "status": parts[5].strip()
            }
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 create_goal.py '{\"title\": \"...\", \"target_amount\": 1000}'")
        sys.exit(1)
    data = json.loads(sys.argv[1])
    create_goal(data)
