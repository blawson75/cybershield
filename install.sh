#!/usr/bin/env bash
# ============================================================
# CyberShield Install Script
# Deploy CyberShield to an Ubuntu server with nginx
# ============================================================
set -euo pipefail

# --- Configuration ---
REPO_URL="https://github.com/blawson75/cybershield.git"
INSTALL_DIR="${INSTALL_DIR:-/opt/cybershield}"
VENV_DIR="${VENV_DIR:-/opt/cybershield/venv}"
APP_USER="${APP_USER:-cybershield}"
APP_PORT="${APP_PORT:-5000}"
NGINX_SITES_DIR="${NGINX_SITES_DIR:-/etc/nginx/sites-available}"
NGINX_ENABLED_DIR="${NGINX_ENABLED_DIR:-/etc/nginx/sites-enabled}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }
die()  { err "$*"; exit 1; }

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root (sudo $0)"
fi

# --- Step 1: Install system dependencies ---
log "Updating package list..."
apt-get update -qq

log "Installing system dependencies..."
apt-get install -y -qq \
    python3 \
    python3-venv \
    python3-pip \
    nginx \
    git \
    curl > /dev/null

# --- Step 2: Create application user ---
if ! id "$APP_USER" &>/dev/null; then
    log "Creating system user '$APP_USER'..."
    useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$APP_USER"
else
    log "User '$APP_USER' already exists."
fi

# --- Step 3: Clone repository ---
log "Cloning repository to $INSTALL_DIR..."
if [[ -d "$INSTALL_DIR" ]]; then
    warn "Directory $INSTALL_DIR already exists. Removing and re-cloning..."
    rm -rf "$INSTALL_DIR"
fi
git clone "$REPO_URL" "$INSTALL_DIR"
chown -R "$APP_USER":"$APP_USER" "$INSTALL_DIR"

# --- Step 4: Set up Python virtual environment ---
log "Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
chown -R "$APP_USER":"$APP_USER" "$VENV_DIR"

log "Installing Python dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip -qq
pip install -r "$INSTALL_DIR/requirements.txt" -qq
deactivate
chown -R "$APP_USER":"$APP_USER" "$VENV_DIR"

# --- Step 5: Configure systemd service ---
log "Installing systemd service..."
cp "$INSTALL_DIR/cybershield.service" /etc/systemd/system/cybershield.service
sed -i "s|/opt/cybershield|$INSTALL_DIR|g" /etc/systemd/system/cybershield.service
sed -i "s|/opt/cybershield/venv|$VENV_DIR|g" /etc/systemd/system/cybershield.service

systemctl daemon-reload
systemctl enable cybershield

# --- Step 6: Configure nginx ---
log "Configuring nginx..."
cp "$INSTALL_DIR/nginx-site.conf" "$NGINX_SITES_DIR/cybershield"
sed -i "s|/opt/cybershield|$INSTALL_DIR|g" "$NGINX_SITES_DIR/cybershield"
sed -i "s|5000|$APP_PORT|g" "$NGINX_SITES_DIR/cybershield"

# Enable site (remove default if present)
rm -f "$NGINX_ENABLED_DIR/default"
ln -sf "$NGINX_SITES_DIR/cybershield" "$NGINX_ENABLED_DIR/cybershield"

# --- Step 7: Start services ---
log "Starting CyberShield service..."
systemctl restart cybershield
sleep 2

log "Reloading nginx..."
systemctl reload nginx

# --- Step 8: Verify ---
log "Verifying installation..."
if systemctl is-active --quiet cybershield; then
    log "CyberShield service is running."
else
    warn "CyberShield service failed to start. Check logs: journalctl -u cybershield"
fi

if systemctl is-active --quiet nginx; then
    log "Nginx is running."
else
    warn "Nginx failed to start."
fi

# --- Step 9: Test endpoints ---
log "Testing backend..."
if curl -sf "http://127.0.0.1:${APP_PORT}/api/brokers" > /dev/null 2>&1; then
    log "Backend API is responding on port ${APP_PORT}."
else
    warn "Backend API not responding yet. Check: journalctl -u cybershield -n 50"
fi

# --- Done ---
log ""
log "============================================"
log "  CyberShield installed successfully!"
log "============================================"
log "  Web UI:   http://$(hostname -I | awk '{print $1}')"
log "  API:      http://$(hostname -I | awk '{print $1}'):${APP_PORT}/api/brokers"
log "  Logs:     journalctl -u cybershield -f"
log "  Status:   systemctl status cybershield"
log "  Config:   ${INSTALL_DIR}"
log "============================================"