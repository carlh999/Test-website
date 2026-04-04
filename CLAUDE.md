# CLAUDE.md - Project Guidelines

## Deployment Rules

- All deployments must go through GitHub Actions only. No manual deployments.
- Never SSH directly into the server. All server interactions must be via GitHub Actions workflows.
- Droplet IP is stored in GitHub secret `DO_HOST` (currently 159.203.69.34).

## Secrets & Access

These are for the TEST droplet only. Rotate before any real use.

- **DO API token**: Stored locally only — do NOT commit. See `~/.do-token` or your password manager.
- **GitHub Secrets required**: `DO_HOST`, `DO_PASSWORD`, `ANTHROPIC_API_KEY`

## Droplet Setup (Ubuntu 24.04, 512MB)

When creating a fresh droplet, these are the known issues:

1. **DNS is broken out of the box** — `systemd-resolved` manages `/etc/resolv.conf` as a symlink. Fix: disable it, create a real file with `8.8.8.8` / `1.1.1.1`.
2. **pip can't upgrade system packages** — Debian-managed packages (e.g. `typing-extensions`) have no RECORD file. Use `pip3 install --break-system-packages --ignore-installed`.
3. **No nginx needed** — Flask serves port 80 directly. Stop and disable nginx if pre-installed.
4. **PermitRootLogin** — Must be `yes` in `/etc/ssh/sshd_config` for the deploy workflow to SSH in.

## CI/CD Rules

- Always use `set -o pipefail` in workflow `run:` blocks that pipe output (e.g. `cmd | tee`). Without it, the pipe masks the real exit code.
- Always use `set -ex` in deploy scripts.
- The deploy workflow creates a GitHub issue on failure with the last 80 lines of output.
- Deploy triggers on push to any `claude/*` branch. Edit `.github/workflows/deploy.yml` to change.

## Debugging Rules

- Always read full error logs before attempting to fix any issue.
- Deploy only after bugs have been resolved and verified.
- If CI shows "success" but site is broken, check for piped commands masking exit codes.

## Architecture

- **App**: Flask + Anthropic Claude API (`app.py`), serves directly on port 80
- **Model**: claude-sonnet-4-6
- **Service**: systemd unit `research-app.service` (created by `deploy/setup.sh`)
- **No venv**: System Python with `--break-system-packages --ignore-installed`
- **No nginx**: Disabled. Flask handles HTTP directly.
