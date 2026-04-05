# Droplet Setup Checklist

When destroying and recreating the DigitalOcean droplet:

## 1. Create Droplet
- Ubuntu 24.04
- Cheapest plan (512MB works)
- Region: any
- Enable password authentication

## 2. Enable SSH Root Login
On the droplet console, verify `/etc/ssh/sshd_config` has:
```
PermitRootLogin yes
```
Then run: `systemctl restart sshd`

## 3. Update GitHub Secrets
Go to repo Settings > Secrets and variables > Actions:
- `DO_HOST` → new droplet IP
- `DO_PASSWORD` → new root password
- `ANTHROPIC_API_KEY` → your Anthropic API key

## 4. Push to Deploy
Push any commit to a `claude/*` branch. The workflow handles everything:
- Fixes DNS (disables systemd-resolved)
- Installs Python packages (flask, anthropic)
- Disables nginx
- Creates systemd service for Flask on port 80
- Verifies the site responds

## 5. Verify
Visit `http://<droplet-ip>` — you should see the NEXUS Research Terminal.
