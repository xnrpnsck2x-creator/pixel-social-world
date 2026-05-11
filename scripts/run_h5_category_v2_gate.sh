#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_H5_CATEGORY_V2_ARTIFACT_DIR:-$ROOT_DIR/.tools/h5-category-v2-gate}"
EXPORT_WEB="${PSW_H5_EXPORT_WEB:-0}"

mkdir -p "$ARTIFACT_DIR"

PSW_H5_EXPORT_WEB="$EXPORT_WEB" \
PSW_H5_MAP_PATROL_ARTIFACT_DIR="$ARTIFACT_DIR/h5-map-patrol" \
"$ROOT_DIR/scripts/run_h5_map_patrol.sh"

PSW_H5_EXPORT_WEB=0 \
PSW_H5_NPC_AMBIENCE_ARTIFACT_DIR="$ARTIFACT_DIR/h5-npc-ambience-patrol" \
"$ROOT_DIR/scripts/run_h5_npc_ambience_patrol.sh"

PSW_H5_EXPORT_WEB=0 \
PSW_H5_AVATAR_VARIANT_ARTIFACT_DIR="$ARTIFACT_DIR/h5-avatar-variant-patrol" \
"$ROOT_DIR/scripts/run_h5_avatar_variant_patrol.sh"

PSW_H5_EXPORT_WEB=0 \
PSW_H5_AVATAR_ACTION_ARTIFACT_DIR="$ARTIFACT_DIR/h5-avatar-action-patrol" \
"$ROOT_DIR/scripts/run_h5_avatar_action_patrol.sh"

node "$ROOT_DIR/tests/h5_category_v2_report.mjs" "$ARTIFACT_DIR"
