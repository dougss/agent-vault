#!/usr/bin/env python3
"""Consulta learnings ativos no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, sql_escape


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: query_learnings.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])
    min_confidence = data.get("min_confidence", 0.5)
    category = data.get("category")

    where = f"active = TRUE AND confidence >= {min_confidence}"
    if category:
        where += f" AND category = '{sql_escape(category)}'"

    sql = f"""
    SELECT category, insight, confidence, evidence_count, updated_at::date
    FROM learnings
    WHERE {where}
    ORDER BY confidence DESC, updated_at DESC
    LIMIT 20;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(1)

    print(json.dumps({"learnings": result["output"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
