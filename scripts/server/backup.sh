#!/bin/bash
set -euo pipefail

BACKUP_DIR="$HOME/server/backups"
BACKUP_LOG="$BACKUP_DIR/backup.log"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
WORK_DIR="$BACKUP_DIR/tmp_$TIMESTAMP"
RETENTION_DAYS=7

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${CYAN}[backup]${NC} $1"
    echo "$msg" >> "$BACKUP_LOG"
}

ok() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $1"
    echo -e "${GREEN}[  OK  ]${NC} $1"
    echo "$msg" >> "$BACKUP_LOG"
}

err() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$msg" >> "$BACKUP_LOG"
}

mkdir -p "$BACKUP_DIR" "$WORK_DIR"

log "=== Início do backup $TIMESTAMP ==="

# 1. PostgreSQL dump
log "Dump do PostgreSQL..."
DOCKER_BIN="/usr/local/bin/docker"
if "$DOCKER_BIN" ps --format '{{.Names}}' 2>/dev/null | grep -qi postgres; then
    POSTGRES_CONTAINER=$("$DOCKER_BIN" ps --format '{{.Names}}' | grep -i postgres | head -1)
    "$DOCKER_BIN" exec "$POSTGRES_CONTAINER" pg_dumpall -U admin > "$WORK_DIR/postgres_dump.sql" 2>/dev/null \
        && ok "PostgreSQL dump via Docker concluído" \
        || err "Falha no dump do PostgreSQL via Docker"
else
    err "PostgreSQL não disponível (container não encontrado), pulando dump"
fi

# 2. Redis snapshot
log "Snapshot do Redis..."
if command -v redis-cli &>/dev/null; then
    redis-cli BGSAVE &>/dev/null && sleep 2
    REDIS_DIR=$(redis-cli CONFIG GET dir 2>/dev/null | tail -1)
    if [ -f "$REDIS_DIR/dump.rdb" ]; then
        cp "$REDIS_DIR/dump.rdb" "$WORK_DIR/redis_dump.rdb"
        ok "Redis snapshot concluído"
    else
        err "Arquivo dump.rdb não encontrado"
    fi
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -qi redis; then
    REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i redis | head -1)
    docker exec "$REDIS_CONTAINER" redis-cli BGSAVE &>/dev/null && sleep 2
    docker cp "$REDIS_CONTAINER:/data/dump.rdb" "$WORK_DIR/redis_dump.rdb" 2>/dev/null \
        && ok "Redis snapshot via Docker concluído" \
        || err "Falha no snapshot do Redis via Docker"
else
    err "Redis não disponível, pulando snapshot"
fi

# 3. OpenClaw config backup
log "Backup das configs do OpenClaw..."
if [ -d "$HOME/.openclaw" ]; then
    cp -r "$HOME/.openclaw" "$WORK_DIR/openclaw_config"
    ok "Config do OpenClaw copiada"
else
    err "Diretório ~/.openclaw não encontrado, pulando"
fi

# 4. Backup app configs (docker-compose files, .env, etc.)
log "Backup dos configs de apps..."
if [ -d "$HOME/server/apps" ]; then
    mkdir -p "$WORK_DIR/app_configs"
    for app_dir in "$HOME/server/apps"/*/; do
        [ -d "$app_dir" ] || continue
        app_name=$(basename "$app_dir")
        mkdir -p "$WORK_DIR/app_configs/$app_name"
        for f in docker-compose.yml docker-compose.yaml .env Dockerfile; do
            [ -f "$app_dir/$f" ] && cp "$app_dir/$f" "$WORK_DIR/app_configs/$app_name/"
        done
    done
    ok "Configs de apps copiadas"
fi

# 5. Compress everything
log "Comprimindo backup..."
ARCHIVE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$BACKUP_DIR" "tmp_$TIMESTAMP"
rm -rf "$WORK_DIR"
ARCHIVE_SIZE=$(du -h "$ARCHIVE" | cut -f1)
ok "Backup comprimido: $ARCHIVE ($ARCHIVE_SIZE)"

# 6. Remove old backups
log "Removendo backups com mais de $RETENTION_DAYS dias..."
REMOVED=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -print -delete 2>/dev/null | wc -l | tr -d ' ')
ok "$REMOVED backup(s) antigo(s) removido(s)"

log "=== Backup concluído: $ARCHIVE ==="
echo ""
echo "Arquivo: $ARCHIVE"
echo "Tamanho: $ARCHIVE_SIZE"
