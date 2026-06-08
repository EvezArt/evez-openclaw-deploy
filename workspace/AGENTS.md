# EVEZ Agent Configuration — Full Catalog

## Default Model
`groq/llama-3.3-70b-versatile` with fallbacks:
1. `openrouter/anthropic/claude-sonnet-4`
2. `openrouter/google/gemini-2.5-pro`
3. `openrouter/deepseek/deepseek-r1`
4. `groq/llama-3.1-8b-instant`

## Available Models by Provider

### Groq (Ultra-fast, free tier)
- llama-3.3-70b-versatile ⭐ (default)
- llama-3.1-8b-instant
- compound / compound-mini
- qwen/qwen3-32b
- meta-llama/llama-4-scout-17b-16e-instruct
- openai/gpt-oss-120b / gpt-oss-20b

### OpenRouter (200+ models via single key)
- anthropic/claude-sonnet-4, claude-opus-4
- openai/gpt-4o, gpt-4-turbo
- google/gemini-2.5-pro, gemini-2.5-flash
- deepseek/deepseek-r1, deepseek-v3
- meta-llama/llama-3.3-70b-instruct
- moonshotai/kimi-k2.5, kimi-k2.6

### GitHub Copilot
- claude-opus-4.6/4.7/4.8
- claude-sonnet-4.6
- gemini-2.5-pro, gemini-3-flash, gemini-3.1-pro
- gpt-5.3-codex, gpt-5.4, gpt-5.5
- goldeneye, raptor-mini

## Plugins Loaded (17 active)
- active-memory: persistent agent memory across sessions
- admin-http-rpc: remote administration API
- browser: web browsing and scraping
- canvas: visual generation
- device-pair: multi-device sync (phone ↔ PC)
- file-transfer: file sharing
- llm-task: background LLM task execution
- memory-core: core memory system
- memory-wiki: wiki-style knowledge base
- openrouter: 200+ model provider
- phone-control: mobile integration
- policy: agent behavior policies
- talk-voice: voice I/O
- telegram: Telegram messenger channel
- thread-ownership: multi-user session management
- webhooks: HTTP webhook integrations
- workboard: task/project management

## Channels
- Telegram (configure TELEGRAM_BOT_TOKEN)
- Slack (configure SLACK_BOT_TOKEN + SLACK_APP_TOKEN)
- SMS, Signal available with additional setup

## Tools
- Web search (DuckDuckGo, Exa, Perplexity, Tavily, SearXNG)
- Browser automation
- Document extraction
- Image/video generation (Fal, ComfyUI, Runway)
- Voice (Deepgram, ElevenLabs, Azure Speech)
- Code execution (Codex supervisor)
