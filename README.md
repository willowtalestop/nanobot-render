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
| `NANOBOT_MODEL` | ✅ | Model identifier (default: `minimaxai/minimax-m2.7`) |
| `TELEGRAM_TOKEN` | ✅ | Telegram bot token from [@BotFather](https://t.me/BotFather) |
| `NVIDIA_API_KEY` | ✅ | NVIDIA NIM / NeMo API key |
| `PORT` | ✅ | Health‑check / dashboard port (default: `10000`) |

### Email Channel (optional)

> **Note:** Email requires a **Gmail App Password** (not your regular Google password).  
> Generate one at: **Google Account → Security → App passwords**

| Variable | Required | Description |
|----------|----------|-------------|
| `IMAP_HOST` | ✅ | IMAP server (Gmail: `imap.gmail.com`) |
| `IMAP_USERNAME` | ✅ | Email address |
| `IMAP_PASSWORD` | ✅ | App password |
| `IMAP_PORT` | | IMAP port (default: `993`) |
| `IMAP_MAILBOX` | | Mailbox to poll (default: `INBOX`) |
| `IMAP_USE_SSL` | | Use SSL for IMAP (default: `true`) |
| `SMTP_HOST` | ✅ | SMTP server (Gmail: `smtp.gmail.com`) |
| `SMTP_USERNAME` | ✅ | Email address |
| `SMTP_PASSWORD` | ✅ | App password |
| `SMTP_PORT` | | SMTP port (default: `587`) |
| `SMTP_USE_TLS` | | Use STARTTLS (default: `true`) |
| `SMTP_USE_SSL` | | Use SSL for SMTP (default: `false`) |
| `FROM_ADDRESS` | | Sender address shown in replies |
| `AUTO_REPLY_ENABLED` | | Auto‑reply to inbound mail (default: `true`) |
| `POLL_INTERVAL` | | Seconds between IMAP polls (default: `30`) |
| `VERIFY_DKIM` | | Enforce DKIM verification (default: `true`) |
| `VERIFY_SPF` | | Enforce SPF verification (default: `true`) |
| `ALLOWED_ATTACHMENT_TYPES` | | MIME types to allow (default: all `["*"]`) |
| `MAX_ATTACHMENT_SIZE` | | Max attachment size in bytes (default: `2000000`) |
| `MAX_ATTACHMENTS_PER_EMAIL` | | Max attachments per message (default: `5`) |

### rclone (optional)

| Variable | Required | Description |
|----------|----------|-------------|
| `RCLONE_CONFIG_BASE64` | | Base64‑encoded rclone config for cloud storage backup |

To generate the base64 string:

```powershell
# PowerShell
[System.Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes(
        Get-Content -Raw -Path "rclone.conf"
    )
)
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