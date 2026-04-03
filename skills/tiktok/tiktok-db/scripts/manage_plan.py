#!/usr/bin/env python3
"""Gerencia plano de fases e tarefas no PostgreSQL."""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import run_sql, sql_escape


def get_active_phase():
    result = run_sql("""
    SELECT id, name, goal, metrics_target, start_date, end_date, status
    FROM plan_phases WHERE status = 'active'
    ORDER BY start_date LIMIT 1;
    """)
    return result


def get_today_tasks():
    result = run_sql("""
    SELECT pt.id, pt.day_number, pt.task, pt.type, pt.completed, pp.name as phase_name
    FROM plan_tasks pt
    JOIN plan_phases pp ON pp.id = pt.phase_id
    WHERE pt.date = CURRENT_DATE
    ORDER BY pt.day_number;
    """)
    return result


def complete_task(task_id):
    result = run_sql(f"UPDATE plan_tasks SET completed = TRUE WHERE id = '{sql_escape(task_id)}' RETURNING id;")
    return result


def create_phase(data):
    name = sql_escape(data["name"])
    goal = sql_escape(data.get("goal", ""))
    start_date = data["start_date"]
    end_date = data["end_date"]
    metrics_target = json.dumps(data.get("metrics_target", {}))

    result = run_sql(f"""
    INSERT INTO plan_phases (name, goal, metrics_target, start_date, end_date, status)
    VALUES ('{name}', '{goal}', '{metrics_target}', '{start_date}', '{end_date}', 'active')
    RETURNING id;
    """)
    return result


def add_tasks(data):
    phase_id = sql_escape(data["phase_id"])
    tasks = data["tasks"]
    values = []
    for t in tasks:
        task_text = sql_escape(t["task"])
        task_type = sql_escape(t.get("type", "video"))
        day = t.get("day_number", 1)
        date = t.get("date", "CURRENT_DATE")
        values.append(f"('{phase_id}', {day}, '{date}', '{task_text}', '{task_type}')")

    sql = f"INSERT INTO plan_tasks (phase_id, day_number, date, task, type) VALUES {','.join(values)} RETURNING id;"
    return run_sql(sql)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Uso: manage_plan.py '{...}'"}))
        sys.exit(1)

    data = json.loads(sys.argv[1])
    action = data.get("action")

    if action == "get_active":
        result = get_active_phase()
    elif action == "get_today_tasks":
        result = get_today_tasks()
    elif action == "complete_task":
        result = complete_task(data["task_id"])
    elif action == "create_phase":
        result = create_phase(data)
    elif action == "add_tasks":
        result = add_tasks(data)
    else:
        result = {"error": f"Acao invalida: {action}"}

    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
