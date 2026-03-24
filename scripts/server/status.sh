#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

divider() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
header()  { divider; echo -e "${BOLD} $1${NC}"; divider; }

# 1. Uptime
header "UPTIME"
uptime

# 2. Docker Containers
header "DOCKER CONTAINERS"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    RUNNING=$(docker ps -q | wc -l | tr -d ' ')
    TOTAL=$(docker ps -aq | wc -l | tr -d ' ')
    echo -e "Containers: ${GREEN}$RUNNING rodando${NC} / $TOTAL total"
    echo ""
    if [ "$TOTAL" -gt 0 ]; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    else
        echo "Nenhum container encontrado."
    fi
else
    echo -e "${YELLOW}Docker não está rodando ou não instalado${NC}"
fi

# 3. Disk Usage
header "USO DE DISCO"
df -h / "$HOME" 2>/dev/null | awk 'NR==1 || /\/$/ || /\/Users/'
echo ""
if [ -d "$HOME/server" ]; then
    echo "Diretório ~/server:"
    du -sh "$HOME/server"/*/ 2>/dev/null | sort -rh
fi

# 4. Memory Usage
header "USO DE MEMÓRIA"
# macOS uses vm_stat
if command -v vm_stat &>/dev/null; then
    PAGE_SIZE=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
    VM=$(vm_stat)
    FREE=$(echo "$VM" | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
    ACTIVE=$(echo "$VM" | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
    INACTIVE=$(echo "$VM" | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
    WIRED=$(echo "$VM" | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
    TOTAL_MEM=$(sysctl -n hw.memsize 2>/dev/null)

    if [ -n "$TOTAL_MEM" ]; then
        TOTAL_GB=$(echo "scale=1; $TOTAL_MEM / 1073741824" | bc)
        USED_PAGES=$((ACTIVE + WIRED))
        USED_BYTES=$((USED_PAGES * PAGE_SIZE))
        USED_GB=$(echo "scale=1; $USED_BYTES / 1073741824" | bc)
        FREE_GB=$(echo "scale=1; $TOTAL_GB - $USED_GB" | bc)
        PCT=$(echo "scale=0; $USED_GB * 100 / $TOTAL_GB" | bc)
        echo "Total: ${TOTAL_GB}GB | Usado: ${USED_GB}GB | Livre: ${FREE_GB}GB | ${PCT}%"
    fi
else
    free -h 2>/dev/null || echo "Informação de memória indisponível"
fi

# 5. OpenClaw Status
header "OPENCLAW"
if [ -d "$HOME/.openclaw" ] || docker ps --format '{{.Names}}' 2>/dev/null | grep -qi openclaw; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qi openclaw; then
        echo -e "${GREEN}OpenClaw está rodando via Docker${NC}"
        docker ps --filter "name=openclaw" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    elif pgrep -f openclaw &>/dev/null; then
        echo -e "${GREEN}OpenClaw está rodando (processo local)${NC}"
    else
        echo -e "${YELLOW}OpenClaw configurado mas não está rodando${NC}"
    fi
else
    echo -e "${YELLOW}OpenClaw não instalado${NC}"
fi

# 6. Network (listening ports)
header "PORTAS EM USO"
lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==1 || /LISTEN/' | head -20 || echo "Sem informação de portas"

# 7. Last backup
header "ÚLTIMO BACKUP"
LAST_BACKUP=$(ls -t "$HOME/server/backups"/backup_*.tar.gz 2>/dev/null | head -1)
if [ -n "$LAST_BACKUP" ]; then
    SIZE=$(du -h "$LAST_BACKUP" | cut -f1)
    DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LAST_BACKUP" 2>/dev/null || stat --format="%y" "$LAST_BACKUP" 2>/dev/null | cut -d. -f1)
    echo "Arquivo: $(basename "$LAST_BACKUP")"
    echo "Data:    $DATE"
    echo "Tamanho: $SIZE"
else
    echo -e "${YELLOW}Nenhum backup encontrado${NC}"
fi

divider
echo -e "${BOLD} Relatório gerado em $(date '+%Y-%m-%d %H:%M:%S')${NC}"
