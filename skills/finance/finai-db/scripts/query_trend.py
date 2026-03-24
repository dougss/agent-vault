#!/usr/bin/env python3
"""Tendencia de gastos/receitas nos ultimos N meses."""

import sys
import json
import argparse
from datetime import datetime, date

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_trend(months=6):
    user_id = get_finai_user_id()

    now = datetime.now()

    # Calcula data de inicio
    start_month = now.month - months
    start_year = now.year
    while start_month <= 0:
        start_month += 12
        start_year -= 1
    start_date = f"{start_year}-{start_month:02d}-01"

    # Despesas por mes
    exp_sql = (
        f"SELECT TO_CHAR(purchase_date, 'YYYY-MM'), COALESCE(SUM(value), 0) "
        f"FROM transactions "
        f"WHERE user_id = '{user_id}' "
        f"AND purchase_date >= '{start_date}' "
        f"GROUP BY TO_CHAR(purchase_date, 'YYYY-MM') "
        f"ORDER BY 1"
    )
    exp_result = run_sql(exp_sql)

    expenses_map = {}
    if exp_result.get("output"):
        for line in exp_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                expenses_map[parts[0].strip()] = float(parts[1].strip() or "0")

    # Receitas por mes
    rev_sql = (
        f"SELECT TO_CHAR(COALESCE(received_date, due_date), 'YYYY-MM'), COALESCE(SUM(amount), 0) "
        f"FROM revenues "
        f"WHERE user_id = '{user_id}' "
        f"AND COALESCE(received_date, due_date) >= '{start_date}' "
        f"GROUP BY TO_CHAR(COALESCE(received_date, due_date), 'YYYY-MM') "
        f"ORDER BY 1"
    )
    rev_result = run_sql(rev_sql)

    revenues_map = {}
    if rev_result.get("output"):
        for line in rev_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                revenues_map[parts[0].strip()] = float(parts[1].strip() or "0")

    # Monta lista de meses
    all_months = sorted(set(list(expenses_map.keys()) + list(revenues_map.keys())))

    result_months = []
    for m in all_months:
        rev = revenues_map.get(m, 0)
        exp = expenses_map.get(m, 0)
        balance = rev - exp
        sr = round((balance / rev * 100), 1) if rev > 0 else 0
        result_months.append({
            "month": m,
            "revenues": round(rev, 2),
            "expenses": round(exp, 2),
            "balance": round(balance, 2),
            "savings_rate": sr
        })

    # Media
    if result_months:
        avg_exp = round(sum(m["expenses"] for m in result_months) / len(result_months), 2)
        avg_rev = round(sum(m["revenues"] for m in result_months) / len(result_months), 2)
    else:
        avg_exp = avg_rev = 0

    output = {
        "period": f"{start_date} a {now.strftime('%Y-%m-%d')}",
        "months": result_months,
        "averages": {
            "avg_monthly_expenses": avg_exp,
            "avg_monthly_revenues": avg_rev
        }
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--months", type=int, default=6)
    args = parser.parse_args()
    query_trend(args.months)
