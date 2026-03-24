#!/usr/bin/env python3
"""Consultar metas financeiras ativas."""

import sys
import json
import argparse

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_lifeos import run_sql, DEFAULT_USER_ID


def query_goals(status="active"):
    sql = (
        f"SELECT id, title, target_amount, current_amount, target_date, "
        f"priority, status, strategy "
        f"FROM financial_goals "
        f"WHERE user_id = '{DEFAULT_USER_ID}' AND status = '{status}' "
        f"ORDER BY priority ASC, target_date ASC NULLS LAST"
    )
    result = run_sql(sql)

    goals = []
    if result.get("output"):
        for line in result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                target = float(parts[2].strip() or "0")
                current = float(parts[3].strip() or "0")
                progress = round((current / target * 100), 1) if target > 0 else 0
                goals.append({
                    "id": parts[0].strip(),
                    "title": parts[1].strip(),
                    "target_amount": round(target, 2),
                    "current_amount": round(current, 2),
                    "progress_pct": progress,
                    "target_date": parts[4].strip() or None,
                    "priority": int(parts[5].strip() or "1"),
                    "status": parts[6].strip(),
                    "strategy": parts[7].strip() or None
                })

    output = {
        "filter": status,
        "count": len(goals),
        "goals": goals
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", default="active")
    args = parser.parse_args()
    query_goals(args.status)
