#!/usr/bin/env python3
"""Registra treino no PostgreSQL (tabelas workouts + workout_sets do Life OS)."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, DEFAULT_USER_ID


def find_or_create_exercise(name):
    """Busca exercicio pelo nome ou cria novo."""
    sql = f"SELECT id FROM exercises WHERE LOWER(name) = LOWER($${name}$$) LIMIT 1;"
    result = run_sql(sql)
    if result.get("output"):
        return result["output"]
    # Cria novo
    sql = f"""
    INSERT INTO exercises (name, exercise_type, primary_muscle_group)
    VALUES ($${name}$$, 'strength', 'other')
    RETURNING id;
    """
    result = run_sql(sql)
    return result.get("output", "")


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: log_workout.py '{...}'"}, ensure_ascii=False))
        sys.exit(1)

    data = json.loads(sys.argv[1])

    title = data.get("title", "Treino")
    workout_type = data.get("workout_type", "strength")
    duration = data.get("duration_minutes", 0)
    started_at = data.get("started_at", "NOW()")
    exercises = data.get("exercises", [])
    notes = data.get("notes", "")

    if started_at != "NOW()":
        started_at = f"'{started_at}'"

    # 1. Cria workout
    sql = f"""
    INSERT INTO workouts (user_id, title, workout_type, started_at, duration_minutes, notes)
    VALUES ('{DEFAULT_USER_ID}', $${title}$$, '{workout_type}', {started_at}, {duration}, $${notes}$$)
    RETURNING id;
    """
    result = run_sql(sql)
    if "error" in result:
        print(json.dumps({"success": False, "error": result["error"]}, ensure_ascii=False))
        sys.exit(1)

    workout_id = result["output"]
    sets_logged = 0

    # 2. Para cada exercicio, cria sets
    for ex_order, exercise in enumerate(exercises, 1):
        ex_name = exercise.get("name", "")
        exercise_id = find_or_create_exercise(ex_name)
        if not exercise_id:
            continue

        for set_order, s in enumerate(exercise.get("sets", []), 1):
            reps = s.get("reps", 0)
            weight = s.get("weight_kg", 0)
            rpe = s.get("rpe", "NULL")
            set_notes = s.get("notes", "")

            sql = f"""
            INSERT INTO workout_sets (workout_id, exercise_id, set_number, reps, weight_kg, rpe, notes)
            VALUES ('{workout_id}', '{exercise_id}', {set_order}, {reps}, {weight}, {rpe}, $${set_notes}$$);
            """
            result = run_sql(sql)
            if "error" not in result:
                sets_logged += 1

    print(json.dumps({
        "success": True,
        "workout_id": workout_id,
        "title": title,
        "exercises_count": len(exercises),
        "sets_logged": sets_logged
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
