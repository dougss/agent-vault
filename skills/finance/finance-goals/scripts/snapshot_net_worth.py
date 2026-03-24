#!/usr/bin/env python3
"""Snapshot de patrimonio liquido cruzando FinAI (investimentos) + Life OS (contas)."""

import sys
import json
import subprocess
import os

sys.path.insert(0, __import__("os").path.dirname(__file__))
from db_lifeos import run_sql, DEFAULT_USER_ID


def get_finai_user_id():
    """Busca FINAI_USER_ID."""
    env_file = os.path.expanduser("~/.openclaw/secrets/.env")
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line.startswith("FINAI_USER_ID="):
                    return line.split("=", 1)[1].strip('"').strip("'")
    return None


def run_finai_sql(sql):
    """Executa SQL no FinAI DB."""
    cmd = [
        "docker", "exec", "finai-db-1",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-F", "|",
        "-c", sql
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr.strip()}
    return {"output": result.stdout.strip()}


def snapshot_net_worth():
    finai_uid = get_finai_user_id()

    breakdown = {
        "investments": {},
        "accounts": {},
        "liabilities": {}
    }

    total_assets = 0.0
    total_liabilities = 0.0

    # 1. Investimentos do FinAI (ativos)
    if finai_uid:
        inv_sql = (
            f"SELECT it.name, SUM(i.current_amount) "
            f"FROM investments i "
            f"JOIN investment_types it ON i.type_id = it.id "
            f"WHERE i.user_id = '{finai_uid}' AND i.is_active = true "
            f"GROUP BY it.name"
        )
        inv_result = run_finai_sql(inv_sql)
        if inv_result.get("output"):
            for line in inv_result["output"].split("\n"):
                if "|" in line:
                    parts = line.split("|")
                    name = parts[0].strip()
                    val = float(parts[1].strip() or "0")
                    breakdown["investments"][name] = round(val, 2)
                    total_assets += val

    # 2. Contas do Life OS
    acc_sql = (
        f"SELECT name, account_type, current_balance "
        f"FROM financial_accounts "
        f"WHERE user_id = '{DEFAULT_USER_ID}' AND is_active = true"
    )
    acc_result = run_sql(acc_sql)
    if acc_result.get("output"):
        for line in acc_result["output"].split("\n"):
            if "|" in line:
                parts = line.split("|")
                name = parts[0].strip()
                acc_type = parts[1].strip()
                balance = float(parts[2].strip() or "0")

                if acc_type == "credit_card" and balance < 0:
                    breakdown["liabilities"][name] = round(abs(balance), 2)
                    total_liabilities += abs(balance)
                else:
                    breakdown["accounts"][name] = round(balance, 2)
                    total_assets += balance

    net_worth = total_assets - total_liabilities

    # 3. Salvar snapshot
    breakdown_json = json.dumps(breakdown, ensure_ascii=False).replace("'", "''")
    insert_sql = (
        f"INSERT INTO net_worth_snapshots (user_id, total_assets, total_liabilities, net_worth, breakdown) "
        f"VALUES ('{DEFAULT_USER_ID}', {round(total_assets, 2)}, {round(total_liabilities, 2)}, "
        f"{round(net_worth, 2)}, '{breakdown_json}'::jsonb) "
        f"ON CONFLICT (user_id, snapshot_date) DO UPDATE SET "
        f"total_assets = EXCLUDED.total_assets, "
        f"total_liabilities = EXCLUDED.total_liabilities, "
        f"net_worth = EXCLUDED.net_worth, "
        f"breakdown = EXCLUDED.breakdown "
        f"RETURNING id, snapshot_date"
    )
    save_result = run_sql(insert_sql)

    snapshot_date = "hoje"
    if save_result.get("output") and "|" in save_result["output"]:
        parts = save_result["output"].split("|")
        snapshot_date = parts[1].strip()

    output = {
        "snapshot_date": snapshot_date,
        "total_assets": round(total_assets, 2),
        "total_liabilities": round(total_liabilities, 2),
        "net_worth": round(net_worth, 2),
        "breakdown": breakdown,
        "saved": not bool(save_result.get("error"))
    }

    if save_result.get("error"):
        output["save_error"] = save_result["error"]

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    snapshot_net_worth()
