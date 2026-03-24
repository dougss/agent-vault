#!/usr/bin/env python3
"""Registra medidas corporais no PostgreSQL (tabela body_measurements do Life OS)."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, DEFAULT_USER_ID


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_body.py '{...}'"}, ensure_ascii=False))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    weight = data.get("weight_kg", "NULL")
    body_fat = data.get("body_fat_pct", "NULL") or "NULL"
    waist = data.get("waist_cm", "NULL") or "NULL"
    chest = data.get("chest_cm", "NULL") or "NULL"
    arm = data.get("arm_cm", "NULL") or "NULL"
    thigh = data.get("thigh_cm", "NULL") or "NULL"
    notes = data.get("notes", "")
    measured_at = data.get("measured_at", "NOW()")

    if measured_at != "NOW()":
        measured_at = f"'{measured_at}'"

    sql = f"""
    INSERT INTO body_measurements (user_id, weight_kg, body_fat_pct, waist_cm, chest_cm, arm_cm, thigh_cm, notes, measured_at)
    VALUES ('{DEFAULT_USER_ID}', {weight}, {body_fat}, {waist}, {chest}, {arm}, {thigh}, $${notes}$$, {measured_at})
    RETURNING id;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps({"success": False, "error": result["error"]}, ensure_ascii=False))
        sys.exit(1)

    print(json.dumps({
        "success": True,
        "id": result["output"],
        "weight_kg": weight,
        "body_fat_pct": body_fat
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
