#!/bin/bash
set -ex

GEMINI_API_KEY="$1"

# Install Node.js 20+
if ! command -v node &>/dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  echo "==> Installing Node.js 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "Node: $(node -v)"
echo "npm: $(npm -v)"

# Install infsh (nano-banana image generation from inference.sh)
echo "==> Installing infsh..."
npm install -g infsh

# Authenticate with Gemini API key
echo "==> Authenticating infsh..."
export GEMINI_API_KEY
echo "export GEMINI_API_KEY=$GEMINI_API_KEY" > /root/.gemini-env
chmod 600 /root/.gemini-env

# Verify installation
echo "==> Verifying infsh..."
infsh --version

echo "=== INFSH INSTALL COMPLETE ==="
