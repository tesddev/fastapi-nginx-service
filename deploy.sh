#!/usr/bin/env bash
# deploy.sh — Stage 1 FastAPI + Nginx Deployment
# Runs FROM your Mac, SSHes into the EC2 server, and deploys everything.
# Domain: tes-devops.duckdns.org | SSH Port: 2247 | User: deploy

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────
SERVER_IP="52.215.88.152"
SSH_PORT=22
SSH_USER="deploy"
SSH_KEY="$HOME/.ssh/devops-stage0"
DOMAIN="tes-script-devops.duckdns.org"

APP_NAME="fastapi-nginx-service"
REPO_URL="https://github.com/tesddev/fastapi-nginx-service.git"
REMOTE_APP_DIR="/home/$SSH_USER/$APP_NAME"
VENV_DIR="$REMOTE_APP_DIR/venv"
SERVICE_NAME="fastapi-app"
UVICORN_PORT=8000
# ──────────────────────────────────────────────────────────────────────

SSH_CMD="ssh -i $SSH_KEY -p $SSH_PORT -o StrictHostKeyChecking=accept-new $SSH_USER@$SERVER_IP"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ── Pre-flight check ─────────────────────────────────────────────────
log "Testing SSH connectivity to $SSH_USER@$SERVER_IP:$SSH_PORT ..."
if ! $SSH_CMD "echo 'SSH OK'" 2>/dev/null; then
  echo "ERROR: Cannot SSH into the server. Check your key, IP, and port."
  exit 1
fi
log "SSH connection successful."

# ══════════════════════════════════════════════════════════════════════
# 2a — Install system dependencies
# ══════════════════════════════════════════════════════════════════════
log "2a — Installing system dependencies ..."
$SSH_CMD "sudo bash -s" <<'REMOTE_2A'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y python3 python3-venv python3-pip git nginx curl certbot python3-certbot-nginx

echo "System dependencies installed."
REMOTE_2A

# ══════════════════════════════════════════════════════════════════════
# 2b — Clone / update the application repo
# ══════════════════════════════════════════════════════════════════════
log "2b — Cloning / updating application repo ..."
$SSH_CMD "bash -s" <<REMOTE_2B
set -euo pipefail

if [ -d "$REMOTE_APP_DIR/.git" ]; then
  echo "Repo exists — pulling latest ..."
  cd "$REMOTE_APP_DIR"
  git fetch origin
  git reset --hard origin/main
else
  echo "Cloning repo ..."
  git clone "$REPO_URL" "$REMOTE_APP_DIR"
fi

echo "App repo ready at $REMOTE_APP_DIR"
REMOTE_2B

# ══════════════════════════════════════════════════════════════════════
# 2c — Set up Python virtualenv and install dependencies
# ══════════════════════════════════════════════════════════════════════
log "2c — Setting up Python virtualenv ..."
$SSH_CMD "bash -s" <<REMOTE_2C
set -euo pipefail

cd "$REMOTE_APP_DIR"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
  echo "Created virtualenv at $VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt

echo "Python dependencies installed."
REMOTE_2C

# ══════════════════════════════════════════════════════════════════════
# 2d — Create systemd service for Uvicorn
# ══════════════════════════════════════════════════════════════════════
log "2d — Creating systemd service ..."
$SSH_CMD "sudo bash -s" <<REMOTE_2D
set -euo pipefail

cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=FastAPI App (Uvicorn) — Stage 1
After=network.target

[Service]
User=$SSH_USER
Group=$SSH_USER
WorkingDirectory=$REMOTE_APP_DIR
ExecStart=$VENV_DIR/bin/uvicorn main:app --host 127.0.0.1 --port $UVICORN_PORT
Restart=always
RestartSec=3
Environment=PATH=$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo "systemd service '$SERVICE_NAME' is running."
REMOTE_2D

# ══════════════════════════════════════════════════════════════════════
# 2e — Configure Nginx as reverse proxy
# ══════════════════════════════════════════════════════════════════════
log "2e — Configuring Nginx reverse proxy ..."
$SSH_CMD "sudo bash -s" <<REMOTE_2E
set -euo pipefail

cat > /etc/nginx/sites-available/$APP_NAME <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$UVICORN_PORT;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
}
EOF

# Enable the new site, remove old default/stage0 if they conflict
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

echo "Nginx configured as reverse proxy to Uvicorn on port $UVICORN_PORT."
REMOTE_2E

# ══════════════════════════════════════════════════════════════════════
# 2f — Re-run Certbot for SSL (if certificate exists, just reload)
# ══════════════════════════════════════════════════════════════════════
log "2f — Ensuring SSL certificate ..."
$SSH_CMD "sudo bash -s" <<REMOTE_2F
set -euo pipefail

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "SSL certificate already exists for $DOMAIN — re-running certbot to update nginx config ..."
  certbot --nginx -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "tesleem.amuda@gmail.com" \
    --redirect \
    --reinstall
else
  echo "Requesting new certificate for $DOMAIN ..."
  certbot --nginx -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "tesleem.amuda@gmail.com" \
    --redirect
fi

systemctl reload nginx
echo "SSL configured for $DOMAIN."
REMOTE_2F

# ══════════════════════════════════════════════════════════════════════
# 2g — Smoke test
# ══════════════════════════════════════════════════════════════════════
log "2g — Running smoke tests ..."

echo ""
echo "────────────────────────────────────────────────────────"
echo "  Testing endpoints on https://$DOMAIN"
echo "────────────────────────────────────────────────────────"

PASS=0
FAIL=0

test_endpoint() {
  local path="$1"
  local url="https://$DOMAIN$path"
  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")

  if [ "$status" = "200" ]; then
    echo "  ✅  $url → $status"
    PASS=$((PASS + 1))
  else
    echo "  ❌  $url → $status"
    FAIL=$((FAIL + 1))
  fi
}

test_endpoint "/"
test_endpoint "/health"
test_endpoint "/me"

echo ""
echo "────────────────────────────────────────────────────────"
echo "  Results: $PASS passed, $FAIL failed"
echo "────────────────────────────────────────────────────────"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  log "⚠️  Some endpoints failed. Check the service status:"
  echo "  $SSH_CMD 'sudo systemctl status $SERVICE_NAME'"
  echo "  $SSH_CMD 'sudo journalctl -u $SERVICE_NAME --no-pager -n 30'"
  exit 1
fi

echo ""
log "🚀 Deployment successful!"
log "   Live URL:   https://$DOMAIN"
log "   Health:     https://$DOMAIN/health"
log "   /me:        https://$DOMAIN/me"
log "   SSH cmd:    ssh -i ~/.ssh/devops-stage0 -p $SSH_PORT $SSH_USER@$SERVER_IP"
