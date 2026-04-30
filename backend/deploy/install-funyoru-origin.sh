#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "run as root, for example: sudo deploy/install-funyoru-origin.sh" >&2
  exit 1
fi

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_USER="${APP_USER:-pixelsocial}"
APP_GROUP="${APP_GROUP:-pixelsocial}"
APP_ROOT="${APP_ROOT:-/opt/pixel-social-world}"
STATE_ROOT="${STATE_ROOT:-/var/lib/pixel-social-world}"
ENV_DIR="${ENV_DIR:-/etc/pixel-social-world}"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
}

require_file "$BUNDLE_DIR/backend/bin/pixel-social-world-server"
require_file "$BUNDLE_DIR/backend/bin/pixel-social-world-preflight"
require_file "$BUNDLE_DIR/backend/configs/production.yaml"
require_file "$BUNDLE_DIR/deploy/pixel-social-world.service"
require_file "$BUNDLE_DIR/deploy/pixel-social-world.env.example"
require_file "$BUNDLE_DIR/deploy/Caddyfile.funyoru.example"
require_file "$BUNDLE_DIR/deploy/cloudflared-funyoru.yml.example"
require_file "$BUNDLE_DIR/web/index.html"
require_file "$BUNDLE_DIR/web/index.wasm"
require_file "$BUNDLE_DIR/web/index.pck"

if ! getent group "$APP_GROUP" >/dev/null; then
  groupadd --system "$APP_GROUP"
fi

if ! id -u "$APP_USER" >/dev/null 2>&1; then
  useradd \
    --system \
    --gid "$APP_GROUP" \
    --home-dir "$STATE_ROOT" \
    --shell /usr/sbin/nologin \
    "$APP_USER"
fi

install -d -m 0755 "$APP_ROOT/backend/bin" "$APP_ROOT/backend/configs" "$APP_ROOT/configs" "$APP_ROOT/web"
install -d -m 0750 -o "$APP_USER" -g "$APP_GROUP" "$STATE_ROOT/creator_packages" "$STATE_ROOT/creator_runtime"
install -d -m 0750 -g "$APP_GROUP" "$ENV_DIR"

install -m 0755 "$BUNDLE_DIR/backend/bin/pixel-social-world-server" "$APP_ROOT/backend/bin/pixel-social-world-server"
install -m 0755 "$BUNDLE_DIR/backend/bin/pixel-social-world-preflight" "$APP_ROOT/backend/bin/pixel-social-world-preflight"
install -m 0644 "$BUNDLE_DIR/backend/configs/production.yaml" "$APP_ROOT/backend/configs/production.yaml"
install -m 0644 "$BUNDLE_DIR/configs/"*.json "$APP_ROOT/configs/"
install -m 0644 "$BUNDLE_DIR/web/"* "$APP_ROOT/web/"
install -m 0644 "$BUNDLE_DIR/deploy/pixel-social-world.service" /etc/systemd/system/pixel-social-world.service

if [[ -f "$ENV_DIR/backend.env" ]]; then
  install -m 0640 -g "$APP_GROUP" "$BUNDLE_DIR/deploy/pixel-social-world.env.example" "$ENV_DIR/backend.env.example.new"
  echo "kept existing $ENV_DIR/backend.env"
  echo "new env template written to $ENV_DIR/backend.env.example.new"
else
  install -m 0640 -g "$APP_GROUP" "$BUNDLE_DIR/deploy/pixel-social-world.env.example" "$ENV_DIR/backend.env"
  echo "env template written to $ENV_DIR/backend.env"
fi

install -d -m 0755 /etc/caddy /etc/cloudflared
install -m 0644 "$BUNDLE_DIR/deploy/Caddyfile.funyoru.example" /etc/caddy/Caddyfile.funyoru.example
install -m 0644 "$BUNDLE_DIR/deploy/cloudflared-funyoru.yml.example" /etc/cloudflared/config.funyoru.yml.example

chown -R root:root "$APP_ROOT"
chown -R "$APP_USER:$APP_GROUP" "$STATE_ROOT"
systemctl daemon-reload

cat <<EOF
origin files installed.

Next steps:
1. Edit $ENV_DIR/backend.env and replace every CHANGE_ME value.
2. Review /etc/caddy/Caddyfile.funyoru.example before copying or merging into /etc/caddy/Caddyfile.
3. Create the Cloudflare Tunnel credentials, then adapt /etc/cloudflared/config.funyoru.yml.example.
4. Dry-run backend config:
   sudo -u $APP_USER $APP_ROOT/backend/bin/pixel-social-world-preflight -env-file $ENV_DIR/backend.env -strict
5. Start services:
   sudo systemctl enable --now pixel-social-world
   sudo systemctl reload caddy
   sudo systemctl restart cloudflared
EOF
