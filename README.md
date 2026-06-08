# EVEZ OpenClaw Deploy

Pre-configured OpenClaw personal AI agent with Groq + OpenRouter providers, 7 plugins, and EVEZ workspace identity.

## Quick Start

### Option 1: Local Install (fastest)
```bash
# Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash

# Copy config
cp openclaw.json ~/.openclaw/openclaw.json
cp .env.example ~/.openclaw/.env
# Edit .env with your API keys

# Start
openclaw gateway
```

### Option 2: Docker (persistent)
```bash
cp .env.example .env
# Edit .env with your API keys
docker compose up -d
# Dashboard: http://localhost:18789
```

### Option 3: Fly.io (cloud, always-on)
```bash
fly launch --config fly.toml
fly secrets set GROQ_API_KEY=your_key OPENROUTER_API_KEY=your_key
fly deploy
# Dashboard: https://evez-openclaw.fly.dev
```

## What's Configured

### Models (27 available)
- **Default:** `groq/llama-3.3-70b-versatile` (ultra-fast via Groq)
- **Groq:** llama-3.3-70b, llama-3.1-8b, compound, qwen3-32b
- **OpenRouter:** 200+ models (Claude, GPT, Gemini, Deepseek, etc.)

### Plugins (7 loaded)
- `browser` — web browsing and scraping
- `canvas` — visual generation
- `memory-core` — persistent agent memory
- `talk-voice` — voice input/output
- `device-pair` — multi-device sync
- `file-transfer` — file sharing
- `phone-control` — mobile integration

### Workspace
- `SOUL.md` — EVEZ agent identity and mission
- `AGENTS.md` — model catalog and tool reference

## Dashboard
Once running, open `http://localhost:18789` for the OpenClaw Control web UI.

## Built by Viktor AI for EVEZ
