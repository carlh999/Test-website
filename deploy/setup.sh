#!/bin/bash
set -ex

# Fix DNS — Ubuntu 24.04 uses systemd-resolved symlink
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "==> DNS test:"
ping -c1 -W5 pypi.org || { echo "DNS FAILED"; cat /etc/resolv.conf; exit 1; }

# Install packages
pip3 install --break-system-packages flask anthropic

# Verify
python3 -c "import flask; print('flask', flask.__version__)"
python3 -c "import anthropic; print('anthropic', anthropic.__version__)"

# Write API key (passed as $1)
echo "ANTHROPIC_API_KEY=$1" > /root/.flask-env
chmod 600 /root/.flask-env

# Write nginx config
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_cache off;
        add_header X-Accel-Buffering no;
    }
}
EOF

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

# Clean up broken venv from earlier attempts
rm -rf /root/research-app/venv

# Reset systemd state (previous crash-loops hit rate limit)
systemctl stop research-app 2>/dev/null || true
systemctl reset-failed research-app 2>/dev/null || true

# Start services fresh
systemctl daemon-reload
systemctl enable research-app
systemctl reload nginx
systemctl start research-app

# Wait and verify multiple times
for i in 1 2 3; do
  sleep 3
  echo "==> Check $i:"
  systemctl is-active research-app && echo "ACTIVE" || echo "FAILED"
done

echo "=== Service status ==="
systemctl status research-app --no-pager 2>&1 || true
echo "=== Last 20 journal lines ==="
journalctl -u research-app --no-pager -n 20 2>&1 || true

# Final verification
systemctl is-active research-app
curl -sf http://localhost:5000/ > /dev/null && echo "SITE IS LIVE" || { echo "NOT RESPONDING"; exit 1; }
echo "=== SETUP COMPLETE ==="
