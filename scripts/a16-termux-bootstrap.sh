#!/usr/bin/env bash
# EVEZ OpenClaw bootstrap for a Samsung Galaxy A16 running Termux.
# The device is a private control surface: local OpenClaw stays loopback-only and
# the remote Contabo gateway is reached through Tailscale with a device-specific token.
set -Eeuo pipefail
umask 077

OC_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OC_REPO="${OC_REPO:-https://github.com/EvezArt/evez-openclaw-deploy.git}"
OC_WORK="$HOME/evez-openclaw-deploy"
OC_PORT="${OPENCLAW_PORT:-18789}"
ENV_FILE="$OC_HOME/.env"

mkdir -p "$OC_HOME" "$OC_HOME/workspace" "$OC_HOME/logs" "$OC_HOME/state"
chmod 700 "$OC_HOME"

if command -v pkg >/dev/null 2>&1; then
  pkg update -y || true
  pkg install -y git curl jq nodejs-lts openssl termux-api || true
fi

if [ ! -d "$OC_WORK/.git" ]; then
  git clone "$OC_REPO" "$OC_WORK"
else
  git -C "$OC_WORK" pull --ff-only || true
fi

cp "$OC_WORK/openclaw.json" "$OC_HOME/openclaw.json"
cp -R "$OC_WORK/workspace/." "$OC_HOME/workspace/" 2>/dev/null || true

if [[ ! -f "$ENV_FILE" ]]; then
  touch "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

upsert_env() {
  local name="$1" value="$2"
  grep -v "^${name}=" "$ENV_FILE" > "$ENV_FILE.tmp" 2>/dev/null || true
  printf '%s=%s\n' "$name" "$value" >> "$ENV_FILE.tmp"
  mv "$ENV_FILE.tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

# Never ship or reuse a default bearer token. A device-local gateway receives its
# own generated token, while the remote token is added only by the user or the
# Contabo pairing procedure.
if ! grep -q '^OPENCLAW_AUTH_TOKEN=' "$ENV_FILE"; then
  LOCAL_TOKEN="$(openssl rand -hex 32 2>/dev/null || date +%s%N)"
  upsert_env OPENCLAW_AUTH_TOKEN "$LOCAL_TOKEN"
fi
upsert_env OPENCLAW_PORT "$OC_PORT"
upsert_env OPENCLAW_BIND "loopback"

cat > "$HOME/start-openclaw.sh" <<'START'
#!/usr/bin/env bash
set -Eeuo pipefail
set -a
[ -f "$HOME/.openclaw/.env" ] && . "$HOME/.openclaw/.env"
set +a
export OPENCLAW_HOME="$HOME/.openclaw"
export OPENCLAW_STATE_DIR="$HOME/.openclaw/state"
export OPENCLAW_CONFIG_PATH="$HOME/.openclaw/openclaw.json"
export OPENCLAW_WORKSPACE_DIR="$HOME/.openclaw/workspace"
mkdir -p "$OPENCLAW_STATE_DIR"
exec npx -y openclaw@latest gateway --port "${OPENCLAW_PORT:-18789}" --bind loopback --token "$OPENCLAW_AUTH_TOKEN"
START
chmod 700 "$HOME/start-openclaw.sh"

cat > "$HOME/evez-control.sh" <<'CONTROL'
#!/usr/bin/env bash
# Usage: evez-control.sh health | dashboard | chat "message"
set -Eeuo pipefail
set -a
[ -f "$HOME/.openclaw/.env" ] && . "$HOME/.openclaw/.env"
set +a
: "${EVEZ_REMOTE_GATEWAY:?Set the HTTPS Tailscale gateway URL in ~/.openclaw/.env}"
command -v curl >/dev/null 2>&1 || { echo 'curl is required' >&2; exit 127; }

case "${1:-}" in
  health)
    # Health is intentionally unauthenticated on the private Tailscale endpoint.
    # This proves mesh reachability even if a previously paired control token rotated.
    curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
      "$EVEZ_REMOTE_GATEWAY/healthz"
    ;;
  dashboard|chat)
    # OpenClaw Control uses its authenticated WebSocket protocol; the historical
    # /v1/chat REST path is not part of this gateway. Open the real Control UI.
    command -v termux-open-url >/dev/null 2>&1 && termux-open-url "$EVEZ_REMOTE_GATEWAY/" || true
    echo "Open the Control UI at: $EVEZ_REMOTE_GATEWAY/"
    echo 'Use the paired Control UI session for chat and actions.'
    ;;
  *)
    echo 'Usage: evez-control.sh health | dashboard | chat "message"' >&2
    exit 2
    ;;
esac
CONTROL
chmod 700 "$HOME/evez-control.sh"

cat > "$HOME/evez-health.sh" <<'HEALTH'
#!/usr/bin/env bash
set -Eeuo pipefail
if "$HOME/evez-control.sh" health; then
  command -v termux-notification >/dev/null 2>&1 && termux-notification --id 18789 --title 'EVEZ mesh' --content 'Remote gateway reachable' >/dev/null 2>&1 || true
  echo
else
  command -v termux-notification >/dev/null 2>&1 && termux-notification --id 18789 --title 'EVEZ mesh' --content 'Remote gateway unavailable' >/dev/null 2>&1 || true
  exit 1
fi
HEALTH
chmod 700 "$HOME/evez-health.sh"

cat > "$HOME/evez-mobile-setup.txt" <<'GUIDE'
1. Install and sign in to the Tailscale Android app using the same private mesh as Contabo.
2. Add EVEZ_REMOTE_GATEWAY=https://<your-private-gateway>/ and the device-specific EVEZ_REMOTE_TOKEN to ~/.openclaw/.env after the Contabo pairing flow completes.
3. Run ~/evez-control.sh health. This validates the private mesh even if an old control token has rotated.
4. Run ~/evez-control.sh dashboard (or ~/evez-control.sh chat "status") to open the authenticated OpenClaw Control UI for the remote response path.
5. Run ~/start-openclaw.sh only when you want a separate local, loopback-only OpenClaw gateway on the phone.
GUIDE

echo 'EVEZ A16 private command surface prepared.'
echo 'No default token, unauthenticated LAN binding, or public gateway was created.'
echo "After Contabo pairing: ~/evez-control.sh health"
