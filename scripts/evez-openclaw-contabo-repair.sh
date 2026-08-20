#!/usr/bin/env bash
# Recover a real OpenClaw node without disabling gateway authentication.
# Requires: curl, jq, OpenClaw, and OPENROUTER_API_KEY in the local OpenClaw env file.
set -Eeuo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${OPENCLAW_STATE_DIR:=$HOME/.openclaw}"
: "${OPENCLAW_CONFIG_PATH:=$OPENCLAW_STATE_DIR/openclaw.json}"
: "${OPENCLAW_PORT:=18789}"
: "${OPENCLAW_BIN:=openclaw}"
ENV_FILE="$OPENCLAW_STATE_DIR/openclaw.env"
MODEL_API="https://openrouter.ai/api/v1/models"
CHAT_API="https://openrouter.ai/api/v1/chat/completions"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/evez-openclaw-repair.XXXXXX")"
BACKUP_DIR="$OPENCLAW_STATE_DIR/backups/repair-$(date -u +%Y%m%dT%H%M%SZ)"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

command -v "$OPENCLAW_BIN" >/dev/null 2>&1 || die "OpenClaw binary '$OPENCLAW_BIN' was not found"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

# First regenerate the normal local bridge variables, token-backed gateway config,
# workspace, and provider auth profiles. This never prints a secret.
if [[ -x "$ROOT/scripts/evez-openclaw-onboard.sh" ]]; then
  "$ROOT/scripts/evez-openclaw-onboard.sh" >/dev/null
fi

[[ -f "$ENV_FILE" ]] || die "Expected local OpenClaw environment file is missing: $ENV_FILE"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

[[ -n "${OPENROUTER_API_KEY:-}" ]] || die "OPENROUTER_API_KEY is absent; cannot configure OpenRouter routing"

mkdir -p "$BACKUP_DIR"
cp -a "$OPENCLAW_CONFIG_PATH" "$BACKUP_DIR/openclaw.json.before" 2>/dev/null || true
cp -a "$ENV_FILE" "$BACKUP_DIR/openclaw.env.before" 2>/dev/null || true
cp -a "$OPENCLAW_STATE_DIR/agents/main/agent/auth-profiles.json" "$BACKUP_DIR/auth-profiles.json.before" 2>/dev/null || true
chmod 700 "$BACKUP_DIR"

log "Fetching the live OpenRouter model catalog"
curl --fail --silent --show-error --location --retry 3 --connect-timeout 10 --max-time 45 \
  "$MODEL_API" -o "$WORK_DIR/models.json"

# Keep OpenClaw on text-producing, zero-cost models only. The generic route is
# deliberately first: it lets OpenRouter select an available free provider when
# individual community models are temporarily rate-limited or removed.
jq -r '
  .data[]
  | select(.id != "openrouter/free")
  | select(((.pricing.prompt | tonumber? // -1) == 0) and ((.pricing.completion | tonumber? // -1) == 0))
  | select((.architecture.output_modalities // []) | index("text"))
  | .id
' "$WORK_DIR/models.json" | sort -u > "$WORK_DIR/free-text-models.txt"

[[ -s "$WORK_DIR/free-text-models.txt" ]] || die "The OpenRouter catalog contained no zero-cost text models"

# A stable priority order is applied only if each model remains in the live catalog.
PREFERRED=(
  "openai/gpt-oss-20b:free"
  "google/gemma-4-31b-it:free"
  "nvidia/nemotron-3-super-120b-a12b:free"
  "z-ai/glm-5.2:free"
  "nvidia/nemotron-3-nano-30b-a3b:free"
  "liquid/lfm-2.5-2.6b:free"
)
CANDIDATES=()
for model in "${PREFERRED[@]}"; do
  grep -Fxq "$model" "$WORK_DIR/free-text-models.txt" && CANDIDATES+=("$model")
done
while IFS= read -r model; do
  case " ${CANDIDATES[*]} " in
    *" $model "*) ;;
    *) CANDIDATES+=("$model") ;;
  esac
done < "$WORK_DIR/free-text-models.txt"

# Probe a bounded set. This proves the route can return an answer now, instead of
# trusting a stale model name. A 429 simply means the candidate is skipped today.
HEALTHY=()
for model in "${CANDIDATES[@]}"; do
  [[ ${#HEALTHY[@]} -ge 4 ]] && break
  body="$(jq -cn --arg model "$model" '{model:$model,messages:[{role:"user",content:"Reply with OK"}],max_tokens:8,temperature:0}')"
  status="$(curl --silent --show-error --output "$WORK_DIR/response.json" --write-out '%{http_code}' \
    --connect-timeout 10 --max-time 35 --retry 1 \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H 'Content-Type: application/json' \
    -H 'HTTP-Referer: https://evez.local/recovery' \
    -H 'X-Title: EVEZ OpenClaw Recovery' \
    --data "$body" "$CHAT_API" || true)"
  if [[ "$status" == "200" ]] && jq -e '.choices[0].message.content? // .choices[0].message.reasoning? // empty' "$WORK_DIR/response.json" >/dev/null 2>&1; then
    HEALTHY+=("$model")
    log "Verified free model: $model"
  else
    log "Skipping unavailable free model: $model (HTTP ${status:-network-error})"
  fi
done

[[ ${#HEALTHY[@]} -gt 0 ]] || die "No sampled free model completed a live OpenRouter response; verify key, account access, and provider availability"

MODEL_REFS=("openrouter/free")
for model in "${HEALTHY[@]}"; do
  MODEL_REFS+=("openrouter/$model")
done
FALLBACK_JSON="$(jq -cn '$ARGS.positional' --args "${MODEL_REFS[@]:1}")"

log "Writing authenticated OpenRouter primary and verified fallbacks"
"$OPENCLAW_BIN" config set agents.defaults.model.primary "${MODEL_REFS[0]}"
"$OPENCLAW_BIN" config set agents.defaults.model.fallbacks "$FALLBACK_JSON" --json

# Enforce token auth and loopback binding. Remote/mobile access must be supplied
# by Tailscale Serve or a reverse proxy, never by an unauthenticated LAN listener.
"$OPENCLAW_BIN" config set gateway.bind "loopback"
"$OPENCLAW_BIN" config set gateway.auth.mode "token"

log "Restarting the gateway through its supported service path"
if command -v systemctl >/dev/null 2>&1 && systemctl --user cat openclaw-gateway.service >/dev/null 2>&1; then
  systemctl --user restart openclaw-gateway.service
elif "$OPENCLAW_BIN" gateway restart >/dev/null 2>&1; then
  :
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -Fxq openclaw-gateway; then
  docker restart openclaw-gateway >/dev/null
else
  die "Could not identify a supported OpenClaw service manager"
fi

# Health is verified with the token over the local loopback control path.
for _ in $(seq 1 45); do
  if env OPENCLAW_STATE_DIR="$OPENCLAW_STATE_DIR" OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}" \
    "$OPENCLAW_BIN" gateway health --url "ws://127.0.0.1:${OPENCLAW_PORT}" \
      --token "${OPENCLAW_GATEWAY_TOKEN:-}" --timeout 5000 >/dev/null 2>&1; then
    log "Gateway is healthy with OpenRouter free-routing fallbacks"
    log "Primary: ${MODEL_REFS[0]}"
    log "Fallbacks: ${MODEL_REFS[*]:1}"
    exit 0
  fi
  sleep 1
done

die "Gateway did not pass its authenticated health check after restart; restore from $BACKUP_DIR and inspect $OPENCLAW_STATE_DIR/logs"
