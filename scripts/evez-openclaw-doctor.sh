#!/usr/bin/env bash
set -euo pipefail
: "${OPENCLAW_STATE_DIR:=$HOME/.openclaw}"
: "${OPENCLAW_CONFIG_PATH:=$OPENCLAW_STATE_DIR/openclaw.json}"
: "${OPENCLAW_PORT:=18789}"
: "${OPENCLAW_BIN:=openclaw}"
printf 'OpenClaw binary: '; command -v "$OPENCLAW_BIN" || true
printf 'State dir: %s\nConfig: %s\n' "$OPENCLAW_STATE_DIR" "$OPENCLAW_CONFIG_PATH"
if [[ -f "$OPENCLAW_CONFIG_PATH" ]]; then echo 'Config exists'; else echo 'Config missing'; fi
if curl -fsS "http://127.0.0.1:$OPENCLAW_PORT/healthz"; then echo; else echo 'healthz failed'; fi
if command -v "$OPENCLAW_BIN" >/dev/null 2>&1; then "$OPENCLAW_BIN" gateway status --json || true; fi
