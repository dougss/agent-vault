#!/usr/bin/env python3
"""Portfolio de investimentos via views e tabelas do FinAI."""

import sys
import json

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_finai import run_sql, get_finai_user_id


def query_investments():
    user_id = get_finai_user_id()

    # Dashboard geral
    dash_sql = (
        f"SELECT total_investments, total_portfolio_value, total_invested, "
        f"avg_roi, total_contributions, total_returns "
        f"FROM investment_dashboard "
        f"WHERE user_id = '{user_id}'"
    )
    dash_result = run_sql(dash_sql)

    dashboard = {}
    if dash_result.get("output"):
        parts = dash_result["output"].split("|")
        if len(parts) >= 6:
            dashboard = {
                "total_investments": int(parts[0].strip() or "0"),
                "total_portfolio_value": round(float(parts[1].strip() or "0"), 2),
                "total_invested": round(float(parts[2].strip() or "0"), 2),
                "avg_roi": round(float(parts[3].strip() or "0"), 2),
                "total_contributions": round(float(parts[4].strip() or "0"), 2),
                "total_returns": round(float(parts[5].strip() or "0"), 2)
            }

    # Por tipo
    type_sql = (
        f"SELECT type_name, investment_count, total_value, avg_roi "
        f"FROM investment_type_performance "
        f"WHERE user_id = '{user_id}' "
        f"ORDER BY total_value DESC"
    )
    type_result = run_sql(type_sql)

    by_type = []
    if type_result.get("output"):
        for line in type_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                by_type.append({
                    "type": parts[0].strip(),
                    "count": int(parts[1].strip() or "0"),
                    "value": round(float(parts[2].strip() or "0"), 2),
                    "roi": round(float(parts[3].strip() or "0"), 2)
                })

    # Detalhes individuais
    detail_sql = (
        f"SELECT i.name, it.name, i.institution, i.initial_amount, "
        f"i.current_amount, i.start_date "
        f"FROM investments i "
        f"JOIN investment_types it ON i.type_id = it.id "
        f"WHERE i.user_id = '{user_id}' AND i.is_active = true "
        f"ORDER BY i.current_amount DESC"
    )
    detail_result = run_sql(detail_sql)

    details = []
    if detail_result.get("output"):
        for line in detail_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                initial = float(parts[3].strip() or "0")
                current = float(parts[4].strip() or "0")
                roi = ((current - initial) / initial * 100) if initial > 0 else 0
                details.append({
                    "name": parts[0].strip(),
                    "type": parts[1].strip(),
                    "institution": parts[2].strip(),
                    "initial_amount": round(initial, 2),
                    "current_amount": round(current, 2),
                    "roi_pct": round(roi, 2),
                    "start_date": parts[5].strip()
                })

    output = {
        "summary": dashboard,
        "by_type": by_type,
        "details": details
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    query_investments()
