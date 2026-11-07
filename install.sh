#!/usr/bin/env bash
set -euo pipefail
REPO_URL="https://github.com/blawson75/cybershield.git"
INSTALL_DIR="${INSTALL_DIR:-/opt/cybershield}"
VENV_DIR="${VENV_DIR:-/opt/cybershield/venv}"
APP_USER="${APP_USER:-cybershield}"
APP_PORT="${APP_PORT:-5000}"
WEB_SERVER="${WEB_SERVER:-auto}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }
die()  { err "$*"; exit 1; }
[[ $EUID -ne 0 ]] && die "Run as root (sudo $0)"
if command -v dnf &>/dev/null; then
    PM="dnf"; UPD="dnf update -y"; INST="dnf install -y"
    PKGS="python3 python3-pip git curl"
elif command -v apt-get &>/dev/null; then
    PM="apt"; UPD="apt-get update -qq"; INST="apt-get install -y -qq"
    PKGS="python3 python3-venv python3-pip git curl"
elif command -v yum &>/dev/null; then
    PM="yum"; UPD="yum update -y"; INST="yum install -y"
    PKGS="python3 python3-pip git curl"
else
    die "No package manager found (dnf, apt-get, or yum required)"
fi
log "Package manager: $PM"
$UPD
log "Installing base dependencies..."
$INST $PKGS
if ! id "$APP_USER" &>/dev/null; then
    log "Creating user $APP_USER..."
    useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$APP_USER" || \
    useradd --system --home "$INSTALL_DIR" --shell /sbin/nologin "$APP_USER"
else
    log "User $APP_USER already exists"
fi
log "Cloning repository..."
rm -rf "$INSTALL_DIR"
git clone "$REPO_URL" "$INSTALL_DIR"
chown -R "$APP_USER":"$APP_USER" "$INSTALL_DIR"
log "Creating virtual environment..."
python3 -m venv "$VENV_DIR"
chown -R "$APP_USER":"$APP_USER" "$VENV_DIR"
log "Installing Python dependencies..."
"$VENV_DIR/bin/pip" install --upgrade pip -qq
"$VENV_DIR/bin/pip" install -r "$INSTALL_DIR/requirements.txt" -qq
chown -R "$APP_USER":"$APP_USER" "$VENV_DIR"
log "Installing systemd service..."
cp "$INSTALL_DIR/cybershield.service" /etc/systemd/system/cybershield.service
sed -i "s|/opt/cybershield|$INSTALL_DIR|g" /etc/systemd/system/cybershield.service
sed -i "s|/opt/cybershield/venv|$VENV_DIR|g" /etc/systemd/system/cybershield.service
systemctl daemon-reload
systemctl enable cybershield
log "Detecting web server..."
if [[ "$WEB_SERVER" == "auto" ]]; then
    if command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
        WEB_SERVER="apache"
    elif command -v nginx &>/dev/null; then
        WEB_SERVER="nginx"
    else
        warn "No web server found, installing nginx..."
        $INST nginx
        WEB_SERVER="nginx"
    fi
fi
log "Using web server: $WEB_SERVER"
if [[ "$WEB_SERVER" == "nginx" ]]; then
    log "Installing nginx..."
    $INST nginx
    if [[ -d /etc/nginx/sites-available ]]; then
        cp "$INSTALL_DIR/nginx-site.conf" /etc/nginx/sites-available/cybershield
        sed -i "s|/opt/cybershield|$INSTALL_DIR|g" /etc/nginx/sites-available/cybershield
        sed -i "s|5000|$APP_PORT|g" /etc/nginx/sites-available/cybershield
        rm -f /etc/nginx/sites-enabled/default
        ln -sf /etc/nginx/sites-available/cybershield /etc/nginx/sites-enabled/cybershield
    elif [[ -f /etc/nginx/nginx.conf ]]; then
        cp "$INSTALL_DIR/nginx-site.conf" /etc/nginx/conf.d/cybershield.conf
        sed -i "s|/opt/cybershield|$INSTALL_DIR|g" /etc/nginx/conf.d/cybershield.conf
        sed -i "s|5000|$APP_PORT|g" /etc/nginx/conf.d/cybershield.conf
    fi
    systemctl restart nginx
elif [[ "$WEB_SERVER" == "apache" ]]; then
    if command -v apache2 &>/dev/null; then
        APACHE_CONF_DIR="/etc/apache2"
        APACHE_SITES="/etc/apache2/sites-available"
        APACHE_ENABLED="/etc/apache2/sites-enabled"
        $INST apache2
    else
        APACHE_CONF_DIR="/etc/httpd"
        APACHE_SITES="/etc/httpd/conf.d"
        APACHE_ENABLED="/etc/httpd/conf.d"
        $INST httpd
    fi
    cat > "$APACHE_SITES/cybershield.conf" << APACHE_EOF
Alias /opt/cybershield/frontend "$INSTALL_DIR/frontend"
<Directory "$INSTALL_DIR/frontend">
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
ProxyRequests Off
ProxyPass /api/ http://127.0.0.1:$APP_PORT/
ProxyPassReverse /api/ http://127.0.0.1:$APP_PORT/
APACHE_EOF
    if [[ -d "$APACHE_SITES" && -f "$APACHE_SITES/000-default.conf" ]]; then
        a2dissite 000-default 2>/dev/null || true
    fi
    a2enmod proxy proxy_http rewrite 2>/dev/null || true
    systemctl restart apache2 2>/dev/null || systemctl restart httpd
else
    die "Unknown web server: $WEB_SERVER (use nginx or apache)"
fi
log "Starting CyberShield service..."
systemctl restart cybershield
sleep 2
log "Verifying..."
systemctl is-active --quiet cybershield && log "CyberShield service running." || warn "CyberShield service failed"
if [[ "$WEB_SERVER" == "nginx" ]]; then
    systemctl is-active --quiet nginx && log "Nginx running." || warn "Nginx failed"
else
    systemctl is-active --quiet apache2 2>/dev/null && log "Apache running." || (systemctl is-active --quiet httpd && log "Apache running." || warn "Apache failed")
fi
curl -sf "http://127.0.0.1:${APP_PORT}/api/brokers" > /dev/null 2>&1 && log "API responding on port $APP_PORT." || warn "API not responding"
IP=$(hostname -I | awk '{print $1}')
log ""
log "============================================"
log "  CyberShield installed successfully!"
log "============================================"
log "  Web Server: $WEB_SERVER"
log "  Web UI:    http://$IP"
log "  API:       http://$IP:$APP_PORT/api/brokers"
log "  Logs:      journalctl -u cybershield -f"
log "  Status:    systemctl status cybershield"
log "  Config:    $INSTALL_DIR"
log "============================================"
