#!/usr/bin/env bash
# In-place Hermes Agent recovery for an existing Contabo Linux installation.
# This script never pulls images, creates containers, deletes state, changes ports,
# rotates credentials, or disables authentication. Default mode is read-only.
set -Eeuo pipefail

MODE=check
RESTART_EXISTING=false

usage() {
  cat <<'USAGE'
Usage: evez-hermes-contabo-repair.sh [--apply] [--restart-existing]

  (default)             Inspect existing Hermes containers/services and listeners only.
  --apply               Start an existing stopped Hermes container or systemd service.
  --restart-existing    With --apply, restart an already running existing service.

Safety: no docker pull/run/rm, no package installation, no port publication, no
credential rotation, and no auth weakening. If no existing Hermes runtime is
found, this script exits with a diagnostic rather than installing one.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE=apply ;;
    --restart-existing) RESTART_EXISTING=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$RESTART_EXISTING" == true && "$MODE" != apply ]]; then
  echo '--restart-existing requires --apply' >&2
  exit 2
fi

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

containers=()
if command -v docker >/dev/null 2>&1; then
  while IFS=$'\t' read -r name image state; do
    [[ -n "$name" ]] || continue
    if [[ "$name $image" =~ [Hh]ermes ]]; then
      containers+=("$name")
      log "Existing Hermes container: name=$name state=$state image=$image"
    fi
  done < <(docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.State}}' 2>/dev/null || true)
fi

units=()
if command -v systemctl >/dev/null 2>&1; then
  while IFS= read -r unit; do
    [[ -n "$unit" ]] && units+=("$unit")
  done < <(systemctl list-unit-files 'hermes*.service' --no-legend 2>/dev/null | awk '{print $1}' || true)
fi

if [[ ${#containers[@]} -eq 0 && ${#units[@]} -eq 0 ]]; then
  log 'No existing Hermes container or hermes*.service unit was found.'
  log 'No installation was attempted. Inspect the authenticated host for a custom service name or a loopback-only process.'
  exit 3
fi

if [[ "$MODE" == apply ]]; then
  for name in "${containers[@]}"; do
    state="$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo unknown)"
    if [[ "$state" != true ]]; then
      log "Starting existing Hermes container: $name"
      docker start "$name" >/dev/null
    elif [[ "$RESTART_EXISTING" == true ]]; then
      log "Restarting existing Hermes container: $name"
      docker restart "$name" >/dev/null
    else
      log "Existing Hermes container already running: $name"
    fi
  done

  for unit in "${units[@]}"; do
    if systemctl is-active --quiet "$unit"; then
      if [[ "$RESTART_EXISTING" == true ]]; then
        log "Restarting existing Hermes unit: $unit"
        systemctl restart "$unit"
      else
        log "Existing Hermes unit already active: $unit"
      fi
    else
      log "Starting existing Hermes unit: $unit"
      systemctl start "$unit"
    fi
  done
fi

log 'Listener snapshot (expected Hermes defaults are 8642 gateway/API and 9119 dashboard):'
if command -v ss >/dev/null 2>&1; then
  ss -ltnp 2>/dev/null | grep -E ':(8642|9119)\b' || log 'No listener on 8642 or 9119 is currently visible.'
fi

for url in http://127.0.0.1:8642/health http://127.0.0.1:9119/api/status; do
  if command -v curl >/dev/null 2>&1; then
    status="$(curl --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 3 --max-time 8 "$url" || true)"
    log "Read-only probe $url -> HTTP ${status:-network-error}"
  fi
done

log 'Hermes in-place recovery check complete.'
