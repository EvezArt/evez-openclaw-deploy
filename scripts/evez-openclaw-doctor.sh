#!/usr/bin/env bash
set -euo pipefail
: "${OPENCLAW_STATE_DIR:=$HOME/.openclaw}"
: "${OPENCLAW_CONFIG_PATH:=$OPENCLAW_STATE_DIR/openclaw.json}"
: "${OPENCLAW_PORT:=18789}"
: "${OPENCLAW_BIN:=openclaw}"
ENV_FILE="$OPENCLAW_STATE_DIR/openclaw.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
printf 'OpenClaw binary: '
if command -v "$OPENCLAW_BIN" >/dev/null 2>&1; then command -v "$OPENCLAW_BIN"; else echo "missing ($OPENCLAW_BIN)"; fi
printf 'State dir: %s\nConfig: %s\n' "$OPENCLAW_STATE_DIR" "$OPENCLAW_CONFIG_PATH"
if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then echo 'Config exists'; else echo 'Config missing'; fi
if [[ -f "$OPENCLAW_STATE_DIR/agentvault-connector.json" ]]; then echo 'AgentVault connector profile exists'; else echo 'AgentVault connector profile missing'; fi
if command -v "$OPENCLAW_BIN" >/dev/null 2>&1 && [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  if env OPENCLAW_STATE_DIR="$OPENCLAW_STATE_DIR" OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
    "$OPENCLAW_BIN" gateway health --url "ws://127.0.0.1:$OPENCLAW_PORT" --token "$OPENCLAW_GATEWAY_TOKEN" --timeout 5000; then
    true
  else
    echo 'Gateway WS health failed'
  fi
  "$OPENCLAW_BIN" gateway status --json || true
else
  echo 'Gateway health skipped: missing binary or token'
fi
