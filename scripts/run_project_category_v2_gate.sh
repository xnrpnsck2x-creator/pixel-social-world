#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_PROJECT_CATEGORY_V2_ARTIFACT_DIR:-$ROOT_DIR/.tools/project-category-v2-gate}"
H5_SUMMARY="${PSW_PROJECT_CATEGORY_V2_H5_SUMMARY:-}"

if [[ "${PSW_PROJECT_CATEGORY_V2_SKIP_H5:-0}" != "1" && -z "$H5_SUMMARY" && -f "$ROOT_DIR/.tools/h5-category-v2-gate-current/category-v2-summary.json" ]]; then
	H5_SUMMARY="$ROOT_DIR/.tools/h5-category-v2-gate-current/category-v2-summary.json"
fi

mkdir -p "$ARTIFACT_DIR"

if [[ -n "$H5_SUMMARY" ]]; then
	PSW_PROJECT_CATEGORY_V2_H5_SUMMARY="$H5_SUMMARY" \
	python3 "$ROOT_DIR/tests/project_category_v2_gate.py" "$ARTIFACT_DIR"
else
	python3 "$ROOT_DIR/tests/project_category_v2_gate.py" "$ARTIFACT_DIR"
fi
