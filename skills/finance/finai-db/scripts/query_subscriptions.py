#!/usr/bin/env python3
"""Assinaturas ativas via view subscription_dashboard."""

import sys
import json

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_subscriptions():
    user_id = get_finai_user_id()

    sql = (
        f"SELECT name, frequency, expected_amount, billing_day, "
        f"category_name, card_name, total_charges, avg_charge_amount, "
        f"total_paid, charge_status "
        f"FROM subscription_dashboard "
        f"WHERE user_id = '{user_id}' AND active = true "
        f"ORDER BY expected_amount DESC"
    )
    result = run_sql(sql)

    subscriptions = []
    monthly_total = 0.0

    if result.get("output"):
        for line in result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                amount = float(parts[2].strip() or "0")
                freq = parts[1].strip()

                # Normaliza para mensal
                if freq == "yearly":
                    monthly_equiv = amount / 12
                elif freq == "quarterly":
                    monthly_equiv = amount / 3
                else:
                    monthly_equiv = amount

                monthly_total += monthly_equiv

                subscriptions.append({
                    "name": parts[0].strip(),
                    "frequency": freq,
                    "amount": round(amount, 2),
                    "billing_day": int(parts[3].strip() or "0") if parts[3].strip() else None,
                    "category": parts[4].strip() or None,
                    "card": parts[5].strip() or None,
                    "total_charges": int(parts[6].strip() or "0"),
                    "avg_charge": round(float(parts[7].strip() or "0"), 2),
                    "total_paid": round(float(parts[8].strip() or "0"), 2),
                    "status": parts[9].strip()
                })

    output = {
        "active_count": len(subscriptions),
        "monthly_total": round(monthly_total, 2),
        "subscriptions": subscriptions
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    query_subscriptions()
