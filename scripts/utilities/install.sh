#!/usr/bin/env bash
# Install agent-vault assets to their target locations
# Usage: install.sh <tool> [target-dir]
#
# Examples:
#   install.sh openclaw              # Install to ~/.openclaw/
#   install.sh claude-code           # Install to ~/.claude/
#   install.sh harness ~/server      # Install harness scripts to ~/server/scripts/harness/
#   install.sh hooks                 # Install git hooks to this repo

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="${1:-}"
TARGET="${2:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

usage() {
  echo "Usage: install.sh <tool> [target-dir]"
  echo ""
  echo "Tools:"
  echo "  openclaw      Install agents and skills to ~/.openclaw/"
  echo "  claude-code   Install configs to ~/.claude/"
  echo "  harness       Install harness scripts (default: ~/server/scripts/harness/)"
  echo "  hooks         Install git pre-commit hook to this repo"
  echo "  all           Install everything"
  exit 1
}

install_hooks() {
  echo "Installing pre-commit hook..."
  cp "$REPO_DIR/scripts/utilities/pre-commit-hook.sh" "$REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$REPO_DIR/.git/hooks/pre-commit"
  echo -e "${GREEN}Pre-commit hook installed.${NC}"
}

install_openclaw() {
  local dest="${TARGET:-$HOME/.openclaw}"
  echo "Installing OpenClaw assets to $dest..."

  if [[ ! -d "$dest" ]]; then
    echo -e "${RED}ERROR: $dest does not exist. Is OpenClaw installed?${NC}"
    exit 1
  fi

  # Install agent workspace files
  for agent_dir in "$REPO_DIR/agents"/*/; do
    local agent_name=$(basename "$agent_dir")
    local ws_dest

    if [[ "$agent_name" == "madclaw" ]]; then
      ws_dest="$dest/workspace"
    else
      ws_dest="$dest/workspaces/$agent_name"
    fi

    if [[ ! -d "$ws_dest" ]]; then
      echo -e "${YELLOW}SKIP: $ws_dest does not exist (agent not registered)${NC}"
      continue
    fi

    echo "  Installing $agent_name..."
    for md_file in "$agent_dir"/*.md; do
      [[ -f "$md_file" ]] || continue
      local fname=$(basename "$md_file")
      # Don't overwrite MEMORY.md — it's personal
      if [[ "$fname" == "MEMORY.md" ]]; then
        echo -e "    ${YELLOW}SKIP: $fname (personal memory, not overwritten)${NC}"
        continue
      fi
      cp "$md_file" "$ws_dest/$fname"
      echo "    Copied $fname"
    done
  done

  # Install skills
  for skill_dir in "$REPO_DIR/skills"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name=$(basename "$skill_dir")
    # Read the skill metadata to determine target
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      echo "  Skill $skill_name available (manual install — check SKILL.md for target agent)"
    fi
  done

  echo -e "${YELLOW}NOTE: only agent *.md files were copied. Workspace skills are synced into this repo via migrate.sh from the live host.${NC}"
  echo -e "${GREEN}OpenClaw assets installed.${NC}"
}

install_claude_code() {
  local dest="${TARGET:-$HOME/.claude}"
  echo "Installing Claude Code configs to $dest..."

  if [[ ! -d "$dest" ]]; then
    echo -e "${RED}ERROR: $dest does not exist. Is Claude Code installed?${NC}"
    exit 1
  fi

  # Install CLAUDE.md
  if [[ -f "$REPO_DIR/configs/claude-code/CLAUDE.md" ]]; then
    cp "$REPO_DIR/configs/claude-code/CLAUDE.md" "$dest/CLAUDE.md"
    echo "  Copied CLAUDE.md"
  fi

  # Install settings (merge, don't overwrite)
  if [[ -f "$REPO_DIR/configs/claude-code/settings.json" ]]; then
    echo -e "  ${YELLOW}NOTE: settings.json available but not auto-installed (manual merge recommended)${NC}"
  fi

  # Install skills
  if [[ -d "$REPO_DIR/configs/claude-code/skills" ]]; then
    mkdir -p "$dest/skills"
    cp -r "$REPO_DIR/configs/claude-code/skills/"* "$dest/skills/" 2>/dev/null || true
    echo "  Copied skills"
  fi

  echo -e "${GREEN}Claude Code configs installed.${NC}"
}

install_harness() {
  local dest="${TARGET:-$HOME/server/scripts/harness}"
  echo "Installing harness scripts to $dest..."
  mkdir -p "$dest"
  cp -r "$REPO_DIR/scripts/harness/"* "$dest/"
  chmod +x "$dest"/*.sh 2>/dev/null || true
  chmod +x "$dest"/lib/*.sh 2>/dev/null || true
  echo -e "${GREEN}Harness scripts installed.${NC}"
}

case "$TOOL" in
  hooks)      install_hooks ;;
  openclaw)   install_openclaw ;;
  claude-code) install_claude_code ;;
  harness)    install_harness ;;
  all)
    install_hooks
    install_openclaw
    install_claude_code
    install_harness
    ;;
  *) usage ;;
esac
