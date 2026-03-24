#!/usr/bin/env python3
"""
English SRS — Spaced Repetition System for vocabulary tracking.
SQLite-backed. Used by Kai (English Tutor agent) via OpenClaw.

Usage:
    python3 srs.py add --word WORD --context CONTEXT [--category CATEGORY]
    python3 srs.py due
    python3 srs.py attempt --word WORD --correct true|false
    python3 srs.py error --type TYPE --original TEXT --corrected TEXT
    python3 srs.py stats
    python3 srs.py top-errors [--limit N]
    python3 srs.py search --query TEXT
"""

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "english_srs.db"

# Spaced repetition intervals (in days) — based on SM-2 simplified
SRS_INTERVALS = [1, 3, 7, 14, 30, 60, 120]


def get_db():
    """Get database connection, creating tables if needed."""
    db = sqlite3.connect(str(DB_PATH))
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA journal_mode=WAL")
    db.executescript("""
        CREATE TABLE IF NOT EXISTS vocabulary (
            word TEXT PRIMARY KEY,
            context TEXT NOT NULL,
            category TEXT DEFAULT 'unknown',
            first_seen DATE NOT NULL,
            times_correct INTEGER DEFAULT 0,
            times_incorrect INTEGER DEFAULT 0,
            srs_level INTEGER DEFAULT 0,
            next_review DATE NOT NULL,
            mastered BOOLEAN DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS errors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL CHECK(type IN ('grammar', 'vocabulary', 'pronunciation', 'structure')),
            original TEXT NOT NULL,
            corrected TEXT NOT NULL,
            date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            reviewed BOOLEAN DEFAULT 0,
            times_repeated INTEGER DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date DATE NOT NULL,
            type TEXT NOT NULL DEFAULT 'main',
            duration_min INTEGER,
            words_learned INTEGER DEFAULT 0,
            errors_count INTEGER DEFAULT 0,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_vocab_next_review ON vocabulary(next_review);
        CREATE INDEX IF NOT EXISTS idx_vocab_mastered ON vocabulary(mastered);
        CREATE INDEX IF NOT EXISTS idx_errors_type ON errors(type);
        CREATE INDEX IF NOT EXISTS idx_errors_date ON errors(date);
    """)
    return db


def cmd_add(args):
    """Add a new word to the vocabulary tracker."""
    db = get_db()
    today = datetime.now().strftime("%Y-%m-%d")
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

    try:
        db.execute(
            "INSERT INTO vocabulary (word, context, category, first_seen, next_review) VALUES (?, ?, ?, ?, ?)",
            (args.word.lower().strip(), args.context, args.category or "unknown", today, tomorrow)
        )
        db.commit()
        print(json.dumps({"status": "ok", "word": args.word.lower().strip(), "next_review": tomorrow}))
    except sqlite3.IntegrityError:
        # Word already exists — update context if provided
        db.execute(
            "UPDATE vocabulary SET context = ?, category = COALESCE(?, category) WHERE word = ?",
            (args.context, args.category, args.word.lower().strip())
        )
        db.commit()
        print(json.dumps({"status": "updated", "word": args.word.lower().strip(), "message": "Word already tracked, context updated"}))
    finally:
        db.close()


def cmd_due(args):
    """Get all words due for review today."""
    db = get_db()
    today = datetime.now().strftime("%Y-%m-%d")
    rows = db.execute(
        "SELECT word, context, category, times_correct, times_incorrect, srs_level, first_seen FROM vocabulary WHERE next_review <= ? AND mastered = 0 ORDER BY srs_level ASC, next_review ASC",
        (today,)
    ).fetchall()
    db.close()

    result = [dict(r) for r in rows]
    print(json.dumps({"status": "ok", "count": len(result), "due": result}))


def cmd_attempt(args):
    """Record a review attempt for a word."""
    db = get_db()
    word = args.word.lower().strip()
    correct = args.correct.lower() in ("true", "1", "yes")

    row = db.execute("SELECT * FROM vocabulary WHERE word = ?", (word,)).fetchone()
    if not row:
        print(json.dumps({"status": "error", "message": f"Word '{word}' not found"}))
        db.close()
        return

    if correct:
        new_level = min(row["srs_level"] + 1, len(SRS_INTERVALS) - 1)
        new_correct = row["times_correct"] + 1
        interval = SRS_INTERVALS[new_level]
        next_review = (datetime.now() + timedelta(days=interval)).strftime("%Y-%m-%d")

        # Check mastery: correct 4+ times across 30+ days
        first_seen = datetime.strptime(row["first_seen"], "%Y-%m-%d")
        days_tracked = (datetime.now() - first_seen).days
        mastered = 1 if new_correct >= 4 and days_tracked >= 30 else 0

        db.execute(
            "UPDATE vocabulary SET times_correct = ?, srs_level = ?, next_review = ?, mastered = ? WHERE word = ?",
            (new_correct, new_level, next_review, mastered, word)
        )
        db.commit()
        print(json.dumps({
            "status": "ok", "word": word, "correct": True,
            "srs_level": new_level, "next_review": next_review,
            "interval_days": interval, "mastered": bool(mastered)
        }))
    else:
        new_incorrect = row["times_incorrect"] + 1
        # Reset to level 0 on incorrect
        next_review = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        db.execute(
            "UPDATE vocabulary SET times_incorrect = ?, srs_level = 0, next_review = ?, mastered = 0 WHERE word = ?",
            (new_incorrect, next_review, word)
        )
        db.commit()
        print(json.dumps({
            "status": "ok", "word": word, "correct": False,
            "srs_level": 0, "next_review": next_review,
            "interval_days": 1, "mastered": False
        }))

    db.close()


def cmd_error(args):
    """Record a language error."""
    db = get_db()

    # Check for similar existing error to increment times_repeated
    existing = db.execute(
        "SELECT id, times_repeated FROM errors WHERE corrected = ? AND type = ? ORDER BY date DESC LIMIT 1",
        (args.corrected, args.type)
    ).fetchone()

    if existing:
        db.execute(
            "UPDATE errors SET times_repeated = ?, date = CURRENT_TIMESTAMP, original = ? WHERE id = ?",
            (existing["times_repeated"] + 1, args.original, existing["id"])
        )
        db.commit()
        print(json.dumps({
            "status": "ok", "action": "incremented",
            "type": args.type, "times_repeated": existing["times_repeated"] + 1
        }))
    else:
        db.execute(
            "INSERT INTO errors (type, original, corrected) VALUES (?, ?, ?)",
            (args.type, args.original, args.corrected)
        )
        db.commit()
        print(json.dumps({"status": "ok", "action": "added", "type": args.type}))

    db.close()


def cmd_stats(args):
    """Get comprehensive learning statistics."""
    db = get_db()
    today = datetime.now().strftime("%Y-%m-%d")

    total_words = db.execute("SELECT COUNT(*) as c FROM vocabulary").fetchone()["c"]
    mastered = db.execute("SELECT COUNT(*) as c FROM vocabulary WHERE mastered = 1").fetchone()["c"]
    due_today = db.execute("SELECT COUNT(*) as c FROM vocabulary WHERE next_review <= ? AND mastered = 0", (today,)).fetchone()["c"]
    total_errors = db.execute("SELECT COUNT(*) as c FROM errors").fetchone()["c"]

    # Errors by type
    error_types = db.execute("SELECT type, COUNT(*) as c, SUM(times_repeated) as total FROM errors GROUP BY type").fetchall()

    # Words learned this month
    month_start = datetime.now().replace(day=1).strftime("%Y-%m-%d")
    new_this_month = db.execute("SELECT COUNT(*) as c FROM vocabulary WHERE first_seen >= ?", (month_start,)).fetchone()["c"]

    # Accuracy (from vocabulary attempts)
    total_correct = db.execute("SELECT COALESCE(SUM(times_correct), 0) as c FROM vocabulary").fetchone()["c"]
    total_incorrect = db.execute("SELECT COALESCE(SUM(times_incorrect), 0) as c FROM vocabulary").fetchone()["c"]
    total_attempts = total_correct + total_incorrect
    accuracy = round(total_correct / total_attempts * 100, 1) if total_attempts > 0 else 0

    # Sessions this month
    sessions_month = db.execute("SELECT COUNT(*) as c FROM sessions WHERE date >= ?", (month_start,)).fetchone()["c"]

    # SRS level distribution
    levels = db.execute("SELECT srs_level, COUNT(*) as c FROM vocabulary WHERE mastered = 0 GROUP BY srs_level ORDER BY srs_level").fetchall()

    result = {
        "status": "ok",
        "vocabulary": {
            "total": total_words,
            "mastered": mastered,
            "active": total_words - mastered,
            "due_today": due_today,
            "new_this_month": new_this_month,
            "accuracy_pct": accuracy,
            "total_attempts": total_attempts
        },
        "errors": {
            "total_unique": total_errors,
            "by_type": {r["type"]: {"unique": r["c"], "total_occurrences": r["total"]} for r in error_types}
        },
        "sessions": {
            "this_month": sessions_month
        },
        "srs_distribution": {f"level_{r['srs_level']}": r["c"] for r in levels}
    }

    print(json.dumps(result, indent=2))
    db.close()


def cmd_top_errors(args):
    """Get most recurring errors."""
    db = get_db()
    limit = args.limit or 5
    rows = db.execute(
        "SELECT type, original, corrected, times_repeated, date FROM errors ORDER BY times_repeated DESC, date DESC LIMIT ?",
        (limit,)
    ).fetchall()
    db.close()

    result = [dict(r) for r in rows]
    print(json.dumps({"status": "ok", "count": len(result), "errors": result}))


def cmd_search(args):
    """Search vocabulary by keyword."""
    db = get_db()
    query = f"%{args.query.lower()}%"
    rows = db.execute(
        "SELECT word, context, category, times_correct, times_incorrect, srs_level, mastered, next_review FROM vocabulary WHERE word LIKE ? OR context LIKE ? ORDER BY word",
        (query, query)
    ).fetchall()
    db.close()

    result = [dict(r) for r in rows]
    print(json.dumps({"status": "ok", "count": len(result), "results": result}))


def cmd_log_session(args):
    """Log a completed session."""
    db = get_db()
    today = datetime.now().strftime("%Y-%m-%d")
    db.execute(
        "INSERT INTO sessions (date, type, duration_min, words_learned, errors_count, notes) VALUES (?, ?, ?, ?, ?, ?)",
        (today, args.type or "main", args.duration, args.words or 0, args.errors or 0, args.notes)
    )
    db.commit()

    total = db.execute("SELECT COUNT(*) as c FROM sessions").fetchone()["c"]
    db.close()

    print(json.dumps({"status": "ok", "total_sessions": total}))


def main():
    parser = argparse.ArgumentParser(description="English SRS — Spaced Repetition Vocabulary Tracker")
    sub = parser.add_subparsers(dest="command", required=True)

    # add
    p_add = sub.add_parser("add", help="Add a new word")
    p_add.add_argument("--word", required=True)
    p_add.add_argument("--context", required=True)
    p_add.add_argument("--category", default="unknown")

    # due
    sub.add_parser("due", help="Get words due for review")

    # attempt
    p_att = sub.add_parser("attempt", help="Record a review attempt")
    p_att.add_argument("--word", required=True)
    p_att.add_argument("--correct", required=True)

    # error
    p_err = sub.add_parser("error", help="Record an error")
    p_err.add_argument("--type", required=True, choices=["grammar", "vocabulary", "pronunciation", "structure"])
    p_err.add_argument("--original", required=True)
    p_err.add_argument("--corrected", required=True)

    # stats
    sub.add_parser("stats", help="Get learning statistics")

    # top-errors
    p_top = sub.add_parser("top-errors", help="Get top recurring errors")
    p_top.add_argument("--limit", type=int, default=5)

    # search
    p_search = sub.add_parser("search", help="Search vocabulary")
    p_search.add_argument("--query", required=True)

    # log-session
    p_session = sub.add_parser("log-session", help="Log a completed session")
    p_session.add_argument("--type", default="main")
    p_session.add_argument("--duration", type=int)
    p_session.add_argument("--words", type=int, default=0)
    p_session.add_argument("--errors", type=int, default=0)
    p_session.add_argument("--notes", default="")

    args = parser.parse_args()
    commands = {
        "add": cmd_add, "due": cmd_due, "attempt": cmd_attempt,
        "error": cmd_error, "stats": cmd_stats, "top-errors": cmd_top_errors,
        "search": cmd_search, "log-session": cmd_log_session,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
