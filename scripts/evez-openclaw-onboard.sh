#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${OPENCLAW_STATE_DIR:=$HOME/.openclaw}"
: "${OPENCLAW_CONFIG_PATH:=$OPENCLAW_STATE_DIR/openclaw.json}"
: "${OPENCLAW_WORKSPACE_DIR:=$OPENCLAW_STATE_DIR/workspace}"
: "${OPENCLAW_PORT:=18789}"
: "${OPENCLAW_BIND:=loopback}"
: "${OPENCLAW_BIN:=openclaw}"
ENV_FILE="$OPENCLAW_STATE_DIR/openclaw.env"
mkdir -p "$OPENCLAW_STATE_DIR" "$OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_STATE_DIR/logs" "$OPENCLAW_STATE_DIR/run"
chmod 700 "$OPENCLAW_STATE_DIR"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
: "${OPENCLAW_TELEGRAM_ALLOW_FROM:=7453631330}"
existing_bool() {
  local expr="$1" file="$2"
  [[ -f "$file" ]] || { echo false; return; }
  python3 - "$file" "$expr" <<'PYBOOL' 2>/dev/null || echo false
import json,sys
p,expr=sys.argv[1],sys.argv[2]
j=json.load(open(p))
cur=j
for part in expr.split('.'):
    cur=cur.get(part,{}) if isinstance(cur,dict) else {}
print('true' if cur is True else 'false')
PYBOOL
}
EXISTING_TELEGRAM_ENABLED="$(existing_bool channels.telegram.enabled "$OPENCLAW_CONFIG_PATH")"
EXISTING_SLACK_ENABLED="$(existing_bool channels.slack.enabled "$OPENCLAW_CONFIG_PATH")"
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32 2>/dev/null || python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  umask 077
  cat > "$ENV_FILE" <<ENV
OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN
OPENCLAW_PORT=$OPENCLAW_PORT
OPENCLAW_BIND=$OPENCLAW_BIND
OPENCLAW_STATE_DIR=$OPENCLAW_STATE_DIR
OPENCLAW_CONFIG_PATH=$OPENCLAW_CONFIG_PATH
OPENCLAW_WORKSPACE_DIR=$OPENCLAW_WORKSPACE_DIR
OPENCLAW_TELEGRAM_ALLOW_FROM=$OPENCLAW_TELEGRAM_ALLOW_FROM
ENV
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TELEGRAM_BOT_TOKEN" >> "$ENV_FILE"
  fi
  if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
    printf 'SLACK_BOT_TOKEN=%s\n' "$SLACK_BOT_TOKEN" >> "$ENV_FILE"
  fi
  if [[ -n "${SLACK_APP_TOKEN:-}" ]]; then
    printf 'SLACK_APP_TOKEN=%s\n' "$SLACK_APP_TOKEN" >> "$ENV_FILE"
  fi
  for secret_name in GROQ_API_KEY OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY GOOGLE_API_KEY CEREBRAS_API_KEY DEEPSEEK_API_KEY MISTRAL_API_KEY XAI_API_KEY TOGETHER_API_KEY FIREWORKS_API_KEY NVIDIA_API_KEY DEEPINFRA_API_KEY NOVITA_API_KEY HUGGINGFACE_TOKEN; do
    value="${!secret_name:-}"
    if [[ -n "$value" ]]; then
      printf '%s=%s\n' "$secret_name" "$value" >> "$ENV_FILE"
    fi
  done
fi

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

TELEGRAM_ENABLED=false
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" || "$EXISTING_TELEGRAM_ENABLED" == "true" ]]; then
  TELEGRAM_ENABLED=true
fi
SLACK_ENABLED=false
if [[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_APP_TOKEN:-}" || "$EXISTING_SLACK_ENABLED" == "true" ]]; then
  SLACK_ENABLED=true
fi

MODEL_PRIMARY="groq/llama-3.3-70b-versatile"
MODEL_FALLBACKS='["openrouter/meta-llama/llama-3.3-70b-instruct:free", "openrouter/openai/gpt-oss-20b:free", "openrouter/qwen/qwen3-coder:free", "groq/llama-3.1-8b-instant"]'
if [[ -n "${OPENROUTER_API_KEY:-}" && -z "${GROQ_API_KEY:-}" ]]; then
  MODEL_PRIMARY="openrouter/meta-llama/llama-3.3-70b-instruct:free"
  MODEL_FALLBACKS='["openrouter/openai/gpt-oss-20b:free", "openrouter/qwen/qwen3-coder:free", "openrouter/z-ai/glm-4.5-air:free"]'
fi

if [[ -d "$ROOT/workspace" ]]; then
  cp -Rn "$ROOT/workspace/." "$OPENCLAW_WORKSPACE_DIR/" 2>/dev/null || true
fi
if [[ -f "$ROOT/runtime/agentvault-connector.json" ]]; then
  cp "$ROOT/runtime/agentvault-connector.json" "$OPENCLAW_STATE_DIR/agentvault-connector.json"
  chmod 600 "$OPENCLAW_STATE_DIR/agentvault-connector.json" 2>/dev/null || true
fi
mkdir -p "$OPENCLAW_STATE_DIR/credentials"
if [[ -n "${OPENCLAW_TELEGRAM_ALLOW_FROM:-}" ]]; then
  python3 - "$OPENCLAW_STATE_DIR/credentials/telegram-allowFrom.json" "$OPENCLAW_TELEGRAM_ALLOW_FROM" <<'PYALLOW'
import json,sys
out=sys.argv[1]
ids=[x.strip() for x in sys.argv[2].replace(';',',').split(',') if x.strip()]
json.dump({"version":1,"allowFrom":ids}, open(out,"w"), indent=2)
PYALLOW
  chmod 600 "$OPENCLAW_STATE_DIR/credentials/telegram-allowFrom.json" 2>/dev/null || true
fi
cat > "$OPENCLAW_CONFIG_PATH" <<JSON
{
  "gateway": {
    "mode": "local",
    "port": $OPENCLAW_PORT,
    "bind": "$OPENCLAW_BIND",
    "auth": { "mode": "token" },
    "controlUi": { "basePath": "/" },
    "remote": {}
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "$MODEL_PRIMARY",
        "fallbacks": $MODEL_FALLBACKS
      },
      "thinkingDefault": "high",
      "workspace": "$OPENCLAW_WORKSPACE_DIR",
      "timeoutSeconds": 1800,
      "heartbeat": { "every": "0m" }
    }
  },
  "channels": {
    "telegram": { "enabled": $TELEGRAM_ENABLED },
    "slack": { "enabled": $SLACK_ENABLED }
  },
  "plugins": {
    "entries": {
      "memory-core": { "enabled": true },
      "llm-task": { "enabled": true },
      "slack": { "enabled": $SLACK_ENABLED },
      "telegram": { "enabled": $TELEGRAM_ENABLED },
      "whatsapp": { "enabled": false },
      "signal": { "enabled": false },
      "discord": { "enabled": false },
      "open-prose": { "enabled": true },
      "copilot-proxy": { "enabled": true }
    }
  },
  "session": {
    "scope": "per-sender",
    "resetTriggers": ["/new", "/reset"],
    "reset": { "mode": "daily", "atHour": 4, "idleMinutes": 10080 }
  }
}
JSON
chmod 600 "$OPENCLAW_CONFIG_PATH" "$ENV_FILE"

# Preserve or bootstrap provider auth profiles for the default OpenClaw agent.
# OpenClaw keeps these outside openclaw.json at agents/main/agent/auth-profiles.json.
AUTH_AGENT_DIR="$OPENCLAW_STATE_DIR/agents/main/agent"
AUTH_STORE="$AUTH_AGENT_DIR/auth-profiles.json"
mkdir -p "$AUTH_AGENT_DIR"
if [[ ! -f "$AUTH_STORE" ]]; then
  python3 - "$AUTH_STORE" <<'PYAUTH'
import json, os, pathlib, sys
out=pathlib.Path(sys.argv[1])
providers={
  "groq":"GROQ_API_KEY",
  "openrouter":"OPENROUTER_API_KEY",
  "openai":"OPENAI_API_KEY",
  "anthropic":"ANTHROPIC_API_KEY",
  "google":"GEMINI_API_KEY",
  "cerebras":"CEREBRAS_API_KEY",
  "deepseek":"DEEPSEEK_API_KEY",
  "mistral":"MISTRAL_API_KEY",
  "xai":"XAI_API_KEY",
  "together":"TOGETHER_API_KEY",
  "fireworks":"FIREWORKS_API_KEY",
  "nvidia":"NVIDIA_API_KEY",
  "deepinfra":"DEEPINFRA_API_KEY",
  "novita":"NOVITA_API_KEY",
}
profiles={}
order={}
for provider, env_name in providers.items():
    key=os.environ.get(env_name, "").strip()
    if not key:
        continue
    pid=f"{provider}:env"
    profiles[pid]={"type":"api_key","provider":provider,"key":key}
    order[provider]=[pid]
payload={"version":1,"profiles":profiles}
if order:
    payload["order"]=order
json.dump(payload, out.open("w"), indent=2)
out.chmod(0o600)
PYAUTH
else
  chmod 600 "$AUTH_STORE" 2>/dev/null || true
fi


cat > "$OPENCLAW_WORKSPACE_DIR/RECOVERY.md" <<MD
# OpenClaw Recovery

This workspace is managed by evez-openclaw-deploy.

- Config: generated by scripts/evez-openclaw-onboard.sh
- Token: stored only in the local OpenClaw env file, not in git
- Dashboard: http://127.0.0.1:${OPENCLAW_PORT}/ or the tokenized link from \`openclaw dashboard --no-open\`
- Start/recover: \`scripts/evez-openclaw-recover.sh\`
MD

if ! command -v "$OPENCLAW_BIN" >/dev/null 2>&1; then
  echo "ERROR: OPENCLAW_BIN '$OPENCLAW_BIN' not found. Install OpenClaw or set OPENCLAW_BIN=/path/to/openclaw.mjs" >&2
  exit 127
fi

cat <<OUT
OpenClaw gateway onboarded.
State dir: $OPENCLAW_STATE_DIR
Config: $OPENCLAW_CONFIG_PATH
Workspace: $OPENCLAW_WORKSPACE_DIR
Dashboard: http://127.0.0.1:$OPENCLAW_PORT/
Tokenized URL: run '$OPENCLAW_BIN dashboard --no-open' on the gateway host.
OUT
