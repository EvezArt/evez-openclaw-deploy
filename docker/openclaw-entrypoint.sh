#!/usr/bin/env sh
set -eu
: "${OPENCLAW_STATE_DIR:=/home/node/.openclaw}"
: "${OPENCLAW_CONFIG_PATH:=$OPENCLAW_STATE_DIR/openclaw.json}"
: "${OPENCLAW_WORKSPACE_DIR:=$OPENCLAW_STATE_DIR/workspace}"
: "${OPENCLAW_TELEGRAM_ALLOW_FROM:=}"
mkdir -p "$OPENCLAW_STATE_DIR" "$OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_STATE_DIR/credentials" "$OPENCLAW_STATE_DIR/logs" "$OPENCLAW_STATE_DIR/run"
if [ ! -f "$OPENCLAW_CONFIG_PATH" ] || [ "${EVEZ_OPENCLAW_OVERWRITE_CONFIG:-0}" = "1" ]; then
  cp /opt/evez-openclaw-deploy/openclaw.json "$OPENCLAW_CONFIG_PATH"
fi
if [ -d /opt/evez-openclaw-deploy/workspace ]; then
  cp -Rn /opt/evez-openclaw-deploy/workspace/. "$OPENCLAW_WORKSPACE_DIR/" 2>/dev/null || true
fi
if [ -f /opt/evez-openclaw-deploy/runtime/agentvault-connector.json ]; then
  cp /opt/evez-openclaw-deploy/runtime/agentvault-connector.json "$OPENCLAW_STATE_DIR/agentvault-connector.json"
fi
if [ -n "$OPENCLAW_TELEGRAM_ALLOW_FROM" ]; then
  python3 - "$OPENCLAW_STATE_DIR/credentials/telegram-allowFrom.json" "$OPENCLAW_TELEGRAM_ALLOW_FROM" <<'PY'
import json,sys
ids=[x.strip() for x in sys.argv[2].replace(';',',').split(',') if x.strip()]
json.dump({"version":1,"allowFrom":ids}, open(sys.argv[1],"w"), indent=2)
PY
fi
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  echo "ERROR: OPENCLAW_GATEWAY_TOKEN must be set as a secret/env var so the Control UI can connect." >&2
  exit 64
fi
exec "$@" --token "$OPENCLAW_GATEWAY_TOKEN"
