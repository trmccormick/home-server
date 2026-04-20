#!/usr/bin/env bash
# =============================================================================
# setup.sh – Bootstrap the Raspberry Pi 4 Home Server
# =============================================================================
# Run once on a fresh Raspberry Pi OS (64-bit) installation:
#   chmod +x setup.sh && sudo ./setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${DATA_DIR:-/mnt/data}"

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Root check ─────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || error "Please run as root (sudo ./setup.sh)"

# ── 1. System update ───────────────────────────────────────────────────────────
info "Updating system packages…"
apt-get update -qq
apt-get upgrade -y -qq

# ── 2. Install Docker ──────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  info "Installing Docker…"
  # NOTE: Review the script at https://get.docker.com before running in production.
  curl -fsSL https://get.docker.com | sh
  # Add the first non-root user to the docker group
  SUDO_USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
  if [[ -n "$SUDO_USER_NAME" ]]; then
    usermod -aG docker "$SUDO_USER_NAME"
    info "Added '${SUDO_USER_NAME}' to the docker group (re-login required)"
  fi
else
  info "Docker already installed – skipping"
fi

# ── 3. Install Docker Compose v2 plugin ───────────────────────────────────────
if ! docker compose version &>/dev/null; then
  info "Installing Docker Compose plugin…"
  apt-get install -y -qq docker-compose-plugin
else
  info "Docker Compose already available – skipping"
fi

# ── 4. Create data directories ────────────────────────────────────────────────
info "Creating data directories under ${DATA_DIR}…"
mkdir -p \
  "${DATA_DIR}/duckdns/config" \
  "${DATA_DIR}/jellyfin/config" \
  "${DATA_DIR}/media/movies" \
  "${DATA_DIR}/media/tv" \
  "${DATA_DIR}/media/music" \
  "${DATA_DIR}/shared" \
  "${DATA_DIR}/samba/config" \
  "${DATA_DIR}/pihole/etc-pihole" \
  "${DATA_DIR}/pihole/etc-dnsmasq.d" \
  "${DATA_DIR}/postgres/data" \
  "${DATA_DIR}/open-webui"

PUID="${SUDO_USER:+$(id -u "$SUDO_USER")}"
PUID="${PUID:-1000}"
PGID="${SUDO_USER:+$(id -g "$SUDO_USER")}"
PGID="${PGID:-1000}"
chown -R "${PUID}:${PGID}" "${DATA_DIR}"

# ── 5. Copy Samba config ──────────────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/config/samba/smb.conf" ]]; then
  info "Copying Samba configuration…"
  cp "${SCRIPT_DIR}/config/samba/smb.conf" "${DATA_DIR}/samba/config/smb.conf"
fi

# ── 6. Copy Pi-hole custom DNS ────────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/config/pihole/custom.list" ]]; then
  info "Copying Pi-hole custom DNS list…"
  cp "${SCRIPT_DIR}/config/pihole/custom.list" "${DATA_DIR}/pihole/etc-pihole/custom.list"
fi

# ── 7. Create .env from example if not already present ───────────────────────
if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
  if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    warn ".env created from .env.example – please edit it before starting services!"
  fi
else
  info ".env already exists – skipping"
fi

# ── 8. Disable systemd-resolved stub listener (conflicts with Pi-hole on :53) ─
if systemctl is-active --quiet systemd-resolved; then
  info "Disabling systemd-resolved stub listener (required for Pi-hole)…"
  sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
  sed -i 's/DNSStubListener=yes/DNSStubListener=no/'  /etc/systemd/resolved.conf
  systemctl restart systemd-resolved
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Edit .env with your real values:"
echo "       nano ${SCRIPT_DIR}/.env"
echo "  2. Start all services:"
echo "       cd ${SCRIPT_DIR} && docker compose up -d"
echo "  3. Access services:"
echo "       Jellyfin:    http://<pi-ip>:8096"
echo "       Pi-hole:     http://<pi-ip>:8080/admin"
echo "       Open WebUI:  http://<pi-ip>:3000"
echo ""
