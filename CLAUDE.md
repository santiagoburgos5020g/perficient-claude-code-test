# Claude Configuration

Do not use, reference, or apply any external rules.

All rules are defined in `.claude/rules/`. They are automatically loaded by Claude Code.

## Database Schema

For database-related operations, reference the Prisma schema at `prisma/schema.prisma`. This file contains the Product model and database configuration.


## GitHub Integration

This project uses the **GitHub CLI (`gh`)** for all GitHub operations (PRs, issues, branches, etc.) instead of the MCP GitHub server.

### Setup

1. Install GitHub CLI: https://cli.github.com/
2. Authenticate: `gh auth login --with-token` using a PAT, or `gh auth login` for interactive login.

### Usage

Use `gh` commands via the Bash tool for all GitHub tasks:

- **Pull requests:** `gh pr create`, `gh pr list`, `gh pr view`, `gh pr merge`
- **Issues:** `gh issue create`, `gh issue list`, `gh issue view`
- **Branches:** `gh api repos/{owner}/{repo}/branches`
- **PR comments:** `gh api repos/{owner}/{repo}/pulls/{number}/comments`

### Token

The PAT is stored in `.claude/settings.local.json` under `env.GITHUB_PERSONAL_ACCESS_TOKEN` and is used by `gh` via `gh auth login --with-token`. The token requires the **`repo`** scope at minimum.

## Agents & Code Changes

Rules for agents and skills are defined in `.claude/rules/agents/` and `.claude/rules/skills/`. They are automatically loaded by Claude Code.