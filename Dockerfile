FROM python:3.12-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl git jq sudo unzip \
    && curl https://rclone.org/install.sh | sudo bash \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -u 1000 user
WORKDIR /home/user/app

# Install Nanobot
RUN pip install --no-cache-dir nanobot-ai

# Build the startup script
COPY <<-"EOF" /home/user/app/start.sh
#!/bin/bash
set -e

# Initialize Rclone
if [ -n "$RCLONE_CONFIG_BASE64" ]; then
    echo "$RCLONE_CONFIG_BASE64" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# Setup Nanobot Workspace
mkdir -p /home/user/.nanobot/workspace/memory
echo "You are a professional AI assistant for Automatte Asia." > /home/user/.nanobot/workspace/SOUL.md

# Create Config
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

exec nanobot gateway
EOF

RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user
CMD ["./start.sh"]