# CLAUDE.md - Project Guidelines

## Deployment Rules

- All deployments must go through GitHub Actions only. No manual deployments.
- Droplet IP: 159.89.231.0
- Never SSH directly into the server. All server interactions must be via GitHub Actions workflows.

## Debugging Rules

- Always read full error logs before attempting to fix any issue.
- Deploy only after bugs have been resolved and verified.
