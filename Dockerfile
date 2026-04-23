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
COPY <<EOF /home/user/app/start.sh
#!/bin/bash
set -e

# Capture the model - Now defaulting to MiniMax
CURRENT_MODEL="\${NANOBOT_MODEL:-minimaxai/minimax-m2.7}"

# Dashboard HTML
cat <<HTML > /home/user/app/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Automatte Asia | Nanobot Gateway</title>
    <style>
        body { font-family: 'Inter', -apple-system, sans-serif; background-color: #0d1117; color: #c9d1d9; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .container { text-align: center; background: #161b22; padding: 3rem; border-radius: 16px; border: 1px solid #30363d; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 440px; width: 90%; }
        .logo { font-size: 1.5rem; font-weight: 700; color: #f0f6fc; margin-bottom: 0.5rem; }
        .status-badge { display: inline-flex; align-items: center; background: rgba(35, 134, 54, 0.1); color: #3fb950; padding: 6px 12px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; margin-bottom: 2rem; border: 1px solid rgba(63, 185, 80, 0.3); }
        .pulse { width: 8px; height: 8px; background: #3fb950; border-radius: 50%; margin-right: 8px; animation: pulse 2s infinite; }
        @keyframes pulse { 0% { box-shadow: 0 0 0 0 rgba(63, 185, 80, 0.7); } 70% { box-shadow: 0 0 0 10px rgba(63, 185, 80, 0); } 100% { box-shadow: 0 0 0 0 rgba(63, 185, 80, 0); } }
        .model-info { background: #0d1117; padding: 1rem; border-radius: 8px; font-family: monospace; font-size: 0.85rem; color: #79c0ff; border: 1px solid #30363d; word-break: break-all; }
        .footer { margin-top: 2rem; font-size: 0.75rem; color: #484f58; }
    </style>
</head>
<body>
    <div class="container">
        <div class="status-badge"><div class="pulse"></div> Gateway Active</div>
        <div class="logo">Automatte Nanobot</div>
        <p style="color: #8b949e; margin-bottom: 2rem;">Turbo Mode: Enabled</p>
        <div class="model-info">
            <div style="font-size: 0.65rem; color: #8b949e; margin-bottom: 4px; text-transform: uppercase;">Active Engine</div>
            \$CURRENT_MODEL
        </div>
        <div class="footer">&copy; 2026 Automatte Asia</div>
    </div>
</body>
</html>
HTML

# Start health server
python3 -m http.server \${PORT:-10000} &

# Rclone
if [ -n "\$RCLONE_CONFIG_BASE64" ]; then
    echo "\$RCLONE_CONFIG_BASE64" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# Workspace/Config
mkdir -p /home/user/.nanobot/workspace/memory
cat <<CONF > /home/user/.nanobot/config.json
{
  "agents": {
    "defaults": {
      "workspace": "/home/user/.nanobot/workspace",
      "model": "\$CURRENT_MODEL",
      "provider": "openai"
    }
  },
  "providers": {
    "openai": {
      "apiKey": "\${NVIDIA_API_KEY}",
      "apiBase": "https://integrate.api.nvidia.com/v1"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "\${TELEGRAM_TOKEN}",
      "allowFrom": ["*"]
    }
  }
}
CONF

echo "Gateway initialized with \$CURRENT_MODEL"
exec nanobot gateway
EOF

RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user
EXPOSE 10000
CMD ["./start.sh"]