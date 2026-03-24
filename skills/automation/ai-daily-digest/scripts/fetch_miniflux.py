#!/usr/bin/env python3
"""
AI Daily Digest — Miniflux Feed Fetcher

Consulta a API do Miniflux para obter entries não lidos,
retorna JSON no stdout no mesmo formato do collect_feeds.py.

Após o digest ser enviado, rodar com --mark-read para marcar como lidos.
"""

import json
import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Dependências
# ---------------------------------------------------------------------------

def ensure_deps():
    try:
        import httpx  # noqa: F401
    except ImportError:
        import subprocess
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--quiet", "httpx"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

ensure_deps()

import httpx  # noqa: E402

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

MINIFLUX_URL = os.environ.get("MINIFLUX_URL", "http://127.0.0.1:8081")
MINIFLUX_API_KEY = os.environ.get("MINIFLUX_API_KEY", "")

# Load from secrets/.env if not in environment
if not MINIFLUX_API_KEY:
    secrets_env = Path.home() / ".openclaw" / "secrets" / ".env"
    if secrets_env.exists():
        for line in secrets_env.read_text().splitlines():
            line = line.strip()
            if line.startswith("MINIFLUX_API_KEY="):
                MINIFLUX_API_KEY = line.split("=", 1)[1].strip().strip("'\"")
                break

if not MINIFLUX_API_KEY:
    print("[ERROR] MINIFLUX_API_KEY not found in env or ~/.openclaw/secrets/.env", file=sys.stderr)
    sys.exit(1)

# Category name → priority mapping (set in Miniflux UI)
CATEGORY_PRIORITY = {
    "Alta prioridade": "high",
    "High": "high",
    "Média prioridade": "medium",
    "Medium": "medium",
    "Baixa prioridade": "low",
    "Low": "low",
}
DEFAULT_PRIORITY = "medium"

HEADERS = {"X-Auth-Token": MINIFLUX_API_KEY}

# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

def api_get(path, params=None):
    url = f"{MINIFLUX_URL}/v1{path}"
    with httpx.Client(timeout=15) as client:
        resp = client.get(url, headers=HEADERS, params=params)
        resp.raise_for_status()
        return resp.json()


def api_put(path, data):
    url = f"{MINIFLUX_URL}/v1{path}"
    with httpx.Client(timeout=15) as client:
        resp = client.put(url, headers=HEADERS, json=data)
        resp.raise_for_status()
        return resp


def get_feeds():
    """Get all feeds with their category info for priority mapping."""
    feeds = api_get("/feeds")
    feed_map = {}
    for f in feeds:
        cat_title = f.get("category", {}).get("title", "")
        feed_map[f["id"]] = {
            "title": f.get("title", ""),
            "priority": CATEGORY_PRIORITY.get(cat_title, DEFAULT_PRIORITY),
        }
    return feed_map


def fetch_unread(limit=50):
    """Fetch unread entries from Miniflux."""
    data = api_get("/entries", params={
        "status": "unread",
        "order": "published_at",
        "direction": "desc",
        "limit": limit,
    })
    return data.get("entries", [])


def mark_as_read(entry_ids):
    """Mark entries as read in Miniflux."""
    if not entry_ids:
        return
    api_put("/entries", {"entry_ids": entry_ids, "status": "read"})
    print(f"[INFO] Marked {len(entry_ids)} entries as read", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def collect():
    feed_map = get_feeds()
    entries = fetch_unread()
    items = []

    for entry in entries:
        feed_info = feed_map.get(entry.get("feed_id", 0), {})
        title = entry.get("title", "Sem título")
        url = entry.get("url", "")
        if not url:
            continue

        # Extract summary: prefer content snippet
        content = entry.get("content", "")
        import re
        summary = re.sub(r"<[^>]+>", "", content or "")
        summary = summary.strip()[:300]

        items.append({
            "id": entry["id"],
            "title": title,
            "url": url,
            "summary": summary,
            "source": feed_info.get("title", entry.get("feed", {}).get("title", "Unknown")),
            "priority": feed_info.get("priority", DEFAULT_PRIORITY),
            "published": entry.get("published_at"),
        })

    return items


if __name__ == "__main__":
    if "--mark-read" in sys.argv:
        # Read entry IDs from stdin (JSON array)
        try:
            ids = json.load(sys.stdin)
            mark_as_read(ids)
        except Exception as e:
            print(f"[ERROR] mark-read: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        items = collect()
        # Sort by priority then date
        priority_order = {"high": 0, "medium": 1, "low": 2}
        items.sort(key=lambda x: (
            priority_order.get(x["priority"], 9),
            -(len(x.get("published") or "") and 1),
        ))
        # Remove internal id from output but save for mark-read
        entry_ids = [item.pop("id") for item in items]
        print(json.dumps(items, ensure_ascii=False, indent=2))
        print(f"\n[INFO] {len(items)} itens coletados do Miniflux", file=sys.stderr)

        # Save entry IDs for later mark-read
        ids_file = Path(__file__).resolve().parent.parent / "data" / "last_entry_ids.json"
        ids_file.parent.mkdir(parents=True, exist_ok=True)
        ids_file.write_text(json.dumps(entry_ids))
