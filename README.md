# EVEZ OpenClaw Deploy

Pre-configured OpenClaw personal AI agent — maxed out with 60 plugins, 27+ models, Telegram/Slack channels, and model fallback chains.

## Quick Start

### Option 1: Docker (recommended for Galaxy A16 + PC setup)
```bash
git clone https://github.com/EvezArt/evez-openclaw-deploy.git
cd evez-openclaw-deploy
cp .env.example .env
# Add your API keys to .env
docker compose up -d
# Dashboard: http://localhost:18789
```

### Option 2: Local Install
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
cp openclaw.json ~/.openclaw/openclaw.json
cp .env.example ~/.openclaw/.env
# Edit ~/.openclaw/.env with your keys
openclaw gateway
```

### Option 3: Fly.io (cloud, always-on)
```bash
fly launch --config fly.toml
fly secrets set GROQ_API_KEY=... OPENROUTER_API_KEY=...
fly deploy
```

## Mobile App
See [evez-openclaw-apk](https://github.com/EvezArt/evez-openclaw-apk) for the Android app (Galaxy A16).

## What's Configured

| Category | Count | Details |
|----------|-------|---------|
| Plugins  | 60    | All available plugins enabled |
| Models   | 27+   | Groq, OpenRouter, GitHub Copilot, DeepSeek, etc. |
| Channels | 2     | Telegram, Slack |
| Fallbacks| 4     | Auto-failover: Groq → Claude → Gemini → DeepSeek → Llama-8b |
| Thinking | High  | Extended reasoning enabled |

## Telegram Setup
1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. `/newbot` → name it "EVEZ OpenClaw"
3. Copy the bot token
4. Add to `.env`: `TELEGRAM_BOT_TOKEN=your_token`
5. Restart: `docker compose restart`

## Built by Viktor AI for EVEZ
