# EVEZ Private Command Mesh

## Purpose

This repository defines a **private, mobile-first command mesh** centered on the Contabo OpenClaw Control UI. The mesh uses the Tailscale tailnet as the transport boundary, keeps every OpenClaw gateway loopback-bound on its host, and uses an authenticated Control UI session for interactive operations. No public gateway binding, default bearer token, or anonymous mobile control surface is created.

## Canonical Control Plane

| Component | Canonical role | Private route | Security boundary |
|---|---|---|---|
| Contabo `evezos-contabo` | Primary OpenClaw gateway and Control UI | `https://evezos-contabo.tail613e80.ts.net/` | Tailscale transport plus OpenClaw gateway/device authentication |
| Contabo health endpoint | Non-invasive reachability proof | `https://evezos-contabo.tail613e80.ts.net/healthz` | Private mesh only; intentionally unauthenticated health result |
| Samsung Galaxy A16 | Mobile control surface | Tailscale Android client → private Control UI | Device pairing and its device-specific control token |
| A16 local OpenClaw option | Optional loopback-only local node | `http://127.0.0.1:18789` on the phone | Device-local token; never LAN-bound |
| Contabo Hermes Agent runtime | Separate Linux-host agent runtime; not currently verified as live | **No verified private endpoint** | Requires authenticated host inspection; must remain private and authenticated after restoration |
| GitHub deployment repo | Declarative recovery and mobile bootstrap source | `EvezArt/evez-openclaw-deploy` | No runtime secret values committed |

> The Contabo Control UI is the authoritative interactive surface. The phone uses the same private URL; it does not expose a second public control plane.

## Mobile Command Contract

The Galaxy A16 bootstrap writes the following safe defaults into `~/.openclaw/.env` only when they are absent:

| Variable | Meaning | Source of truth |
|---|---|---|
| `EVEZ_REMOTE_GATEWAY` | Private Contabo Control UI URL | Defaults to `https://evezos-contabo.tail613e80.ts.net` |
| `EVEZ_REMOTE_TOKEN` | Paired device-specific OpenClaw control token | Created only by the Contabo pairing flow; never placed in Git |
| `OPENCLAW_AUTH_TOKEN` | Token for the optional phone-local loopback gateway | Generated per phone by the bootstrap |
| `OPENCLAW_BIND` | Phone-local exposure boundary | Always `loopback` |

After Tailscale is connected on the phone, the command surface is deliberately split in two:

```bash
~/evez-control.sh health
~/evez-control.sh dashboard
```

The first command validates private-mesh reachability through `/healthz`, including after a control-token rotation. The second opens the genuine authenticated Control UI, whose WebSocket protocol handles chat, pairing, and gateway operations. A historical `/v1/chat` REST shortcut is not used because the Control UI gateway does not provide it.

## Hermes Agent Runtime Contract

In this system, **Hermes Agent** means the separate NousResearch-style agent runtime expected on the Contabo Linux host. It is not an OpenRouter model identifier and it is not served by the OpenClaw Control UI. The conventional local surfaces are port `8642` for the gateway/API health endpoint and port `9119` for the dashboard.

The latest private-mesh probes returned host-side connection refusal on both ports, and the Tailscale HTTPS front door has no Hermes-specific route. Consequently, there is **no Hermes private URL to distribute yet**. Hermes may be stopped, loopback-only, un-published from its existing container, or absent. An authenticated on-host administrative session is required to inspect and repair that state without creating a new runtime, pulling an image, deleting state, changing credentials, or weakening authentication.

For an authenticated recovery session, `scripts/evez-hermes-contabo-repair.sh` is safe by default: it reads existing Hermes container/service state and listener health only. Its explicit `--apply` mode may start an already existing stopped Hermes container or `hermes*.service`, but deliberately never installs, pulls, creates, deletes, publishes, or reconfigures a resource.

## Zero-Cost Model Contract

The recovery path verifies the live OpenRouter catalog before applying a model route. The stable zero-cost order is:

1. `openrouter/free` as a resilient free-provider router.
2. `openai/gpt-oss-20b:free`.
3. `google/gemma-4-31b-it:free`.
4. `nvidia/nemotron-3-super-120b-a12b:free`.
5. `z-ai/glm-5.2:free`.
6. `google/gemma-4-26b-a4b-it:free`.

When a Groq key is available, Groq remains primary and the complete free OpenRouter sequence stays behind it. The Contabo repair script independently retrieves the current catalog and makes bounded live completion probes before it writes the final configuration; this avoids permanently trusting stale free-model aliases.

## EVEZ Surface Roles

| EVEZ surface | Mesh role |
|---|---|
| `evez-openclaw-deploy` | Gateway configuration, live-catalog recovery, A16 bootstrap, and this contract |
| `openclaw-runtime` | WebSocket and event-stream implementation reference for phone/node patterns |
| `evez-openclaw-apk` | Native Android WebView wrapper for the same Control UI |
| `evez-os` and `evez-spine` | Event semantics and audit/event-spine substrate |
| `evez-agentnet` | Secondary agent-network runtime configuration |
| `evez-vcl` | Visual topology/observability surface |
| `evez-watchdog` and `evez-status` | Health-monitoring and recovery-pattern sources |

## Operating Rules

The mesh follows four operating rules. First, health checks are safe and private; interactive actions require a paired device session. Second, a service restart or repair must validate the current model catalog instead of reusing historical free aliases. Third, the A16 is a control surface, not an exposed server: its optional local gateway stays loopback-only. Fourth, the host’s current OpenClaw token remains host-local and must not be copied into repository files, logs, or documentation.

## Current Recovery State

The private Contabo health endpoint and Control UI WebSocket are responsive. This repository contains the corrected free-model routing, the A16 private-gateway defaults, and a staged non-destructive Hermes runtime inspection/restart script. Hermes itself is not currently proven live: its standard private ports `8642` and `9119` refuse connections, and the host refuses tailnet SSH. Applying any existing-runtime Hermes repair therefore still requires an authenticated on-host administrative session; no reset, reinstallation, disk operation, image pull, public exposure, or authentication bypass is part of that path.
