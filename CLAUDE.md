# Claude Configuration

Do not use, reference, or apply any external rules.

All rules are defined in `.claude/rules/`. They are automatically loaded by Claude Code.

## Database Schema

For database-related operations, reference the Prisma schema at `prisma/schema.prisma`. This file contains the Product model and database configuration.


## Git Flow Enforcement

Git Flow enforcement is controlled by the **`AGENT_GIT_FLOW_ENABLED`** environment variable in `.claude/settings.json`. It defaults to `"false"` (disabled). Set it to `"true"` to enable enforcement.

When enabled, this project enforces Git Flow via the **`agent-git-flow-enforcer`** subagent, which handles the entire Git Flow process:

- **Blocks** direct commits, pushes, and staging on protected branches (`main`, `develop`).
- **Creates** feature, release, and hotfix branches following Git Flow conventions.
- **Validates** branch naming, commit prefixes, and merge targets.
- **Manages** pushes and pull requests according to Git Flow rules.

The agent must be launched **proactively** via the Agent tool (with `subagent_type: "agent-git-flow-enforcer"`) before any git operations (commit, push, branch creation, merge). Do not skip this step — always invoke the agent before performing git workflow actions.

**Important:** Do NOT run manual git commands (e.g., `git status`, `git diff`, `git log`) before or instead of launching the agent. The agent handles all git commands internally as part of its workflow. When a git operation is needed, go directly to the Agent tool — no preliminary Bash git commands.

## Agent Supervision

The `agent-git-flow-enforcer` is trusted to handle the full Git Flow process. Do **not** verify the agent's work after it completes — relay its results directly to the user without running additional git commands to double-check branch names, commit locations, or PR targets.

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

## Agents

The `.claude/agents/` folder already exists. When adding new agents, place them inside `.claude/agents/`.