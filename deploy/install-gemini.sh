#!/bin/bash
set -ex

GEMINI_API_KEY="$1"

# Install google-genai Python SDK for image generation
echo "==> Installing google-genai SDK..."
pip3 install --break-system-packages --ignore-installed google-genai

# Verify import works
python3 -c "from google import genai; print('google-genai OK')"

# Store API key
echo "export GEMINI_API_KEY=$GEMINI_API_KEY" > /root/.gemini-env
chmod 600 /root/.gemini-env

echo "=== GEMINI SDK INSTALL COMPLETE ==="
