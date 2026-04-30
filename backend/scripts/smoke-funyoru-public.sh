#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

WEB_URL="${PSW_WEB_URL:-https://funyoru.com}"
API_URL="${PSW_API_URL:-https://api.funyoru.com}"
RUN_BROWSER_SMOKE="${RUN_BROWSER_SMOKE:-0}"

tmp_index="$(mktemp)"
trap 'rm -f "$tmp_index"' EXIT

echo "checking H5 shell: $WEB_URL"
curl -fsS --retry 3 --retry-delay 2 "$WEB_URL" -o "$tmp_index"
grep -q "index.wasm" "$tmp_index"
grep -q "index.pck" "$tmp_index"

echo "checking backend health: $API_URL/healthz"
curl -fsS --retry 3 --retry-delay 2 "$API_URL/healthz"
echo

if [[ "$RUN_BROWSER_SMOKE" == "1" ]]; then
  echo "running browser smoke against $WEB_URL/index.html"
  (
    cd "$PROJECT_DIR"
    PSW_H5_URL="$WEB_URL/index.html" node tests/h5_viewport_smoke.mjs
  )
fi

echo "public smoke passed"
