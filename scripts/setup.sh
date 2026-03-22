#!/bin/bash
# ============================================================
# ID MANAGEMENT SYSTEM — Full Setup Script
# Run as: bash scripts/setup.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   SchoolID Pro — Setup Script            ║${NC}"
echo -e "${CYAN}║   Oracle Cloud Always Free               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Check prerequisites ──────────────────────────────
info "Checking prerequisites..."
command -v docker      >/dev/null 2>&1 || err "Docker not found. Install Docker first."
command -v docker-compose >/dev/null 2>&1 || \
  docker compose version >/dev/null 2>&1   || \
  err "Docker Compose not found."
log "Docker and Docker Compose found"

# ── Step 2: Install Flutter (if not present) ─────────────────
if ! command -v flutter &>/dev/null; then
  warn "Flutter not found. Installing Flutter SDK..."
  sudo apt-get update -qq
  sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa

  FLUTTER_VERSION="3.24.0"
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

  curl -sL "$FLUTTER_URL" -o /tmp/flutter.tar.xz
  sudo tar -xf /tmp/flutter.tar.xz -C /opt/
  sudo ln -sf /opt/flutter/bin/flutter /usr/local/bin/flutter
  rm /tmp/flutter.tar.xz

  flutter doctor --android-licenses 2>/dev/null || true
  log "Flutter ${FLUTTER_VERSION} installed"
else
  log "Flutter already installed: $(flutter --version | head -1)"
fi

# ── Step 3: Create .env file ──────────────────────────────────
cd "$PROJECT_DIR"

if [ ! -f .env ]; then
  warn ".env not found, copying from .env.example"
  cp .env.example .env
  warn "IMPORTANT: Edit .env with your Firebase and MSG91 credentials before starting"
  warn "File: $PROJECT_DIR/.env"
  echo ""
fi

# ── Step 4: Build Flutter Web ─────────────────────────────────
info "Building Flutter Web app (base-href: /idmgmt/)..."
cd "$PROJECT_DIR/flutter_app"

flutter pub get
flutter build web \
  --release \
  --base-href /idmgmt/ \
  --web-renderer canvaskit \
  2>&1 | tail -5

log "Flutter web build complete → flutter_app/build/web/"

# ── Step 5: Start Docker services ────────────────────────────
cd "$PROJECT_DIR"
info "Starting ID Management services..."

# Use docker-compose or docker compose
if command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  DC="docker compose"
fi

$DC up -d --build

log "Services started. Waiting for health checks..."
sleep 15

# ── Step 6: Verify services ───────────────────────────────────
info "Checking service health..."
MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' idmgmt_db 2>/dev/null || echo "not found")
  if [ "$STATUS" = "healthy" ]; then
    log "Database is healthy"
    break
  fi
  echo -n "."
  sleep 5
  WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
  warn "Database health check timed out. Check: docker logs idmgmt_db"
fi

# ── Step 7: Reload nginx ──────────────────────────────────────
info "Reloading nginx with new /idmgmt routes..."
docker exec trading_nginx nginx -t 2>&1 && \
  docker exec trading_nginx nginx -s reload && \
  log "Nginx reloaded successfully" || \
  err "Nginx config test failed. Check: docker exec trading_nginx nginx -t"

# ── Step 8: Summary ──────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🚀 ID Management System is LIVE!                  ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Web App:    https://80.225.246.32.nip.io/idmgmt            ║${NC}"
echo -e "${CYAN}║  API:        https://80.225.246.32.nip.io/idmgmt/api        ║${NC}"
echo -e "${CYAN}║  API Health: https://80.225.246.32.nip.io/idmgmt/api/health ║${NC}"
echo -e "${CYAN}║  DB Admin:   localhost:3307 (MySQL)                  ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Existing app still runs at: https://80.225.246.32.nip.io  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}Sample credentials (Delhi Public School):${NC}"
echo -e "  Principal RKP: principal@dps-rkpuram.edu.in"
echo -e "  Principal Rohini: principal@dps-rohini.edu.in"
echo ""
echo -e "  ${YELLOW}Useful commands:${NC}"
echo -e "  docker logs idmgmt_backend -f   # Backend logs"
echo -e "  docker logs idmgmt_db           # DB logs"
echo -e "  docker-compose ps               # Service status"
echo ""
