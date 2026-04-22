# Use Python 3.12 slim for a smaller footprint
FROM python:3.12-slim

USER root

# Install system dependencies
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

# Create the startup script with the enhanced Dark Theme HTML
COPY <<EOF /home/user/app/start.sh
#!/bin/bash
set -e

# 1. Create a sleek Dark Theme Dashboard
cat <<HTML > /home/user/app/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Automatte Asia | Nanobot Gateway</title>
    <style>
        body {
            font-family: 'Inter', -apple-system, sans-serif;
            background-color: #0d1117;
            color: #c9d1d9;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            text-align: center;
            background: #161b22;
            padding: 3rem;
            border-radius: 16px;
            border: 1px solid #30363d;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            max-width: 400px;
            width: 90%;
        }
        .logo {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f0f6fc;
            margin-bottom: 0.5rem;
            letter-spacing: -0.5px;
        }
        .status-badge {
            display: inline-flex;
            align-items: center;
            background: rgba(35, 134, 54, 0.1);
            color: #3fb950;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 600;
            margin-bottom: 2rem;
            border: 1px solid rgba(63, 185, 80, 0.3);
        }
        .pulse {
            width: 8px;
            height: 8px;
            background: #3fb950;
            border-radius: 50%;
            margin-right: 8px;
            box-shadow: 0 0 0 rgba(63, 185, 80, 0.4);
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { box-shadow: 0 0 0 0 rgba(63, 185, 80, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(63, 185, 80, 0); }
            100% { box-shadow: 0 0 0 0 rgba(63, 185, 80, 0); }
        }
        .model-info {
            background: #21262d;
            padding: 1rem;
            border-radius: 8px;
            font-family: monospace;
            font-size: 0.9rem;
            color: #8b949e;
            border: 1px solid #30363d;
        }
        .footer {
            margin-top: 2rem;
            font-size: 0.75rem;
            color: #484f58;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="status-badge">
            <div class="pulse"></div> Gateway Active
        </div>
        <div class="logo">Automatte Nanobot</div>
        <p style="color: #8b949e; margin-bottom: 2rem;">Agency-grade automation gateway is running.</p>
        <div class="model-info">
            Model: \${NANOBOT_MODEL:-nvidia/llama-3.1-8b-instruct}
        </div>
        <div class="footer">
            &copy; 2026 Automatte Asia. All rights reserved.
        </div>
    </div>
</body>
</html>
HTML

# 2. Start the web server for Render Health Checks
python3 -m http.server \${PORT:-10000} &

# 3. Rclone Configuration
if [ -n "\$RCLONE_CONFIG_BASE64" ]; then
    echo "Configuring rclone..."
    echo "\$RCLONE_CONFIG_BASE64" | tr -dc 'A-Za-z0-9+/=' | base64 -d > /home/user/rclone.conf
fi

# 4. Create Nanobot Workspace
mkdir -p /home/user/.nanobot/workspace/memory
if [ ! -f "/home/user/.nanobot/workspace/SOUL.md" ]; then
    echo "You are a professional AI assistant for Automatte Asia." > /home/user/.nanobot/workspace/SOUL.md
fi

# 5. Generate the config.json
cat <<CONF > /home/user/.nanobot/config.json
{
  "agents": {
    "defaults": {
      "workspace": "/home/user/.nanobot/workspace",
      "model": "\${NANOBOT_MODEL:-qwen/qwen3.5-397b-a17b}",
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

# 6. Start the Nanobot Gateway
echo "Starting Nanobot Gateway..."
exec nanobot gateway
EOF

# Set permissions and switch to non-root user
RUN chmod +x /home/user/app/start.sh && chown -R user:user /home/user
USER user

# Render expects the service to be available on port 10000
EXPOSE 10000

CMD ["./start.sh"]