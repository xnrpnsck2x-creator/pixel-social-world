#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$BACKEND_DIR/.." && pwd)"

WEB_DIR="${WEB_DIR:-$PROJECT_DIR/builds/web}"
RELEASE_ROOT="${RELEASE_ROOT:-$PROJECT_DIR/.tools/releases}"
RELEASE_NAME="${RELEASE_NAME:-pixel-social-world-funyoru-free-launch}"
RELEASE_DIR="$RELEASE_ROOT/$RELEASE_NAME"
ARCHIVE_PATH="${ARCHIVE_PATH:-$RELEASE_ROOT/$RELEASE_NAME.tar.gz}"

required_web_files=(index.html index.js index.wasm index.pck)
for file in "${required_web_files[@]}"; do
  if [[ ! -f "$WEB_DIR/$file" ]]; then
    echo "missing Web export file: $WEB_DIR/$file" >&2
    echo "run the Godot Web export before packaging" >&2
    exit 1
  fi
done

"$SCRIPT_DIR/build-linux-amd64.sh" >/dev/null

rm -rf "$RELEASE_DIR"
mkdir -p \
  "$RELEASE_DIR/backend/bin" \
  "$RELEASE_DIR/backend/configs" \
  "$RELEASE_DIR/configs" \
  "$RELEASE_DIR/deploy" \
  "$RELEASE_DIR/web"

cp "$BACKEND_DIR/bin/pixel-social-world-server" "$RELEASE_DIR/backend/bin/"
cp "$BACKEND_DIR/bin/pixel-social-world-preflight" "$RELEASE_DIR/backend/bin/"
cp "$BACKEND_DIR/bin/pixel-social-world-retention-cleanup" "$RELEASE_DIR/backend/bin/"
cp "$BACKEND_DIR/configs/production.yaml" "$RELEASE_DIR/backend/configs/"
cp "$BACKEND_DIR/deploy/"* "$RELEASE_DIR/deploy/"
cp "$PROJECT_DIR/configs/"*.json "$RELEASE_DIR/configs/"
cp "$WEB_DIR/"* "$RELEASE_DIR/web/"
python3 "$PROJECT_DIR/scripts/patch_web_shell.py" "$RELEASE_DIR/web/index.html" >/dev/null
if [[ -f "$BACKEND_DIR/deploy/runtime_config.funyoru.json" ]]; then
  cp "$BACKEND_DIR/deploy/runtime_config.funyoru.json" "$RELEASE_DIR/web/runtime_config.json"
fi

cat >"$RELEASE_DIR/README.deploy.txt" <<'EOF'
Pixel Social World funyoru.com Free Launch Bundle

Suggested origin layout:

  /opt/pixel-social-world/backend/bin/pixel-social-world-server
  /opt/pixel-social-world/backend/bin/pixel-social-world-preflight
  /opt/pixel-social-world/backend/bin/pixel-social-world-retention-cleanup
  /opt/pixel-social-world/backend/bin/pixel-social-world-liveops-alert-probe
  /opt/pixel-social-world/backend/configs/production.yaml
  /opt/pixel-social-world/configs/*.json
  /opt/pixel-social-world/web/*
  /opt/pixel-social-world/web/runtime_config.json
  /etc/pixel-social-world/backend.env

Suggested service files:

  deploy/pixel-social-world.service -> /etc/systemd/system/pixel-social-world.service
  deploy/pixel-social-world-retention-cleanup.service -> /etc/systemd/system/pixel-social-world-retention-cleanup.service
  deploy/pixel-social-world-retention-cleanup.timer -> /etc/systemd/system/pixel-social-world-retention-cleanup.timer
  deploy/pixel-social-world-liveops-alerts.service -> /etc/systemd/system/pixel-social-world-liveops-alerts.service
  deploy/pixel-social-world-liveops-alerts.timer -> /etc/systemd/system/pixel-social-world-liveops-alerts.timer
  deploy/pixel-social-world.env.example -> /etc/pixel-social-world/backend.env
  deploy/Caddyfile.funyoru.example -> merge into /etc/caddy/Caddyfile
  deploy/cloudflared-funyoru.yml.example -> merge into /etc/cloudflared/config.yml

After editing secrets in backend.env:

  /opt/pixel-social-world/backend/bin/pixel-social-world-preflight -env-file /etc/pixel-social-world/backend.env -strict
  /opt/pixel-social-world/backend/bin/pixel-social-world-retention-cleanup -env-file /etc/pixel-social-world/backend.env
  sudo systemctl daemon-reload
  sudo systemctl enable --now pixel-social-world
  sudo systemctl enable --now pixel-social-world-retention-cleanup.timer
  sudo systemctl enable --now pixel-social-world-liveops-alerts.timer
  sudo systemctl reload caddy
  sudo systemctl restart cloudflared
EOF

(
  cd "$RELEASE_DIR"
  find . -type f -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS
)

mkdir -p "$RELEASE_ROOT"
rm -f "$ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$RELEASE_ROOT" "$RELEASE_NAME"

echo "release_dir=$RELEASE_DIR"
echo "archive=$ARCHIVE_PATH"
du -sh "$RELEASE_DIR" "$ARCHIVE_PATH"
