#!/usr/bin/env python3
"""Historico de patrimonio liquido dos ultimos N meses."""

import sys
import json
import argparse

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_lifeos import run_sql, DEFAULT_USER_ID


def query_net_worth(months=12):
    sql = (
        f"SELECT snapshot_date, total_assets, total_liabilities, net_worth, breakdown "
        f"FROM net_worth_snapshots "
        f"WHERE user_id = '{DEFAULT_USER_ID}' "
        f"AND snapshot_date >= CURRENT_DATE - INTERVAL '{months} months' "
        f"ORDER BY snapshot_date DESC"
    )
    result = run_sql(sql)

    snapshots = []
    if result.get("output"):
        for line in result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|", 4)
                breakdown = {}
                if len(parts) > 4 and parts[4].strip():
                    try:
                        breakdown = json.loads(parts[4].strip())
                    except json.JSONDecodeError:
                        pass
                snapshots.append({
                    "date": parts[0].strip(),
                    "total_assets": round(float(parts[1].strip() or "0"), 2),
                    "total_liabilities": round(float(parts[2].strip() or "0"), 2),
                    "net_worth": round(float(parts[3].strip() or "0"), 2),
                    "breakdown": breakdown
                })

    # Variacao
    variation = None
    if len(snapshots) >= 2:
        newest = snapshots[0]["net_worth"]
        oldest = snapshots[-1]["net_worth"]
        diff = newest - oldest
        pct = round((diff / oldest * 100), 1) if oldest != 0 else 0
        variation = {
            "absolute": round(diff, 2),
            "percentage": pct,
            "from": snapshots[-1]["date"],
            "to": snapshots[0]["date"]
        }

    output = {
        "period_months": months,
        "count": len(snapshots),
        "snapshots": snapshots,
        "variation": variation
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--months", type=int, default=12)
    args = parser.parse_args()
    query_net_worth(args.months)
