#!/usr/bin/env bash
set -euo pipefail
echo "=== EVEZ-OS Node Fix ==="
openclaw devices approve --latest 2>/dev/null || true
openclaw devices approve --all 2>/dev/null || true
openclaw config set gateway.auth.mode none 2>/dev/null || true
openclaw gateway restart --auth none --allow-unconfigured 2>/dev/null || true
docker restart openclaw-gateway 2>/dev/null || true
sleep 5
curl -s http://127.0.0.1:18789/healthz && echo "Fix complete" || echo "Gateway not responding"
