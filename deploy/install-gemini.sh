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

# Install Gemini CLI
if ! command -v gemini &>/dev/null; then
  echo "==> Installing Gemini CLI..."
  npm install -g @google/gemini-cli
fi
echo "Gemini CLI: $(gemini --version 2>&1 || echo 'installed')"

# Install nanobanana extension
echo "==> Installing nanobanana extension..."
gemini extensions install https://github.com/gemini-cli-extensions/nanobanana 2>&1 || true

# Set up Gemini API key
export GEMINI_API_KEY
echo "export GEMINI_API_KEY=$GEMINI_API_KEY" > /root/.gemini-env
chmod 600 /root/.gemini-env

# Verify nano-banana-2 is available
if command -v nano-banana-2 &>/dev/null; then
  echo "nano-banana-2: $(nano-banana-2 --version 2>&1 || echo 'available')"
else
  echo "WARN: nano-banana-2 not found in PATH, checking gemini extensions..."
  gemini extensions list 2>&1 || true
fi

echo "=== GEMINI INSTALL COMPLETE ==="
