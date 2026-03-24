#!/usr/bin/env bash
# Migrate assets from live system to agent-vault
# Usage: migrate.sh [--dry-run]
# This script copies, sanitizes, and organizes all agentic assets

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DRY_RUN="${1:-}"
OPENCLAW="$HOME/.openclaw"
CLAUDE="$HOME/.claude"
HARNESS="$HOME/server/scripts/harness"
SERVER="$HOME/server/scripts"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

copy_file() {
  local src="$1" dst="$2"
  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo -e "  ${YELLOW}[DRY] $src -> $dst${NC}"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo -e "  ${GREEN}Copied${NC} $(basename "$src") -> $dst"
}

copy_dir() {
  local src="$1" dst="$2"
  if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo -e "  ${YELLOW}[DRY] $src/ -> $dst/${NC}"
    return
  fi
  mkdir -p "$dst"
  cp -r "$src"/* "$dst/" 2>/dev/null || true
  echo -e "  ${GREEN}Copied dir${NC} $src -> $dst"
}

sanitize_file() {
  local file="$1"
  if [[ "$DRY_RUN" == "--dry-run" ]]; then return; fi
  # Replace known secret patterns with placeholders
  if [[ -f "$file" ]]; then
    # API keys
    sed -i '' 's/sk-proj-[A-Za-z0-9_-]\{20,\}/${OPENAI_API_KEY}/g' "$file" 2>/dev/null || true
    sed -i '' 's/AIzaSy[A-Za-z0-9_-]\{30,\}/${GEMINI_API_KEY}/g' "$file" 2>/dev/null || true
    sed -i '' 's/sk-[a-z0-9]\{30,\}/${API_SECRET_KEY}/g' "$file" 2>/dev/null || true
    sed -i '' 's/BSA[A-Za-z0-9]\{20,\}/${BRAVE_API_KEY}/g' "$file" 2>/dev/null || true
    # Telegram IDs
    sed -i '' 's/"to": "[0-9]\{6,\}"/"to": "${TELEGRAM_CHAT_ID}"/g' "$file" 2>/dev/null || true
    # Hardcoded paths (make relative)
    sed -i '' 's|/Users/macmini/\.openclaw|~/.openclaw|g' "$file" 2>/dev/null || true
    sed -i '' 's|/Users/macmini/server|~/server|g' "$file" 2>/dev/null || true
    sed -i '' 's|/Users/macmini|~|g' "$file" 2>/dev/null || true
  fi
}

echo "=== Agent Vault Migration ==="
echo "Source: $OPENCLAW, $CLAUDE, $HARNESS"
echo "Target: $REPO_DIR"
[[ "$DRY_RUN" == "--dry-run" ]] && echo "(DRY RUN — no files will be copied)"
echo ""

# === 1. OpenClaw Agents ===
echo "[1/6] Migrating OpenClaw agents..."

# Main agent (MadClaw)
for md in SOUL.md AGENTS.md IDENTITY.md TOOLS.md USER.md BOOTSTRAP.md HEARTBEAT.md; do
  [[ -f "$OPENCLAW/workspace/$md" ]] && copy_file "$OPENCLAW/workspace/$md" "$REPO_DIR/agents/madclaw/$md"
done

# Specialist agents
for ws_dir in "$OPENCLAW/workspaces"/*/; do
  agent_name=$(basename "$ws_dir")
  for md in SOUL.md AGENTS.md IDENTITY.md TOOLS.md USER.md BOOTSTRAP.md HEARTBEAT.md; do
    [[ -f "$ws_dir/$md" ]] && copy_file "$ws_dir/$md" "$REPO_DIR/agents/$agent_name/$md"
  done
done

# === 2. OpenClaw Skills ===
echo -e "\n[2/6] Migrating OpenClaw skills..."

# Main workspace skills
for skill_dir in "$OPENCLAW/workspace/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == "*" ]] && continue
  mkdir -p "$REPO_DIR/skills/shared/$skill_name"
  # Copy SKILL.md
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/shared/$skill_name/SKILL.md"
  # Copy scripts
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/shared/$skill_name/scripts"
  # Copy _meta.json
  [[ -f "$skill_dir/_meta.json" ]] && copy_file "$skill_dir/_meta.json" "$REPO_DIR/skills/shared/$skill_name/_meta.json"
done

# Global skills (ai-daily-digest)
for skill_dir in "$OPENCLAW/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == "*" ]] && continue
  mkdir -p "$REPO_DIR/skills/automation/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/automation/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/automation/$skill_name/scripts"
  [[ -d "$skill_dir/references" ]] && copy_dir "$skill_dir/references" "$REPO_DIR/skills/automation/$skill_name/references"
done

# Health skills
for skill_name in macro-calc health-db; do
  skill_dir="$OPENCLAW/workspaces/health-coach/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/health/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/health/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/health/$skill_name/scripts"
done

# Finance skills
for skill_name in finai-db finance-goals investment-analysis portfolio-review; do
  skill_dir="$OPENCLAW/workspaces/finance-advisor/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/finance/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/finance/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/finance/$skill_name/scripts"
done

# English skills
for skill_name in english-srs; do
  skill_dir="$OPENCLAW/workspaces/english-tutor/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/english/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/english/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/english/$skill_name/scripts"
done

# Media skills (image-gen, video-gen)
for skill_name in bailian-image nano-banana-pro; do
  skill_dir="$OPENCLAW/workspaces/image-gen/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/media/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/media/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/media/$skill_name/scripts"
done
for skill_name in ai-video-gen; do
  skill_dir="$OPENCLAW/workspaces/video-gen/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/media/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/media/$skill_name/SKILL.md"
  # Video gen has scripts at skill root, not in scripts/
  for py in "$skill_dir"/*.py; do
    [[ -f "$py" ]] && copy_file "$py" "$REPO_DIR/skills/media/$skill_name/scripts/$(basename "$py")"
  done
  [[ -f "$skill_dir/requirements.txt" ]] && copy_file "$skill_dir/requirements.txt" "$REPO_DIR/skills/media/$skill_name/requirements.txt"
done

# Research skills
for skill_name in deep-research-pro bailian-web-search arxiv-cli-tools; do
  skill_dir="$OPENCLAW/workspaces/researcher/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/research/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/research/$skill_name/SKILL.md"
  [[ -d "$skill_dir/scripts" ]] && copy_dir "$skill_dir/scripts" "$REPO_DIR/skills/research/$skill_name/scripts"
  [[ -f "$skill_dir/_meta.json" ]] && copy_file "$skill_dir/_meta.json" "$REPO_DIR/skills/research/$skill_name/_meta.json"
done

# Planning skills
for skill_name in brainstorming writing-plans excalidraw excalidraw-obsidian; do
  # Try planner first, then knowledge-forge
  for ws in planner knowledge-forge; do
    skill_dir="$OPENCLAW/workspaces/$ws/skills/$skill_name"
    [[ -d "$skill_dir" ]] || continue
    mkdir -p "$REPO_DIR/skills/planning/$skill_name"
    [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/planning/$skill_name/SKILL.md"
    [[ -f "$skill_dir/_meta.json" ]] && copy_file "$skill_dir/_meta.json" "$REPO_DIR/skills/planning/$skill_name/_meta.json"
    break  # Only copy once
  done
done

# Task orchestrator skills
for skill_name in agent-task-tracker executing-plans; do
  skill_dir="$OPENCLAW/workspaces/task-orchestrator/skills/$skill_name"
  [[ -d "$skill_dir" ]] || continue
  mkdir -p "$REPO_DIR/skills/shared/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/shared/$skill_name/SKILL.md"
  [[ -f "$skill_dir/_meta.json" ]] && copy_file "$skill_dir/_meta.json" "$REPO_DIR/skills/shared/$skill_name/_meta.json"
done

# Prompt engineer skills
skill_dir="$OPENCLAW/workspaces/prompt-engineer/skills/skill-creator"
if [[ -d "$skill_dir" ]] && [[ ! -d "$REPO_DIR/skills/shared/skill-creator" ]]; then
  mkdir -p "$REPO_DIR/skills/shared/skill-creator"
  [[ -f "$skill_dir/SKILL.md" ]] && copy_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/shared/skill-creator/SKILL.md"
fi

# === 3. Cron Jobs ===
echo -e "\n[3/6] Migrating cron jobs..."
[[ -f "$OPENCLAW/cron/jobs.json" ]] && copy_file "$OPENCLAW/cron/jobs.json" "$REPO_DIR/cron/jobs.json"

# === 4. Harness Scripts ===
echo -e "\n[4/6] Migrating harness scripts..."
if [[ -d "$HARNESS" ]]; then
  for f in "$HARNESS"/*.sh; do
    [[ -f "$f" ]] && copy_file "$f" "$REPO_DIR/scripts/harness/$(basename "$f")"
  done
  [[ -d "$HARNESS/lib" ]] && copy_dir "$HARNESS/lib" "$REPO_DIR/scripts/harness/lib"
  [[ -d "$HARNESS/templates" ]] && copy_dir "$HARNESS/templates" "$REPO_DIR/scripts/harness/templates"
fi

# === 5. Claude Code Configs ===
echo -e "\n[5/6] Migrating Claude Code configs..."
[[ -f "$CLAUDE/CLAUDE.md" ]] && copy_file "$CLAUDE/CLAUDE.md" "$REPO_DIR/configs/claude-code/CLAUDE.md"
[[ -f "$CLAUDE/settings.json" ]] && copy_file "$CLAUDE/settings.json" "$REPO_DIR/configs/claude-code/settings.json"
[[ -f "$CLAUDE/settings.local.json" ]] && copy_file "$CLAUDE/settings.local.json" "$REPO_DIR/configs/claude-code/settings.local.json"
# Claude Code custom skill
[[ -d "$CLAUDE/skills" ]] && copy_dir "$CLAUDE/skills" "$REPO_DIR/configs/claude-code/skills"
# Server CLAUDE.md
[[ -f "$HOME/server/CLAUDE.md" ]] && copy_file "$HOME/server/CLAUDE.md" "$REPO_DIR/configs/claude-code/server-CLAUDE.md"

# === 6. Server Scripts ===
echo -e "\n[6/6] Migrating server scripts..."
for script in api-spending.sh status.sh backup.sh deploy.sh; do
  [[ -f "$SERVER/$script" ]] && copy_file "$SERVER/$script" "$REPO_DIR/scripts/server/$script"
done

# === Sanitize all copied files ===
if [[ "$DRY_RUN" != "--dry-run" ]]; then
  echo -e "\n[SANITIZE] Removing secrets from copied files..."
  find "$REPO_DIR" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '*.json' \) \
    -not -path '*/.git/*' -not -name '.env.example' -not -name 'migrate.sh' \
    -not -name 'validate.sh' -not -name 'pre-commit-hook.sh' | while read -r f; do
    sanitize_file "$f"
  done
  echo -e "${GREEN}Sanitization complete.${NC}"
fi

echo -e "\n=== Migration complete ==="
echo "Run: scripts/utilities/validate.sh to check for issues"
