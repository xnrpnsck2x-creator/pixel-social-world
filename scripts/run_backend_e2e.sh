#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
ARTIFACT_DIR="${PSW_BACKEND_E2E_ARTIFACT_DIR:-$ROOT_DIR/.tools/backend-e2e}"
GO_BIN="${PSW_GO_BIN:-$ROOT_DIR/.tools/go/bin/go}"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
API_PORT="${PSW_BACKEND_E2E_API_PORT:-18787}"
ADMIN_TOKEN="${PSW_BACKEND_E2E_ADMIN_TOKEN:-local-admin-token}"
BACKEND_BIN="$ARTIFACT_DIR/pixel-social-world-server-e2e"

TESTS=(
	"tests/auth_upgrade_backend_e2e.gd"
	"tests/reviewer_console_backend_e2e.gd"
	"tests/online_messaging_backend_e2e.gd"
	"tests/online_backend_e2e.gd"
	"tests/realtime_backend_e2e.gd"
)

if [[ ! -x "$GO_BIN" ]]; then
	GO_BIN="go"
fi
if [[ ! -x "$GODOT_BIN" ]]; then
	echo "Godot binary not found: $GODOT_BIN" >&2
	exit 1
fi

mkdir -p "$ARTIFACT_DIR"
(cd "$BACKEND_DIR" && "$GO_BIN" build -o "$BACKEND_BIN" ./cmd/server)

kill_port() {
	local port="$1"
	local pids
	pids="$(lsof -nP -tiTCP:"$port" -sTCP:LISTEN || true)"
	if [[ -n "$pids" ]]; then
		kill $pids 2>/dev/null || true
		sleep 0.4
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

api_pid=""
cleanup() {
	if [[ -n "${api_pid:-}" ]]; then
		kill "$api_pid" 2>/dev/null || true
		wait "$api_pid" 2>/dev/null || true
	fi
	kill_port "$API_PORT"
}
trap cleanup EXIT

run_one() {
	local test_script="$1"
	local slug
	slug="$(basename "$test_script" .gd)"
	local run_dir="$ARTIFACT_DIR/$slug"
	local api_log="$run_dir/backend.log"

	rm -rf "$run_dir"
	mkdir -p "$run_dir/creator_packages" "$run_dir/creator_runtime"
	kill_port "$API_PORT"

	(cd "$BACKEND_DIR" && \
		PSW_CONFIG="$BACKEND_DIR/configs/local.yaml" \
		PSW_ADDR="127.0.0.1:$API_PORT" \
		PSW_ADMIN_TOKEN="$ADMIN_TOKEN" \
		PSW_PACKAGE_ARTIFACT_DIR="$run_dir/creator_packages" \
		PSW_PACKAGE_INSTALL_DIR="$run_dir/creator_runtime" \
		"$BACKEND_BIN") >"$api_log" 2>&1 &
	api_pid=$!

	for i in $(seq 1 80); do
		if curl -fsS "http://127.0.0.1:$API_PORT/healthz" >/dev/null 2>&1; then
			break
		fi
		if [[ "$i" == "80" ]]; then
			echo "backend E2E server did not become ready for $test_script" >&2
			tail -100 "$api_log" >&2 || true
			exit 1
		fi
		sleep 0.25
	done

	echo "backend e2e start: $test_script"
	"$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$ROOT_DIR/$test_script"
	echo "backend e2e done: $test_script"

	cleanup
	api_pid=""
	assert_port_clear "$API_PORT"
}

for test_script in "${TESTS[@]}"; do
	run_one "$test_script"
done

echo "backend E2E suite passed. Artifacts: $ARTIFACT_DIR"
