#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_PORT="${PSW_H5_WEB_PORT:-18888}"
API_PORT="${PSW_H5_API_PORT:-8787}"
ARTIFACT_DIR="${PSW_H5_ARTIFACT_DIR:-$ROOT_DIR/.tools/artifacts}"
GO_BIN="${PSW_GO_BIN:-$ROOT_DIR/.tools/go/bin/go}"
BACKEND_BIN="$ARTIFACT_DIR/backend-h5-smoke"
WEB_LOG="$ARTIFACT_DIR/h5-static.log"
API_LOG="$ARTIFACT_DIR/h5-backend.log"
MATRIX_LOG="$ARTIFACT_DIR/h5-matrix.json"

mkdir -p "$ARTIFACT_DIR"

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

(cd "$ROOT_DIR/backend" && "$GO_BIN" build -o "$BACKEND_BIN" ./cmd/server)
python3 -m http.server "$WEB_PORT" --bind 127.0.0.1 --directory "$ROOT_DIR/builds/web" >"$WEB_LOG" 2>&1 &
web_pid=$!
(cd "$ROOT_DIR/backend" && PSW_ADDR="127.0.0.1:$API_PORT" "$BACKEND_BIN") >"$API_LOG" 2>&1 &
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
