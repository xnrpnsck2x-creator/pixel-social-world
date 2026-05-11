#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
WEB_SRC_DIR="${PSW_LOCAL_ALPHA_WEB_SRC:-$ROOT_DIR/builds/web}"
WEB_PORT="${PSW_LOCAL_ALPHA_WEB_PORT:-18888}"
API_PORT="${PSW_LOCAL_ALPHA_API_PORT:-8787}"
ADMIN_TOKEN="${PSW_LOCAL_ALPHA_ADMIN_TOKEN:-local-admin-token}"
ARTIFACT_DIR="${PSW_LOCAL_ALPHA_ARTIFACT_DIR:-$ROOT_DIR/.tools/local-alpha}"
GO_BIN="${PSW_GO_BIN:-$ROOT_DIR/.tools/go/bin/go}"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
EXPORT_WEB="${PSW_LOCAL_ALPHA_EXPORT_WEB:-0}"
EXIT_AFTER_READY="${PSW_LOCAL_ALPHA_EXIT_AFTER_READY:-0}"

if [[ ! -x "$GO_BIN" ]]; then
	GO_BIN="go"
fi

required_web_files=(index.html index.js index.wasm index.pck)

kill_port() {
	local port="$1"
	local pids
	pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN || true)"
	if [[ -n "$pids" ]]; then
		kill $pids 2>/dev/null || true
		sleep 0.3
	fi
}

cleanup() {
	if [[ -n "${web_pid:-}" ]]; then
		kill "$web_pid" 2>/dev/null || true
		wait "$web_pid" 2>/dev/null || true
	fi
	if [[ -n "${api_pid:-}" ]]; then
		kill "$api_pid" 2>/dev/null || true
		wait "$api_pid" 2>/dev/null || true
	fi
	kill_port "$WEB_PORT"
	kill_port "$API_PORT"
}

if [[ "$EXPORT_WEB" == "1" ]]; then
	"$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release Web "$WEB_SRC_DIR/index.html"
fi

for file in "${required_web_files[@]}"; do
	if [[ ! -f "$WEB_SRC_DIR/$file" ]]; then
		echo "missing Web export file: $WEB_SRC_DIR/$file" >&2
		echo "run: PSW_LOCAL_ALPHA_EXPORT_WEB=1 scripts/run_local_alpha.sh" >&2
		exit 1
	fi
done
python3 "$ROOT_DIR/scripts/patch_web_shell.py" "$WEB_SRC_DIR/index.html" >/dev/null

mkdir -p "$ARTIFACT_DIR" "$BACKEND_DIR/var/creator_packages" "$BACKEND_DIR/var/creator_runtime"
WEB_DIR="$ARTIFACT_DIR/web"
BACKEND_BIN="$ARTIFACT_DIR/pixel-social-world-server-local"
PREFLIGHT_BIN="$ARTIFACT_DIR/pixel-social-world-preflight-local"
WEB_LOG="$ARTIFACT_DIR/web.log"
API_LOG="$ARTIFACT_DIR/api.log"
rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR"
for file in "$WEB_SRC_DIR"/*; do
	name="$(basename "$file")"
	if [[ "$name" == "runtime_config.json" ]]; then
		continue
	fi
	ln -sf "$file" "$WEB_DIR/$name"
done
cat >"$WEB_DIR/runtime_config.json" <<JSON
{
  "schema_version": 1,
  "web_build": "local-alpha",
  "min_client_version": "0.1.0",
  "maintenance": {"enabled": false, "message_key": ""},
  "network": {
    "environment": "local_alpha",
    "online_enabled": true,
    "base_url": "http://127.0.0.1:$API_PORT",
    "websocket_url": "ws://127.0.0.1:$API_PORT/ws/city"
  },
  "feature_flags": {
    "trade_backend": true
  }
}
JSON

(cd "$BACKEND_DIR" && "$GO_BIN" build -o "$BACKEND_BIN" ./cmd/server)
(cd "$BACKEND_DIR" && "$GO_BIN" build -o "$PREFLIGHT_BIN" ./cmd/preflight)
(cd "$BACKEND_DIR" && \
	PSW_ADDR="127.0.0.1:$API_PORT" \
	PSW_ADMIN_TOKEN="$ADMIN_TOKEN" \
	"$PREFLIGHT_BIN" -config configs/local.yaml -check-dirs >/dev/null)

web_pid=""
api_pid=""
trap cleanup EXIT
kill_port "$WEB_PORT"
kill_port "$API_PORT"

python3 - "$WEB_PORT" "$WEB_DIR" >"$WEB_LOG" 2>&1 <<'PY' &
import functools
import http.server
import socketserver
import sys

port = int(sys.argv[1])
directory = sys.argv[2]

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
	def end_headers(self):
		self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
		self.send_header("Pragma", "no-cache")
		self.send_header("Expires", "0")
		super().end_headers()

handler = functools.partial(NoCacheHandler, directory=directory)
class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

with ReusableTCPServer(("127.0.0.1", port), handler) as httpd:
    httpd.serve_forever()
PY
web_pid=$!
(cd "$BACKEND_DIR" && \
	PSW_CONFIG="$BACKEND_DIR/configs/local.yaml" \
	PSW_ADDR="127.0.0.1:$API_PORT" \
	PSW_ADMIN_TOKEN="$ADMIN_TOKEN" \
	"$BACKEND_BIN") >"$API_LOG" 2>&1 &
api_pid=$!

for i in $(seq 1 80); do
	if curl -fsS "http://127.0.0.1:$WEB_PORT/index.html" >/dev/null 2>&1 && \
		curl -fsS "http://127.0.0.1:$API_PORT/healthz" >/dev/null 2>&1; then
		break
	fi
	if [[ "$i" == "80" ]]; then
		echo "local alpha did not become ready" >&2
		tail -80 "$API_LOG" >&2 || true
		tail -40 "$WEB_LOG" >&2 || true
		exit 1
	fi
	sleep 0.25
done

cat <<EOF
Local Alpha is ready.

Player URL:
  http://127.0.0.1:$WEB_PORT/index.html

Useful direct panels:
  http://127.0.0.1:$WEB_PORT/index.html?psw_panel=messages
  http://127.0.0.1:$WEB_PORT/index.html?psw_panel=creator
  http://127.0.0.1:$WEB_PORT/index.html?psw_route=liveops_console

Backend API probes (not a UI page):
  http://127.0.0.1:$API_PORT/healthz
  http://127.0.0.1:$API_PORT/readyz

Admin token for local LiveOps:
  $ADMIN_TOKEN

How to use the token:
  Open the LiveOps URL above, paste the token into the top Admin token field,
  then press Refresh.

Logs:
  $WEB_LOG
  $API_LOG

Press Ctrl+C to stop local alpha.
EOF

if [[ "$EXIT_AFTER_READY" == "1" ]]; then
	exit 0
fi

wait "$api_pid"
