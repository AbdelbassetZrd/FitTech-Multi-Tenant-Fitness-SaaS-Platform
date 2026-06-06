#!/usr/bin/env bash
# =============================================================================
# FitTech — Stop All Services
# Kills processes on ports 8000 & 3000, stops Docker MySQL container
# Usage:  ./stop_all.sh [--no-docker]
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC}  $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${CYAN}→${NC}  $1"; }

NO_DOCKER=false
for arg in "$@"; do
  [[ $arg == "--no-docker" ]] && NO_DOCKER=true
done

echo -e "\n${BOLD}Stopping FitTech services...${NC}\n"

# ── Kill port 8000 (Django) ───────────────────────────────────────────────────
info "Stopping Django backend (port 8000)..."
if fuser -k 8000/tcp 2>/dev/null; then
  log "Backend stopped."
else
  warn "Nothing running on port 8000."
fi

# ── Kill port 3000 (Next.js) ──────────────────────────────────────────────────
info "Stopping Next.js frontend (port 3000)..."
if fuser -k 3000/tcp 2>/dev/null; then
  log "Frontend stopped."
else
  warn "Nothing running on port 3000."
fi

# ── Kill Ngrok ────────────────────────────────────────────────────────────────
info "Stopping Ngrok tunnel..."
NGROK_PID_FILE="$ROOT_DIR/.logs/ngrok.pid"
if [ -f "$NGROK_PID_FILE" ]; then
  NGROK_PID=$(cat "$NGROK_PID_FILE" 2>/dev/null)
  if [ -n "$NGROK_PID" ] && kill -0 "$NGROK_PID" 2>/dev/null; then
    kill "$NGROK_PID" && log "Ngrok stopped (PID $NGROK_PID)."
  else
    warn "Ngrok process not found."
  fi
  rm -f "$NGROK_PID_FILE"
  rm -f "$ROOT_DIR/.logs/ngrok_url.txt"
else
  # Try to kill any ngrok process on port 4040 (ngrok web interface)
  if fuser -k 4040/tcp 2>/dev/null; then
    log "Ngrok stopped (port 4040)."
  else
    warn "No ngrok process found."
  fi
fi

# ── Kill any background PIDs saved by run_all.sh ─────────────────────────────
PID_FILE="$ROOT_DIR/.fittech.pids"
if [ -f "$PID_FILE" ]; then
  info "Stopping background processes..."
  while IFS= read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" && log "Killed PID $pid"
    fi
  done < "$PID_FILE"
  rm -f "$PID_FILE"
fi

# ── Stop Docker MySQL ─────────────────────────────────────────────────────────
if [ "$NO_DOCKER" = false ]; then
  info "Stopping MySQL Docker container..."
  cd "$ROOT_DIR/backend"
  if docker compose ps --quiet 2>/dev/null | grep -q .; then
    docker compose down
    log "MySQL container stopped."
  else
    warn "MySQL container is not running."
  fi
fi

echo ""
log "All FitTech services stopped."
echo ""
