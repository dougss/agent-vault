#!/usr/bin/env python3
"""Resumo financeiro mensal: receitas vs despesas, saldo, savings rate, top categorias."""

import sys
import json
from datetime import datetime

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_monthly(year_month=None):
    user_id = get_finai_user_id()

    if year_month is None:
        year_month = datetime.now().strftime("%Y-%m")

    year, month = year_month.split("-")

    # Receitas do mes
    rev_result = run_sql(
        f"SELECT COALESCE(SUM(amount), 0) FROM revenues "
        f"WHERE user_id = '{user_id}' "
        f"AND EXTRACT(YEAR FROM COALESCE(received_date, due_date)) = {year} "
        f"AND EXTRACT(MONTH FROM COALESCE(received_date, due_date)) = {month}"
    )
    revenues = float(rev_result.get("output", "0") or "0")

    # Despesas do mes (por purchase_date)
    exp_result = run_sql(
        f"SELECT COALESCE(SUM(value), 0) FROM transactions "
        f"WHERE user_id = '{user_id}' "
        f"AND EXTRACT(YEAR FROM purchase_date) = {year} "
        f"AND EXTRACT(MONTH FROM purchase_date) = {month}"
    )
    expenses = float(exp_result.get("output", "0") or "0")

    # Top categorias
    cat_result = run_sql(
        f"SELECT c.name, COALESCE(SUM(t.value), 0) as total "
        f"FROM transactions t "
        f"LEFT JOIN categories c ON t.category_id = c.id "
        f"WHERE t.user_id = '{user_id}' "
        f"AND EXTRACT(YEAR FROM t.purchase_date) = {year} "
        f"AND EXTRACT(MONTH FROM t.purchase_date) = {month} "
        f"GROUP BY c.name ORDER BY total DESC LIMIT 10"
    )

    top_categories = []
    if cat_result.get("output"):
        for line in cat_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                name = parts[0].strip() or "Sem categoria"
                total = float(parts[1].strip() or "0")
                top_categories.append({"name": name, "total": round(total, 2)})

    balance = revenues - expenses
    savings_rate = round((balance / revenues * 100), 1) if revenues > 0 else 0

    result = {
        "period": year_month,
        "revenues": round(revenues, 2),
        "expenses": round(expenses, 2),
        "balance": round(balance, 2),
        "savings_rate": savings_rate,
        "top_categories": top_categories
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    month = sys.argv[1] if len(sys.argv) > 1 else None
    query_monthly(month)
