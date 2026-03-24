---
name: english-srs
description: Spaced Repetition System for English vocabulary tracking. Manages words, errors, and review schedules in SQLite.
metadata:
  openclaw:
    emoji: 🧠
    requires:
      bins: [python3]
---

# English SRS — Spaced Repetition Vocabulary Tracker

Manages Douglas's English vocabulary learning with evidence-based spaced repetition intervals.

## Commands

All commands use the script at `scripts/srs.py`. Output is JSON.

### Add a new word

```bash
python3 scripts/srs.py add --word "straightforward" --context "The solution was straightforward" --category "adjective"
```

Categories: noun, verb, adjective, adverb, phrase, idiom, expression

### Get words due for review today

```bash
python3 scripts/srs.py due
```

Returns list of words that need review today based on SRS intervals.

### Record an attempt (correct or incorrect)

```bash
python3 scripts/srs.py attempt --word "straightforward" --correct true
```

Updates the word's review schedule. Correct → longer interval. Incorrect → reset to shorter interval.

### Record an error

```bash
python3 scripts/srs.py error --type grammar --original "I work in this yesterday" --corrected "I worked on this yesterday"
```

Error types: grammar, vocabulary, pronunciation, structure

### Get statistics

```bash
python3 scripts/srs.py stats
```

Returns: total words, mastered, due today, error counts by type, streaks, level estimate.

### Get top recurring errors

```bash
python3 scripts/srs.py top-errors --limit 10
```

### Search vocabulary

```bash
python3 scripts/srs.py search --query "deploy"
```

### Mark session completed

```bash
python3 scripts/srs.py session --type main
```

Types: main, microdose, weekend. Updates streak counter.

## SRS Intervals

After each correct review, the next interval doubles:

- Level 0: 1 day (new word)
- Level 1: 3 days
- Level 2: 7 days
- Level 3: 14 days
- Level 4: 30 days
- Level 5+: mastered (60 days)

Incorrect review: reset to Level 0 (review tomorrow).

## Database

SQLite file at `~/.openclaw/workspaces/english-tutor/skills/english-srs/english_srs.db`
Auto-created on first run.
