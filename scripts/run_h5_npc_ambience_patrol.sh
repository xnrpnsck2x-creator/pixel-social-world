#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_H5_NPC_AMBIENCE_ARTIFACT_DIR:-$ROOT_DIR/.tools/h5-npc-ambience-patrol}"
EXPORT_WEB="${PSW_H5_EXPORT_WEB:-0}"

PSW_H5_EXPORT_WEB="$EXPORT_WEB" \
PSW_H5_GROUP=npc_ambience \
PSW_H5_ARTIFACT_DIR="$ARTIFACT_DIR" \
"$ROOT_DIR/scripts/run_h5_matrix.sh"

PSW_H5_SEMANTIC_MATRIX="$ARTIFACT_DIR/h5-matrix.json" \
PSW_H5_SEMANTIC_GROUP=npc_ambience \
node "$ROOT_DIR/tests/h5_semantic_smoke.mjs"

node "$ROOT_DIR/tests/h5_npc_ambience_patrol_report.mjs" "$ARTIFACT_DIR/h5-matrix.json"
