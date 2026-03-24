#!/usr/bin/env python3
"""Registra refeicao no PostgreSQL (tabela nutrition_logs do Life OS)."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, DEFAULT_USER_ID


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_meal.py '{...}'"}, ensure_ascii=False))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    meal_type = data.get("meal_type", "other")
    description = data.get("description", "")
    calories = data.get("calories", 0)
    protein_g = data.get("protein_g", 0)
    carbs_g = data.get("carbs_g", 0)
    fat_g = data.get("fat_g", 0)
    logged_at = data.get("logged_at", "NOW()")

    if logged_at != "NOW()":
        logged_at = f"'{logged_at}'"

    sql = f"""
    INSERT INTO nutrition_logs (user_id, meal_type, description, calories, protein_g, carbs_g, fat_g, logged_at)
    VALUES ('{DEFAULT_USER_ID}', '{meal_type}', $${description}$$, {calories}, {protein_g}, {carbs_g}, {fat_g}, {logged_at})
    RETURNING id;
    """

    result = run_sql(sql)
    if "error" in result:
        print(json.dumps({"success": False, "error": result["error"]}, ensure_ascii=False))
        sys.exit(1)

    print(json.dumps({
        "success": True,
        "id": result["output"],
        "meal_type": meal_type,
        "calories": calories,
        "protein_g": protein_g
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
