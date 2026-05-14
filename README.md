# Automatte Nanobot – Render Deployment

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Docker-blue)

A ready‑to‑deploy Docker image for [Automatte Nanobot](https://github.com/automatte-asia/nanobot) that turns a single server into an AI‑powered gateway with support for multiple chat platforms, tool‑calling, and optional e‑mail integration.

---

## Features

- **Multi‑platform** – Telegram (built‑in) + optional Email channel  
- **GPU‑accelerated inference** – MiniMax M2.7 model by default (configurable)  
- **Tool‑calling** – filesystem, cron, websocket, MCP, notebook, and message tools  
- **Observability** – Langfuse tracing, structured logging via Loguru  
- **Cloud storage** – Optional rclone backup to Google Drive, S3, etc.  
- **Web dashboard** – Live status page at `http://<host>:10000`

---

## Quick Start

```bash
# 1. Clone / pull the repo
git clone https://github.com/m4ttgit/nanobot-render.git
cd nanobot-render

# 2. Copy the example env and fill in your secrets
cp .env.example .env
# Edit .env with your real credentials

# 3. Build & run
docker build -t automatte-nanobot .
docker run -d --env-file .env -p 10000:10000 automatte-nanobot
```

Open `http://localhost:10000` to see the live dashboard.

---

## Environment Variables

All configuration is driven by environment variables – no need to rebuild the image for most changes.

### Core

| Variable | Required | Description |
|----------|----------|-------------|
| `NANOBOT_MODEL` | | Model identifier — defaults depend on active provider (see below) |
| `TELEGRAM_TOKEN` | ✅ | Telegram bot token from [@BotFather](https://t.me/BotFather) |
| `OPENROUTER_API_KEY` | * | OpenRouter API key — [sign up at https://openrouter.ai/](https://openrouter.ai/) |
| `NVIDIA_API_KEY` | * | NVIDIA NIM / NeMo API key — [get one at https://build.nvidia.com/](https://build.nvidia.com/) |
| `PORT` | ✅ | Health‑check / dashboard port (default: `10000`) |

> **How it works:** The container auto‑detects which provider to use.
> - If `OPENROUTER_API_KEY` is set → **OpenRouter** (default model: `google/gemini-2.0-flash`)
> - If `NVIDIA_API_KEY` is set → **NVIDIA NIM** (default model: `minimaxai/minimax-m2.7`)
> - If both are set → **OpenRouter wins** (with a warning in the logs)
> - If neither is set → **container refuses to start** with a clear error message
>
> Override the default model by setting `NANOBOT_MODEL` to any model supported by the active provider.

### Provider quick reference

| Provider | Default model | API key variable | Where to get a key |
|----------|---------------|------------------|--------------------|
| OpenRouter | `google/gemini-2.0-flash` | `OPENROUTER_API_KEY` | https://openrouter.ai/ |
| NVIDIA NIM | `minimaxai/minimax-m2.7` | `NVIDIA_API_KEY` | https://build.nvidia.com/ |

### Switching providers

1. Open your `.env` file (or Render environment settings).
2. **Set the API key** for the provider you want to use (`OPENROUTER_API_KEY` or `NVIDIA_API_KEY`).
3. **Remove or clear** the key for the other provider (optional — the active provider's key takes precedence).
4. Optionally change `NANOBOT_MODEL` to a compatible model for the new provider.
5. Rebuild and redeploy:
   ```bash
   docker build -t automatte-nanobot .
   docker run -d --env-file .env -p 10000:10000 automatte-nanobot
   ```

### Using a specific provider's env file (local dev only)

Two ready‑made env files are provided:

```bash
# NVIDIA NIM
cp .env.example.nvidia .env

# OpenRouter
cp .env.example.openrouter .env
```

### Email Channel (optional)

### Switching providers

1. Open your `.env` file.
2. Set `LLM_PROVIDER` to `nvidia` or `openrouter`.
3. Provide the matching API key (`NVIDIA_API_KEY` or `OPENROUTER_API_KEY`).
4. If switching to OpenRouter, consider changing `NANOBOT_MODEL` to a compatible model (e.g. `google/gemini-2.0-flash`).
5. Rebuild and redeploy:
   ```bash
   docker build -t automatte-nanobot .
   docker run -d --env-file .env -p 10000:10000 automatte-nanobot
   ```

---

## Docker Compose

```yaml
version: "3.9"
services:
  nanobot:
    image: ghcr.io/m4ttgit/nanobot-render:latest   # or your own registry
    ports:
      - "10000:10000"
    env_file:
      - .env
    restart: unless-stopped
```

---

## Render Deployment

1. Connect this repository to Render (GitHub integration).  
2. In **Settings → Environment**, add the variables from your `.env` file.  
3. Click **Deploy**.  

Or use the `render.yaml` included in this repo – just uncomment the email block and fill in the values.

---

## Project Structure

```
.
├── Dockerfile            # Production Docker image
├── docker-compose.yml    # (optional) local compose override
├── render.yaml           # Render.com service definition
├── .env.example          # Example env vars (copy to .env)
├── .gitignore            # Secrets & build artifacts
└── README.md             # You are here
```

---

## Updating

```bash
# Pull latest changes
git pull origin master

# Rebuild (if Dockerfile changed)
docker build -t automatte-nanobot .

# Restart with new image
docker stop nanobot && docker rm nanobot
docker run -d --env-file .env -p 10000:10000 --name nanobot automatte-nanobot
```

---

## License

MIT License – see [LICENSE](LICENSE) for details.