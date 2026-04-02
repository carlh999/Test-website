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

# === NGINX: bulletproof approach ===
# Dump the main nginx.conf to see what it includes
echo "=== Current nginx.conf ==="
cat /etc/nginx/nginx.conf

# Disable ALL default sites
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/conf.d/*

# Write our proxy config to BOTH locations to guarantee it's loaded
# regardless of whether nginx.conf includes sites-enabled or conf.d
cat > /etc/nginx/conf.d/research-app.conf << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
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
NGINXEOF

cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
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
NGINXEOF
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# If nginx.conf doesn't include sites-enabled, add it
if ! grep -q 'include.*sites-enabled' /etc/nginx/nginx.conf; then
    echo "==> nginx.conf missing sites-enabled include, conf.d should cover it"
fi

# But if BOTH are included, we'll have duplicate listen 80 — fix by checking
# if nginx.conf includes BOTH, only keep conf.d version
if grep -q 'include.*sites-enabled' /etc/nginx/nginx.conf && grep -q 'include.*conf.d' /etc/nginx/nginx.conf; then
    echo "==> Both includes found, removing sites-enabled copy to avoid conflict"
    rm -f /etc/nginx/sites-enabled/default
fi

# Test nginx config
echo "=== nginx -T (full effective config) ==="
nginx -T 2>&1 || true
nginx -t

# Clean up broken venv from earlier attempts
rm -rf /root/research-app/venv

# Reset systemd state (previous crash-loops hit rate limit)
systemctl stop research-app 2>/dev/null || true
systemctl reset-failed research-app 2>/dev/null || true

# Start services fresh
systemctl daemon-reload
systemctl enable research-app
systemctl stop nginx 2>/dev/null || true
systemctl start nginx
systemctl start research-app

# Wait and verify
for i in 1 2 3; do
  sleep 3
  echo "==> Check $i:"
  systemctl is-active research-app && echo "APP ACTIVE" || echo "APP FAILED"
  systemctl is-active nginx && echo "NGINX ACTIVE" || echo "NGINX FAILED"
done

echo "=== Service status ==="
systemctl status research-app --no-pager 2>&1 || true
echo "=== Last 20 journal lines ==="
journalctl -u research-app --no-pager -n 20 2>&1 || true
echo "=== Nginx status ==="
systemctl status nginx --no-pager 2>&1 || true
echo "=== Ports listening ==="
ss -tlnp | grep -E ':(80|5000)' || true

# Final verification
systemctl is-active research-app
curl -sf http://localhost:5000/ > /dev/null && echo "APP RESPONDS ON :5000" || { echo "APP NOT RESPONDING"; exit 1; }
curl -sf http://localhost:80/ > /dev/null && echo "NGINX PROXYING ON :80" || { echo "NGINX NOT PROXYING — 502 LIKELY"; curl -v http://localhost:80/ 2>&1 || true; exit 1; }
echo "=== SETUP COMPLETE ==="
