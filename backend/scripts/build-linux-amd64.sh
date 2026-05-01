#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/bin}"
GO_BIN="${GO_BIN:-$ROOT_DIR/../.tools/go/bin/go}"

if [[ ! -x "$GO_BIN" ]]; then
  GO_BIN="go"
fi

mkdir -p "$OUT_DIR"
cd "$ROOT_DIR"

export GOOS="${GOOS:-linux}"
export GOARCH="${GOARCH:-amd64}"
export CGO_ENABLED="${CGO_ENABLED:-0}"
export GOMODCACHE="${GOMODCACHE:-$ROOT_DIR/../.tools/gomodcache}"
export GOCACHE="${GOCACHE:-$ROOT_DIR/../.tools/gocache}"

"$GO_BIN" build \
  -trimpath \
  -ldflags="-s -w" \
  -o "$OUT_DIR/pixel-social-world-server" \
  ./cmd/server

"$GO_BIN" build \
  -trimpath \
  -ldflags="-s -w" \
  -o "$OUT_DIR/pixel-social-world-preflight" \
  ./cmd/preflight

"$GO_BIN" build \
  -trimpath \
  -ldflags="-s -w" \
  -o "$OUT_DIR/pixel-social-world-retention-cleanup" \
  ./cmd/retention-cleanup

echo "$OUT_DIR/pixel-social-world-server"
echo "$OUT_DIR/pixel-social-world-preflight"
echo "$OUT_DIR/pixel-social-world-retention-cleanup"
