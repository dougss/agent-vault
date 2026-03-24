"""Modulo compartilhado para acesso ao FinAI PostgreSQL via docker exec."""

import os
import subprocess
import json


def get_finai_user_id():
    """Busca FINAI_USER_ID em ~/.openclaw/secrets/.env ou variavel de ambiente."""
    if os.environ.get("FINAI_USER_ID"):
        return os.environ["FINAI_USER_ID"]
    env_file = os.path.expanduser("~/.openclaw/secrets/.env")
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line.startswith("FINAI_USER_ID="):
                    return line.split("=", 1)[1].strip('"').strip("'")
    raise ValueError("FINAI_USER_ID nao encontrado em ~/.openclaw/secrets/.env")


def run_sql(sql, separator="|"):
    """Executa SQL via docker exec no container finai-db-1 (superuser postgres)."""
    cmd = [
        "docker", "exec",
        "finai-db-1",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-F", separator,
        "-c", sql
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr.strip()}
    return {"output": result.stdout.strip()}


def run_sql_json(sql):
    """Executa SQL e retorna resultado como lista de dicts."""
    # Usa formato CSV com header para parsing
    cmd = [
        "docker", "exec",
        "finai-db-1",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-F", "|",
        "-c", sql
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return []
    lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
    return lines
