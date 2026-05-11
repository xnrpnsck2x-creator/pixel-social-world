#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_OFFSET="${PSW_H5_PORT_OFFSET:-$((($$ % 1000) + 100))}"
WEB_PORT="${PSW_H5_WEB_PORT:-$((18888 + PORT_OFFSET))}"
API_PORT="${PSW_H5_API_PORT:-$((8787 + PORT_OFFSET))}"
ARTIFACT_DIR="${PSW_H5_ARTIFACT_DIR:-$ROOT_DIR/.tools/artifacts}"
GO_BIN="${PSW_GO_BIN:-$ROOT_DIR/.tools/go/bin/go}"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
BACKEND_BIN="$ARTIFACT_DIR/backend-h5-smoke"
WEB_LOG="$ARTIFACT_DIR/h5-static.log"
API_LOG="$ARTIFACT_DIR/h5-backend.log"
MATRIX_LOG="$ARTIFACT_DIR/h5-matrix.json"
RUNTIME_GATE_LOG="$ARTIFACT_DIR/h5-runtime-gate.json"
WEB_EXPORT_DIR="$ROOT_DIR/builds/web"
WEB_SERVE_DIR="$ARTIFACT_DIR/web"
BACKEND_CORS_ALLOWED_ORIGINS="${PSW_CORS_ALLOWED_ORIGINS:-http://127.0.0.1:$WEB_PORT,http://localhost:$WEB_PORT,http://127.0.0.1:$API_PORT,http://localhost:$API_PORT}"
required_web_files=(index.html index.js index.wasm index.pck)

mkdir -p "$ARTIFACT_DIR"

if [[ ! -x "$GO_BIN" ]]; then
	GO_BIN="go"
fi

ensure_playwright() {
	if [[ ! -f "$ROOT_DIR/.tools/browser-smoke/node_modules/playwright/index.mjs" ]]; then
		npm ci --prefix "$ROOT_DIR/.tools/browser-smoke"
	fi
}

ensure_web_export() {
	local missing=0
	for file in "${required_web_files[@]}"; do
		if [[ ! -f "$WEB_EXPORT_DIR/$file" ]]; then
			missing=1
		fi
	done
	if [[ "${PSW_H5_EXPORT_WEB:-0}" == "1" || "$missing" == "1" ]]; then
		mkdir -p "$WEB_EXPORT_DIR"
		"$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release Web "$WEB_EXPORT_DIR/index.html"
	fi
	for file in "${required_web_files[@]}"; do
		if [[ ! -f "$WEB_EXPORT_DIR/$file" ]]; then
			echo "missing Web export file after export check: $WEB_EXPORT_DIR/$file" >&2
			exit 1
		fi
	done
}

prepare_web_serve_dir() {
	mkdir -p "$WEB_SERVE_DIR"
	for file in "$WEB_EXPORT_DIR"/*; do
		local name
		name="$(basename "$file")"
		if [[ "$name" == "runtime_config.json" ]]; then
			continue
		fi
		ln -sf "$file" "$WEB_SERVE_DIR/$name"
	done
	cat >"$WEB_SERVE_DIR/runtime_config.json" <<JSON
{
  "schema_version": 1,
  "web_build": "h5-smoke",
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
}

kill_port() {
	local port="$1"
	local pids
	pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN || true)"
	if [[ -n "$pids" ]]; then
		kill $pids 2>/dev/null || true
		sleep 0.5
	fi
	pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN || true)"
	if [[ -n "$pids" ]]; then
		kill -TERM $pids 2>/dev/null || true
		sleep 0.5
	fi
}

assert_port_clear() {
	local port="$1"
	local pids
	pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN || true)"
	if [[ -n "$pids" ]]; then
		echo "leftover listener on port $port: $pids" >&2
		return 1
	fi
}

web_pid=""
api_pid=""
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
trap cleanup EXIT

kill_port "$WEB_PORT"
kill_port "$API_PORT"

ensure_playwright
ensure_web_export
python3 "$ROOT_DIR/scripts/patch_web_shell.py" "$WEB_EXPORT_DIR/index.html" >/dev/null
prepare_web_serve_dir

(cd "$ROOT_DIR/backend" && "$GO_BIN" build -o "$BACKEND_BIN" ./cmd/server)
python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$WEB_SERVE_DIR" >"$WEB_LOG" 2>&1 &
web_pid=$!
(cd "$ROOT_DIR/backend" && PSW_ADDR="127.0.0.1:$API_PORT" PSW_CORS_ALLOWED_ORIGINS="$BACKEND_CORS_ALLOWED_ORIGINS" "$BACKEND_BIN") >"$API_LOG" 2>&1 &
api_pid=$!

for i in $(seq 1 80); do
	if curl -fsS "http://127.0.0.1:$WEB_PORT/index.html" >/dev/null 2>&1 && \
		curl -fsS "http://127.0.0.1:$API_PORT/healthz" >/dev/null 2>&1; then
		break
	fi
	if [[ "$i" == "80" ]]; then
		echo "H5 smoke servers did not become ready." >&2
		tail -60 "$WEB_LOG" || true
		tail -80 "$API_LOG" || true
		exit 1
	fi
	sleep 0.25
done

PSW_H5_URL="http://127.0.0.1:$WEB_PORT/index.html" \
PSW_H5_ARTIFACT_DIR="$ARTIFACT_DIR" \
PSW_H5_CASE="${PSW_H5_CASE:-}" \
node "$ROOT_DIR/tests/h5_viewport_smoke.mjs" >"$MATRIX_LOG"

if [[ "${PSW_H5_RUNTIME_GATE:-0}" == "1" ]]; then
	PSW_H5_URL="http://127.0.0.1:$WEB_PORT/index.html" \
	PSW_H5_ARTIFACT_DIR="$ARTIFACT_DIR" \
	node "$ROOT_DIR/tests/h5_runtime_gate_smoke.mjs" >"$RUNTIME_GATE_LOG"
	if [[ ! -s "$RUNTIME_GATE_LOG" ]]; then
		echo "missing H5 runtime gate output: $RUNTIME_GATE_LOG" >&2
		exit 1
	fi
	node - "$RUNTIME_GATE_LOG" <<'NODE'
const fs = require("node:fs");
const logPath = process.argv[2];
const result = JSON.parse(fs.readFileSync(logPath, "utf8"));
if (!result.canvasInfo || !result.sample || !result.screenshot) {
	throw new Error(`invalid H5 runtime gate output: ${logPath}`);
}
NODE
fi

cleanup
trap - EXIT
assert_port_clear "$WEB_PORT"
assert_port_clear "$API_PORT"

node - "$MATRIX_LOG" <<'NODE'
const fs = require("node:fs");
const logPath = process.argv[2];
const results = JSON.parse(fs.readFileSync(logPath, "utf8"));
const consoleMessages = results.reduce((sum, row) => sum + (row.messages?.length || 0), 0);
console.log(`h5 matrix passed: ${results.length} screenshots, ${consoleMessages} console messages, ports clear`);
NODE
