#!/usr/bin/env bash
set -euo pipefail

addr="${PSW_ADDR:-127.0.0.1:8787}"
if [[ "$addr" == http://* || "$addr" == https://* ]]; then
  default_endpoint="${addr%/}/debug/ops/alerts"
else
  default_endpoint="http://${addr%/}/debug/ops/alerts"
fi

endpoint="${PSW_LIVEOPS_ALERT_ENDPOINT:-$default_endpoint}"
format="${PSW_LIVEOPS_ALERT_FORMAT:-json}"
timeout="${PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS:-5}"
token="${PSW_LIVEOPS_ALERT_TOKEN:-${PSW_ADMIN_TOKEN:-}}"
curl_bin="${CURL_BIN:-curl}"

if [[ -z "$token" || "$token" == CHANGE_ME* ]]; then
  echo "missing PSW_LIVEOPS_ALERT_TOKEN or PSW_ADMIN_TOKEN for LiveOps alert probe" >&2
  exit 2
fi

if ! command -v "$curl_bin" >/dev/null 2>&1; then
  echo "missing curl executable: $curl_bin" >&2
  exit 2
fi

separator="?"
if [[ "$endpoint" == *"?"* ]]; then
  separator="&"
fi

case "$format" in
  json|"")
    url="${endpoint}${separator}emit_log=1"
    ;;
  prometheus)
    url="${endpoint}${separator}format=prometheus&emit_log=1"
    ;;
  *)
    echo "unsupported PSW_LIVEOPS_ALERT_FORMAT: $format" >&2
    exit 2
    ;;
esac

"$curl_bin" \
  -fsS \
  --connect-timeout "$timeout" \
  --max-time "$timeout" \
  --retry 1 \
  --retry-delay 1 \
  --config - \
  "$url" <<EOF
header = "X-Admin-Token: ${token}"
EOF

printf '\n'
