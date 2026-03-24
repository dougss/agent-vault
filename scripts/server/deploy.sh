#!/bin/bash
set -euo pipefail

APPS_DIR="$HOME/server/apps"
LOGS_DIR="$HOME/server/logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[deploy]${NC} $1"; }
ok()  { echo -e "${GREEN}[  OK  ]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
warn(){ echo -e "${YELLOW}[ WARN]${NC} $1"; }

# List available projects
list_projects() {
    log "Projetos disponíveis em $APPS_DIR:"
    echo ""
    local found=0
    for dir in "$APPS_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        status="--"
        if [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/docker-compose.yaml" ]; then
            running=$(cd "$dir" && docker compose ps --format '{{.Status}}' 2>/dev/null | head -1)
            status="${running:-parado}"
        fi
        printf "  %-20s %s\n" "$name" "$status"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        warn "Nenhum projeto encontrado. Use add-project.sh para criar um."
    fi
}

# Deploy a project
deploy() {
    local project="$1"
    local project_dir="$APPS_DIR/$project"

    if [ ! -d "$project_dir" ]; then
        err "Projeto '$project' não encontrado em $APPS_DIR/"
        list_projects
        exit 1
    fi

    cd "$project_dir"

    # Git pull if it's a git repo
    if [ -d ".git" ]; then
        log "Atualizando repositório..."
        git pull --ff-only && ok "Git pull concluído" || warn "Git pull falhou (verifique manualmente)"
    else
        warn "Não é um repositório git, pulando git pull"
    fi

    # Docker compose build and up
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        log "Construindo e iniciando containers..."
        docker compose up -d --build && ok "Containers iniciados" || { err "Falha ao iniciar containers"; exit 1; }

        log "Removendo imagens não utilizadas..."
        docker image prune -f && ok "Prune concluído"

        echo ""
        log "Status dos containers:"
        docker compose ps

        echo ""
        log "Logs recentes (últimas 20 linhas):"
        docker compose logs --tail=20
    else
        err "Nenhum docker-compose.yml encontrado em $project_dir"
        exit 1
    fi

    echo ""
    ok "Deploy de '$project' concluído!"
}

# Main
if [ $# -eq 0 ]; then
    list_projects
    echo ""
    echo "Uso: $0 <nome-do-projeto>"
    exit 0
fi

deploy "$1"
