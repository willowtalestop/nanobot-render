FROM python:3.12-slim

USER root

# 1. Install System Dependencies + Node.js 20 (LTS)
RUN apt-get update && apt-get install -y \
    curl git jq sudo unzip procps ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && curl https://rclone.org/install.sh | sudo bash \
    && rm -rf /var/lib/apt/lists/*

# 2. Setup User
RUN useradd -m -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN mkdir -p /home/user/.nanobot /home/user/app \
    && chown -R user:user /home/user

WORKDIR /home/user/app

# 3. Install Nanobot (Python)
RUN pip install --no-cache-dir nanobot-ai

# 4. Startup Script
COPY <<'EOF' /home/user/app/start.sh
#!/bin/bash
set -e

# ── model selection ──────────────────────────────────────────────
CURRENT_MODEL="${NANOBOT_MODEL:-minimaxai/minimax-m2.7}"

# ── static HTML dashboard ────────────────────────────────────────
cat <<HTML > /home/user/app/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Automatte Asia | Nanobot Gateway</title>
  <style>
    body{font-family:'Inter',-apple-system,sans-serif;background:#0d1117;color:#c9d1d9;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}
    .container{text-align:center;background:#161b22;padding:3rem;border-radius:16px;border:1px solid #30363d;box-shadow:0 10px 30px rgba(0,0,0,.5);max-width:440px;width:90%}
    .logo{font-size:1.5rem;font-weight:700;color:#f0f6fc;margin-bottom:.5rem}
    .status-badge{display:inline-flex;align-items:center;background:rgba(35,134,54,.1);color:#3fb950;padding:6px 12px;border-radius:20px;font-size:.85rem;font-weight:600;margin-bottom:2rem;border:1px solid rgba(63,185,80,.3)}
    .pulse{width:8px;height:8px;background:#3fb950;border-radius:50%;margin-right:8px;animation:pulse 2s infinite}
    @keyframes pulse{0%{box-shadow:0 0 0 0 rgba(63,185,80,.7)}70%{box-shadow:0 0 0 10px rgba(63,185,80,0)}100%{box-shadow:0 0 0 0 rgba(63,185,80,0)}}
    .model-info{background:#0d1117;padding:1rem;border-radius:8px;font-family:monospace;font-size:.85rem;color:#79c0ff;border:1px solid #30363d;word-break:break-all}
    .footer{margin-top:2rem;font-size:.75rem;color:#484f58}
  </style>
</head>
<body>
  <div class="container">
    <div class="status-badge"><div class="pulse"></div>Gateway Active</div>
    <div class="logo">Automatte Nanobot</div>
    <p style="color:#8b949e;margin-bottom:2rem">Turbo Mode: Enabled</p>
    <div class="model-info">
      <div style="font-size:.65rem;color:#8b949e;margin-bottom:4px;text-transform:uppercase">Active Engine</div>
      ${CURRENT_MODEL}
    </div>
    <div class="footer">&copy; 2026 Automatte Asia</div>
  </div>
</body>
</html>
HTML

# ── health server ────────────────────────────────────────────────
python3 -m http.server ${PORT:-10000} &

# ── rclone (optional) ───────────────────────────────────────────
if [ -n "${RCLONE_CONFIG_BASE64}" ]; then
  echo "${RCLONE_CONFIG_BASE64}" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# ── workspace ────────────────────────────────────────────────────
mkdir -p /home/user/.nanobot/workspace/memory

# ── build config.json ────────────────────────────────────────────
# Base structure (always present)
cat > /home/user/.nanobot/config.json <<CONF
{
  "agents": {
    "defaults": {
      "workspace": "/home/user/.nanobot/workspace",
      "model": "${CURRENT_MODEL}",
      "provider": "openai"
    }
  },
  "providers": {
    "openai": {
      "apiKey": "${NVIDIA_API_KEY}",
      "apiBase": "https://integrate.api.nvidia.com/v1"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_TOKEN}",
      "allowFrom": ["*"]
    }
  }
}
CONF

# ── optional e‑mail channel ──────────────────────────────────────
# If *all* of the required e‑mail env vars are set, we inject the
# email channel block into the just‑created config.
if [ -n "${IMAP_HOST}" ] && [ -n "${IMAP_USERNAME}" ] && [ -n "${IMAP_PASSWORD}" ] && \
   [ -n "${SMTP_HOST}" ] && [ -n "${SMTP_USERNAME}" ] && [ -n "${SMTP_PASSWORD}" ]; then

  # Build the JSON fragment (properly escaped for jq)
  EMAIL_BLOCK=$(cat <<-EMAIL
{
  "enabled": true,
  "consentGranted": true,
  "imapHost": "${IMAP_HOST}",
  "imapPort": ${IMAP_PORT:-993},
  "imapUsername": "${IMAP_USERNAME}",
  "imapPassword": "${IMAP_PASSWORD}",
  "imapMailbox": "${IMAP_MAILBOX:-INBOX}",
  "imapUseSsl": ${IMAP_USE_SSL:-true},
  "smtpHost": "${SMTP_HOST}",
  "smtpPort": ${SMTP_PORT:-587},
  "smtpUsername": "${SMTP_USERNAME}",
  "smtpPassword": "${SMTP_PASSWORD}",
  "smtpUseTls": ${SMTP_USE_TLS:-true},
  "smtpUseSsl": ${SMTP_USE_SSL:-false},
  "fromAddress": "${FROM_ADDRESS:-}",
  "autoReplyEnabled": ${AUTO_REPLY_ENABLED:-true},
  "pollIntervalSeconds": ${POLL_INTERVAL:-30},
  "markSeen": ${MARK_SEEN:-true},
  "maxBodyChars": ${MAX_BODY_CHARS:-12000},
  "subjectPrefix": "${SUBJECT_PREFIX:-Re: }",
  "verifyDkim": ${VERIFY_DKIM:-true},
  "verifySpf": ${VERIFY_SPF:-true},
  "allowedAttachmentTypes": ${ALLOWED_ATTACHMENT_TYPES:-[]},
  "maxAttachmentSize": ${MAX_ATTACHMENT_SIZE:-2000000},
  "maxAttachmentsPerEmail": ${MAX_ATTACHMENTS_PER_EMAIL:-5}
}
EMAIL
)

  # Merge the fragment into the existing config (requires jq)
  jq --argjson email "$EMAIL_BLOCK" '.channels.email = $email' \
     /home/user/.nanobot/config.json > /tmp/config.tmp && \
  mv /tmp/config.tmp /home/user/.nanobot/config.json

  echo "✅ Email channel configured (IMAP ${IMAP_HOST}, SMTP ${SMTP_HOST})"
else
  echo "ℹ️  No e‑mail env vars supplied – e‑mail channel stays disabled."
fi

echo "Gateway initialized with ${CURRENT_MODEL}"
exec nanobot gateway
EOF

RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user
EXPOSE 10000
CMD ["./start.sh"]