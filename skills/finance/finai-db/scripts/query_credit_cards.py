#!/usr/bin/env python3
"""Cartoes de credito e faturas do mes."""

import sys
import json
from datetime import datetime

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_credit_cards(year_month=None):
    user_id = get_finai_user_id()

    if year_month is None:
        year_month = datetime.now().strftime("%Y-%m")

    year, month = year_month.split("-")

    # Cartoes ativos com faturas do mes
    sql = (
        f"SELECT cc.name, cc.due_day, cc.active, "
        f"COALESCE(ci.amount, 0), COALESCE(ci.paid, false) "
        f"FROM credit_cards cc "
        f"LEFT JOIN credit_card_invoices ci ON cc.id = ci.credit_card_id "
        f"AND ci.year = {year} AND ci.month = {month} "
        f"WHERE cc.user_id = '{user_id}' "
        f"ORDER BY cc.name"
    )
    result = run_sql(sql)

    cards = []
    total_invoices = 0.0
    if result.get("output"):
        for line in result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                amount = float(parts[3].strip() or "0")
                total_invoices += amount
                cards.append({
                    "name": parts[0].strip(),
                    "due_day": int(parts[1].strip() or "0"),
                    "active": parts[2].strip() == "t",
                    "invoice_amount": round(amount, 2),
                    "paid": parts[4].strip() == "t"
                })

    # Total de gastos no cartao no mes (por transacoes)
    spending_sql = (
        f"SELECT cc.name, COALESCE(SUM(t.value), 0), COUNT(t.id) "
        f"FROM transactions t "
        f"JOIN credit_cards cc ON t.credit_card_id = cc.id "
        f"WHERE t.user_id = '{user_id}' "
        f"AND EXTRACT(YEAR FROM t.purchase_date) = {year} "
        f"AND EXTRACT(MONTH FROM t.purchase_date) = {month} "
        f"GROUP BY cc.name ORDER BY SUM(t.value) DESC"
    )
    spend_result = run_sql(spending_sql)

    spending_by_card = []
    if spend_result.get("output"):
        for line in spend_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                spending_by_card.append({
                    "card": parts[0].strip(),
                    "total_spent": round(float(parts[1].strip() or "0"), 2),
                    "transaction_count": int(parts[2].strip() or "0")
                })

    output = {
        "period": year_month,
        "total_invoices": round(total_invoices, 2),
        "cards": cards,
        "spending_by_card": spending_by_card
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    month = sys.argv[1] if len(sys.argv) > 1 else None
    query_credit_cards(month)
