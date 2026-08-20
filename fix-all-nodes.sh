#!/usr/bin/env bash
# Compatibility entry point for the secure Contabo recovery workflow.
# It intentionally preserves token authentication and loopback-only gateway binding.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/scripts/evez-openclaw-contabo-repair.sh"
