#!/bin/bash
set -ex

# Fix DNS — Ubuntu 24.04 systemd-resolved breaks resolv.conf
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
ping -c1 -W5 pypi.org || { echo "DNS FAILED"; exit 1; }

# Install packages (skip if already present)
if python3 -c "import flask; import anthropic" 2>/dev/null; then
  echo "==> Python packages already installed, skipping pip"
else
  pip3 install --break-system-packages --ignore-installed flask anthropic
fi
python3 -c "import flask; print('flask', flask.__version__)"
python3 -c "import anthropic; print('anthropic', anthropic.__version__)"

# Write API key
echo "ANTHROPIC_API_KEY=$1" > /root/.flask-env
chmod 600 /root/.flask-env

# Stop nginx — not needed, Flask serves port 80 directly
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

# Write systemd service
cat > /etc/systemd/system/research-app.service << 'EOF'
[Unit]
Description=NEXUS Research Agent Flask App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/research-app
EnvironmentFile=/root/.flask-env
ExecStart=/usr/bin/python3 /root/research-app/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Clean start
rm -rf /root/research-app/venv
systemctl stop research-app 2>/dev/null || true
systemctl reset-failed research-app 2>/dev/null || true
systemctl daemon-reload
systemctl enable research-app
systemctl start research-app

sleep 5
systemctl is-active research-app
curl -sf http://localhost:80/ > /dev/null && echo "SITE IS LIVE ON PORT 80" || { echo "FAILED"; journalctl -u research-app --no-pager -n 20; exit 1; }
echo "=== DONE ==="
