# Review Context — Test-website

This is a Flask web app (NEXUS Research Terminal) deployed to a DigitalOcean droplet via GitHub Actions.

## Repo structure
```
.github/workflows/deploy.yml  — CI/CD workflow, SSHes into droplet and runs setup
deploy/setup.sh               — Runs on droplet: fixes DNS, installs packages, starts Flask
app.py                        — Flask app with Claude API streaming (SSE)
templates/index.html          — Dark-themed research terminal UI
requirements.txt              — flask, anthropic
CLAUDE.md                     — Project rules and known issues
DROPLET_SETUP.md              — Checklist for recreating the droplet
```

## Key decisions and why
- **No nginx**: Flask serves port 80 directly. Nginx reverse proxy caused persistent 502 due to Ubuntu 24.04 config issues. Not worth the complexity for a single-app test droplet.
- **No venv**: Using system Python with `--break-system-packages --ignore-installed`. Ubuntu 24.04's debian-managed `typing-extensions` can't be upgraded by pip without `--ignore-installed`.
- **DNS fix in setup.sh**: Ubuntu 24.04 `systemd-resolved` breaks `/etc/resolv.conf`. Script disables it and writes a real file.
- **`set -o pipefail` in deploy.yml**: Without it, `ssh ... | tee` masks SSH exit codes and failures look like successes.
- **Deploy triggers on `claude/*` branches**: Wildcard so we don't need to edit the workflow for each new branch.

## GitHub Secrets
- `DO_HOST` — Droplet IP (159.89.231.0)
- `DO_PASSWORD` — Root SSH password
- `ANTHROPIC_API_KEY` — For Claude API calls
- DO API token stored locally only (not committed due to GitHub Push Protection)

## Known issues resolved
1. YAML syntax error in deploy.yml (block scalar + special characters)
2. SSH auth (appleboy actions incompatible, replaced with sshpass)
3. DNS broken on Ubuntu 24.04 (systemd-resolved)
4. pip typing-extensions conflict (debian RECORD file missing)
5. systemd crash-loop rate limiting (reset-failed)
6. 502 Bad Gateway (nginx config not loading — removed nginx entirely)
7. CI masking failures (tee pipe without pipefail)

## What to review
- Is the architecture sound for a test/demo app?
- Any security issues beyond the obvious (root user, no HTTPS, no firewall)?
- Is deploy/setup.sh robust enough for fresh droplet provisioning?
- Any improvements to the GitHub Actions workflow?
- Is the Flask app (app.py) handling streaming/errors properly?
