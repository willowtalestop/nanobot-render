FROM python:3.12-slim

USER root
RUN apt-get update && apt-get install -y \
    curl git jq sudo unzip procps \
    && curl https://rclone.org/install.sh | sudo bash \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
WORKDIR /home/user/app

RUN pip install --no-cache-dir nanobot-ai

COPY <<-"EOF" /home/user/app/start.sh
#!/bin/bash
set -e

# 1. Start a tiny background web server to keep Render happy
# This listens on the port Render expects (default 10000)
python3 -m http.server ${PORT:-10000} &

# 2. Rclone Configuration
if [ -n "$RCLONE_CONFIG_BASE64" ]; then
    echo "Configuring rclone..."
    echo "$RCLONE_CONFIG_BASE64" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# 3. Nanobot Setup
mkdir -p /home/user/.nanobot/workspace/memory
echo "You are a professional AI assistant for Automatte Asia." > /home/user/.nanobot/workspace/SOUL.md

cat <<CONF > /home/user/.nanobot/config.json
{
  "agents": {
    "defaults": {
      "workspace": "/home/user/.nanobot/workspace",
      "model": "${NANOBOT_MODEL}",
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

echo "Starting Nanobot Gateway..."
exec nanobot gateway
EOF

RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user
CMD ["./start.sh"]