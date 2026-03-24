#!/usr/bin/env python3
"""
AI Daily Digest — RSS Feed Collector

Coleta itens dos últimos 2 dias de RSS feeds de AI,
deduplicando via SQLite local.

Output: JSON array no stdout.
"""

import json
import os
import sqlite3
import sys
import hashlib
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Dependências — instala automaticamente se ausentes
# ---------------------------------------------------------------------------

def ensure_deps():
    missing = []
    try:
        import feedparser  # noqa: F401
    except ImportError:
        missing.append("feedparser")
    try:
        import httpx  # noqa: F401
    except ImportError:
        missing.append("httpx")
    if missing:
        import subprocess
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--quiet", *missing],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

ensure_deps()

import feedparser  # noqa: E402
import httpx  # noqa: E402

# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------

SKILL_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = SKILL_DIR / "data"
DB_PATH = DATA_DIR / "seen.db"

CUTOFF_DAYS = 2
REQUEST_TIMEOUT = 15  # segundos

FEEDS = {
    "high": [
        ("Cursor Changelog", "https://changelog.cursor.com/feed.xml"),
        ("Cursor Blog", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_cursor.xml"),
        ("Anthropic News", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_anthropic_news.xml"),
        ("Anthropic Engineering", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_anthropic_engineering.xml"),
        ("Claude Code Changelog", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_anthropic_changelog_claude_code.xml"),
    ],
    "medium": [
        ("Hugging Face Blog", "https://huggingface.co/blog/feed.xml"),
        ("Ollama Blog", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_ollama.xml"),
        ("Hacker News AI", "https://hnrss.org/newest?q=AI+OR+LLM+OR+Claude+OR+GPT&points=50"),
        ("OpenAI Blog", "https://openai.com/news/rss.xml"),
        ("Google DeepMind", "https://deepmind.com/blog/feed/basic/"),
        ("Latent Space", "https://www.latent.space/feed"),
        ("The Batch", "https://raw.githubusercontent.com/Olshansk/rss-feeds/main/feeds/feed_the_batch.xml"),
    ],
    "low": [
        ("Last Week in AI", "https://lastweekin.ai/feed"),
    ],
}

# ---------------------------------------------------------------------------
# SQLite dedup
# ---------------------------------------------------------------------------

def init_db():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("""
        CREATE TABLE IF NOT EXISTS seen (
            hash TEXT PRIMARY KEY,
            url TEXT,
            first_seen TEXT
        )
    """)
    conn.commit()
    return conn


def is_seen(conn, url):
    h = hashlib.sha256(url.encode()).hexdigest()
    row = conn.execute("SELECT 1 FROM seen WHERE hash = ?", (h,)).fetchone()
    return row is not None


def mark_seen(conn, url):
    h = hashlib.sha256(url.encode()).hexdigest()
    conn.execute(
        "INSERT OR IGNORE INTO seen (hash, url, first_seen) VALUES (?, ?, ?)",
        (h, url, datetime.now(timezone.utc).isoformat()),
    )


def cleanup_old(conn, days=30):
    """Remove entradas com mais de N dias para não crescer indefinidamente."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    conn.execute("DELETE FROM seen WHERE first_seen < ?", (cutoff,))
    conn.commit()

# ---------------------------------------------------------------------------
# Parsing de data dos feeds
# ---------------------------------------------------------------------------

def parse_entry_date(entry):
    """Tenta extrair datetime do entry. Retorna None se falhar."""
    for field in ("published_parsed", "updated_parsed"):
        tp = getattr(entry, field, None)
        if tp:
            try:
                from calendar import timegm
                return datetime.fromtimestamp(timegm(tp), tz=timezone.utc)
            except Exception:
                pass
    for field in ("published", "updated"):
        raw = getattr(entry, field, None)
        if raw:
            try:
                return parsedate_to_datetime(raw).astimezone(timezone.utc)
            except Exception:
                pass
    return None

# ---------------------------------------------------------------------------
# Coleta
# ---------------------------------------------------------------------------

def fetch_feed(client, name, url):
    """Baixa e parseia um feed RSS. Retorna lista de entries."""
    try:
        resp = client.get(url, timeout=REQUEST_TIMEOUT, follow_redirects=True)
        resp.raise_for_status()
        return feedparser.parse(resp.text).entries
    except Exception as e:
        print(f"[WARN] {name}: {e}", file=sys.stderr)
        return []


def collect_all():
    cutoff = datetime.now(timezone.utc) - timedelta(days=CUTOFF_DAYS)
    conn = init_db()
    cleanup_old(conn)
    items = []

    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ai-daily-digest/1.0"
    }

    with httpx.Client(headers=headers) as client:
        for priority, feeds in FEEDS.items():
            for name, url in feeds:
                entries = fetch_feed(client, name, url)
                for entry in entries:
                    link = getattr(entry, "link", None)
                    if not link:
                        continue

                    if is_seen(conn, link):
                        continue

                    pub_date = parse_entry_date(entry)
                    if pub_date and pub_date < cutoff:
                        continue

                    title = getattr(entry, "title", "Sem título")
                    summary = ""
                    if hasattr(entry, "summary"):
                        # Limpa HTML básico do summary
                        import re
                        summary = re.sub(r"<[^>]+>", "", entry.summary or "")
                        summary = summary.strip()[:300]

                    items.append({
                        "title": title,
                        "url": link,
                        "summary": summary,
                        "source": name,
                        "priority": priority,
                        "published": pub_date.isoformat() if pub_date else None,
                    })

                    mark_seen(conn, link)

    conn.commit()
    conn.close()
    return items


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    items = collect_all()
    # Ordena: high > medium > low, depois por data (mais recente primeiro)
    priority_order = {"high": 0, "medium": 1, "low": 2}
    items.sort(key=lambda x: (
        priority_order.get(x["priority"], 9),
        x["published"] or "",
    ), reverse=False)
    # Reverse published dentro de cada prioridade
    items.sort(key=lambda x: (
        priority_order.get(x["priority"], 9),
        -(datetime.fromisoformat(x["published"]).timestamp() if x["published"] else 0),
    ))

    print(json.dumps(items, ensure_ascii=False, indent=2))
    print(f"\n[INFO] {len(items)} itens coletados", file=sys.stderr)
