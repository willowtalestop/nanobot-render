# Use Python 3.12 slim for a smaller footprint
FROM python:3.12-slim

USER root

# Install system dependencies including jq for config verification
RUN apt-get update && apt-get install -y \
    curl git jq sudo unzip procps \
    && curl https://rclone.org/install.sh | sudo bash \
    && rm -rf /var/lib/apt/lists/*

# Setup the user and application directories
RUN useradd -m -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN mkdir -p /home/user/.nanobot /home/user/app \
    && chown -R user:user /home/user

WORKDIR /home/user/app

# Install the Nanobot AI library
RUN pip install --no-cache-dir nanobot-ai

# Create the startup script with variable injection logic
COPY <<EOF /home/user/app/start.sh
#!/bin/bash
set -e

# 1. Start a tiny background web server for Render Health Checks (Free Tier)
# This prevents the "Port not found" error.
python3 -m http.server \${PORT:-10000} &

# 2. Rclone Configuration
if [ -n "\$RCLONE_CONFIG_BASE64" ]; then
    echo "Configuring rclone..."
    echo "\$RCLONE_CONFIG_BASE64" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# 3. Create Nanobot Workspace structures
mkdir -p /home/user/.nanobot/workspace/memory
if [ ! -f "/home/user/.nanobot/workspace/SOUL.md" ]; then
    echo "You are a professional AI assistant for Automatte Asia." > /home/user/.nanobot/workspace/SOUL.md
fi

# 4. Generate the config.json using Render's Environment Variables
# Note: We use the EOF without quotes to allow variable expansion
cat <<CONF > /home/user/.nanobot/config.json
{
  "agents": {
    "defaults": {
      "workspace": "/home/user/.nanobot/workspace",
      "model": "\${NANOBOT_MODEL:-nvidia/llama-3.1-8b-instruct}",
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

# 5. Pre-flight verification
echo "Checking configuration..."
if [ -z "\$NVIDIA_API_KEY" ]; then
    echo "ERROR: NVIDIA_API_KEY is not set in Render Environment Variables."
    exit 1
fi

# Verify the JSON structure (hiding the sensitive key)
jq 'del(.providers.openai.apiKey)' /home/user/.nanobot/config.json

# 6. Start the Nanobot Gateway
echo "Starting Nanobot Gateway..."
exec nanobot gateway
EOF

# Set permissions and switch to non-root user
RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user

# Render expects the service to be available on port 10000 by default
EXPOSE 10000

# Execute the startup script
CMD ["./start.sh"]