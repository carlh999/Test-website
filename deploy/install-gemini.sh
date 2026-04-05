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

# Test: generate an image
echo "==> Running test image generation..."
mkdir -p /root/gemini-test
cd /root/gemini-test
GEMINI_API_KEY="$GEMINI_API_KEY" gemini -p "Use nanobanana to generate a test image of a futuristic AI dashboard with glowing cyan elements on a dark background. Save it to /root/gemini-test/test-image.png" 2>&1 | tee /root/gemini-test-output.txt

echo "=== Test output ==="
cat /root/gemini-test-output.txt
echo "=== Files generated ==="
ls -la /root/gemini-test/
echo "=== GEMINI INSTALL COMPLETE ==="
