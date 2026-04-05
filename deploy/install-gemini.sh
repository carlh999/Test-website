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

# Install nano-banana-mcp (the actual npm package)
echo "==> Installing nano-banana-mcp..."
npm install -g nano-banana-mcp
echo "==> Checking installed binaries from nano-banana-mcp..."
npm ls -g nano-banana-mcp --depth=0
# Show what bin links were created
ls -la $(npm prefix -g)/bin/ | grep -i banana || echo "No banana bin links found"
# Check all common command names
for cmd in nano-banana nano-banana-2 nano-banana-mcp nanobanana; do
  if command -v "$cmd" &>/dev/null; then
    echo "FOUND: $cmd at $(which $cmd)"
    $cmd --version 2>&1 || true
  else
    echo "NOT FOUND: $cmd"
  fi
done

# Set up Gemini API key
export GEMINI_API_KEY
echo "export GEMINI_API_KEY=$GEMINI_API_KEY" > /root/.gemini-env
chmod 600 /root/.gemini-env

echo "=== GEMINI INSTALL COMPLETE ==="
