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

AUTH_AGENT_DIR="$OPENCLAW_STATE_DIR/agents/main/agent"
AUTH_STORE="$AUTH_AGENT_DIR/auth-profiles.json"
mkdir -p "$AUTH_AGENT_DIR"
if [ ! -f "$AUTH_STORE" ]; then
  python3 - "$AUTH_STORE" <<'PYAUTH'
import json, os, pathlib, sys
out=pathlib.Path(sys.argv[1])
providers={"groq":"GROQ_API_KEY","openrouter":"OPENROUTER_API_KEY","openai":"OPENAI_API_KEY","anthropic":"ANTHROPIC_API_KEY","google":"GEMINI_API_KEY"}
profiles={}; order={}
for provider, env_name in providers.items():
    key=os.environ.get(env_name, "").strip()
    if key:
        pid=f"{provider}:env"; profiles[pid]={"type":"api_key","provider":provider,"key":key}; order[provider]=[pid]
payload={"version":1,"profiles":profiles}
if order: payload["order"]=order
json.dump(payload, out.open("w"), indent=2); out.chmod(0o600)
PYAUTH
fi

if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  echo "ERROR: OPENCLAW_GATEWAY_TOKEN must be set as a secret/env var so the Control UI can connect." >&2
  exit 64
fi
exec "$@" --token "$OPENCLAW_GATEWAY_TOKEN"
