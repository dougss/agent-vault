"""Modulo compartilhado para acesso ao Life OS PostgreSQL via docker exec."""

import os
import subprocess

DEFAULT_USER_ID = "00000000-0000-0000-0000-000000000001"


def get_db_pass():
    """Busca senha do banco em ~/.openclaw/secrets/.env ou variavel de ambiente."""
    if os.environ.get("LIFE_OS_DB_PASS"):
        return os.environ["LIFE_OS_DB_PASS"]
    env_file = os.path.expanduser("~/.openclaw/secrets/.env")
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line.startswith("LIFE_OS_DB_PASS="):
                    return line.split("=", 1)[1].strip('"').strip("'")
    return "changeme_in_production"


def run_sql(sql, separator="|"):
    """Executa SQL via docker exec no container postgres."""
    db_pass = get_db_pass()

    cmd = [
        "docker", "exec",
        "-e", f"PGPASSWORD={db_pass}",
        "postgres",
        "psql", "-U", "life_os", "-d", "life_os",
        "-t", "-A", "-F", separator,
        "-c", sql
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return {"error": result.stderr.strip()}
    return {"output": result.stdout.strip()}
