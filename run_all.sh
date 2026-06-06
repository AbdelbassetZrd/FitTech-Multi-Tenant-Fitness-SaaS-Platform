#!/usr/bin/env bash
# =============================================================================
# FitTech — Run All Services
# Starts: MySQL (Docker), Django backend, Next.js frontend,
#         FitTech mobile app, Coach mobile app
# Usage:  ./run_all.sh [--no-mobile] [--no-docker]
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOG_DIR"

# ── Flags ────────────────────────────────────────────────────────────────────
NO_MOBILE=false
NO_DOCKER=false
for arg in "$@"; do
  case $arg in
    --no-mobile) NO_MOBILE=true ;;
    --no-docker) NO_DOCKER=true ;;
  esac
done

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}✓${NC}  $1"; }
warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; }
info()  { echo -e "${BLUE}→${NC}  $1"; }
title() { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

# ── Dependency check ─────────────────────────────────────────────────────────
title "Checking dependencies"

check_dep() {
  if command -v "$1" &>/dev/null; then
    log "$1 found ($(command -v "$1"))"
  else
    error "$1 not found — please install it before running this script."
    exit 1
  fi
}

check_dep docker
check_dep python3
check_dep node
check_dep npm
if [ "$NO_MOBILE" = false ]; then
  check_dep flutter
fi
check_dep ngrok

# ── Open terminal helper ──────────────────────────────────────────────────────
# Opens a new terminal window/tab for each service.
# Priority: gnome-terminal → xterm → background process
open_terminal() {
  local title="$1"
  local log_file="$2"
  local cmd="$3"

  if command -v gnome-terminal &>/dev/null; then
    gnome-terminal \
      --title="$title" \
      -- bash -c "$cmd 2>&1 | tee '$log_file'; echo -e '\n[Process exited — press Enter to close]'; read" &
  elif command -v xterm &>/dev/null; then
    xterm -title "$title" \
      -e bash -c "$cmd 2>&1 | tee '$log_file'; echo '[Process exited]'; read" &
  else
    warn "No graphical terminal found. Running '$title' in background (logs → $log_file)"
    bash -c "$cmd" >"$log_file" 2>&1 &
    echo $! >> "$ROOT_DIR/.fittech.pids"
  fi

  sleep 0.5
}

# ── 1. MySQL via Docker ───────────────────────────────────────────────────────
if [ "$NO_DOCKER" = false ]; then
  title "Starting MySQL (Docker)"
  cd "$ROOT_DIR/backend"

  if docker compose ps --quiet mysql 2>/dev/null | grep -q .; then
    warn "MySQL container already running — skipping."
  else
    docker compose up -d
    log "MySQL container started (host port 3308)"
    info "Waiting 3s for MySQL to be ready..."
    sleep 3
  fi
fi

# ── 2. Django Backend ─────────────────────────────────────────────────────────
title "Starting Django Backend"

BACKEND_CMD="
  echo '── Django Backend ──'
  cd '$ROOT_DIR/backend'
  if [ ! -d venv ]; then
    echo 'Creating virtual environment...'
    python3 -m venv venv    cd /home/abdelbasset/Desktop/bbrahim/backend
    docker-compose ps
    docker-compose logs db --follow --tail=200
    source venv/bin/activate
    pip install -r requirements.txt
  else
    source venv/bin/activate
  fi
  python manage.py migrate --no-input
  python manage.py runserver 0.0.0.0:8000
"

open_terminal "FitTech · Backend (Django :8000)" \
  "$LOG_DIR/backend.log" \
  "$BACKEND_CMD"

log "Backend window opened  →  http://127.0.0.1:8000"
info "API docs will be at    →  http://127.0.0.1:8000/swagger/"

# ── 2b. Ngrok Tunnel (Auto-capture URL) ───────────────────────────────────────────
title "Starting Ngrok Tunnel (Auto-URL)"

# Start ngrok in background
(
  echo '── Ngrok starting ──' > "$LOG_DIR/ngrok.log"
  cd "$ROOT_DIR"
  ngrok http 8000 --log stdout >> "$LOG_DIR/ngrok.log" 2>&1 &
  NGROK_PID=$!
  echo $NGROK_PID > "$LOG_DIR/ngrok.pid"

  # Wait for ngrok API to be ready
  sleep 5

  # Poll for public URL (max 30s)
  for i in {1..30}; do
    sleep 1
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
    if [ -n "$PUBLIC_URL" ]; then
      echo "✓ Ngrok URL: $PUBLIC_URL" >> "$LOG_DIR/ngrok.log"

      # Update Flutter constants file
      DART_FILE="$ROOT_DIR/mobile/fittech/lib/core/constants/app_constants.dart"
      if [ -f "$DART_FILE" ]; then
        sed -i "s|static const String ngrokBaseUrl = 'https://[^']*'|static const String ngrokBaseUrl = '$PUBLIC_URL'|" "$DART_FILE"
        echo "✓ Updated AppConstants.ngrokBaseUrl in Dart file" >> "$LOG_DIR/ngrok.log"
      fi

      echo "$PUBLIC_URL" > "$LOG_DIR/ngrok_url.txt"
      break
    fi
  done

  if [ -z "$PUBLIC_URL" ]; then
    echo "✗ Failed to capture ngrok URL" >> "$LOG_DIR/ngrok.log"
  fi

  wait $NGROK_PID
) &

sleep 2
log "Ngrok starting in background (PID saved)"
info "URL will be auto-captured and saved to .logs/ngrok_url.txt"
info "Flutter constants will be updated automatically"

# ── 3. Next.js Frontend ───────────────────────────────────────────────────────
title "Starting Next.js Frontend"

FRONTEND_CMD="
  echo '── Next.js Frontend ──'
  cd '$ROOT_DIR/frontend'
  npm install --silent
  npm run dev
"

open_terminal "FitTech · Frontend (Next.js :3000)" \
  "$LOG_DIR/frontend.log" \
  "$FRONTEND_CMD"

log "Frontend window opened  →  http://localhost:3000"

# ── 4 & 5. Flutter Mobile Apps ───────────────────────────────────────────────
if [ "$NO_MOBILE" = false ]; then

  # Wait for ngrok URL to be ready (max 35s total)
  info "Waiting for ngrok URL..."
  for i in {1..35}; do
    if [ -f "$LOG_DIR/ngrok_url.txt" ]; then
      NGROK_READY=$(cat "$LOG_DIR/ngrok_url.txt" 2>/dev/null)
      if [ -n "$NGROK_READY" ]; then
        log "Ngrok URL ready: $NGROK_READY"
        break
      fi
    fi
    sleep 1
  done

  title "Starting Flutter — FitTech (User App)"

  FITTECH_CMD="
    echo '── FitTech Mobile App ──'
    cd '$ROOT_DIR/mobile/fittech'
    flutter pub get
    flutter run
  "

  open_terminal "FitTech · Mobile — FitTech App" \
    "$LOG_DIR/mobile_fittech.log" \
    "$FITTECH_CMD"

  log "FitTech mobile window opened  (pick device inside that terminal)"

  title "Starting Flutter — Coach App"

  COACH_CMD="
    echo '── Coach Mobile App ──'
    cd '$ROOT_DIR/mobile/fittech coach/coach'
    flutter pub get
    flutter run -d linux
  "

  open_terminal "FitTech · Mobile — Coach App" \
    "$LOG_DIR/mobile_coach.log" \
    "$COACH_CMD"

  log "Coach mobile window opened  (pick device inside that terminal)"

else
  warn "Mobile apps skipped (--no-mobile flag)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║       All FitTech services started!       ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Backend  API ${NC} →  http://127.0.0.1:8000"
echo -e "  ${CYAN}Swagger  UI  ${NC} →  http://127.0.0.1:8000/swagger/"
echo -e "  ${CYAN}Frontend     ${NC} →  http://localhost:3000"
NGROK_URL=$(cat "$LOG_DIR/ngrok_url.txt" 2>/dev/null || echo 'Starting...')
echo -e "  ${CYAN}Ngrok Tunnel ${NC} →  $NGROK_URL"
echo -e "  ${GREEN}              Auto-updated in Flutter app_constants.dart${NC}"
if [ "$NO_MOBILE" = false ]; then
  echo -e "  ${CYAN}Mobile Apps  ${NC} →  (requires device/emulator — check terminal windows)"
fi
echo ""
echo -e "  ${YELLOW}Logs saved in .logs/ directory${NC}"
echo -e "  ${YELLOW}Run ./stop_all.sh to stop all services${NC}"
echo ""
