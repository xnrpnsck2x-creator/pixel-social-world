#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_H5_AVATAR_VARIANT_ARTIFACT_DIR:-$ROOT_DIR/.tools/h5-avatar-variant-patrol}"
EXPORT_WEB="${PSW_H5_EXPORT_WEB:-0}"

PSW_H5_EXPORT_WEB="$EXPORT_WEB" \
PSW_H5_GROUP=avatar_variants \
PSW_H5_ARTIFACT_DIR="$ARTIFACT_DIR" \
"$ROOT_DIR/scripts/run_h5_matrix.sh"

PSW_H5_SEMANTIC_MATRIX="$ARTIFACT_DIR/h5-matrix.json" \
PSW_H5_SEMANTIC_GROUP=avatar_variants \
node "$ROOT_DIR/tests/h5_semantic_smoke.mjs"

node "$ROOT_DIR/tests/h5_avatar_variant_patrol_report.mjs" "$ARTIFACT_DIR/h5-matrix.json"
