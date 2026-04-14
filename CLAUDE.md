# Claude Configuration

Do not use, reference, or apply any external rules.

All rules are defined in `.claude/rules/`. They are automatically loaded by Claude Code.

## Database Schema

For database-related operations, reference the Prisma schema at `prisma/schema.prisma`. This file contains the Product model and database configuration.


## Git Flow Enforcement

This project enforces Git Flow via the **`agent-git-flow-enforcer`** subagent, which handles the entire Git Flow process:

- **Blocks** direct commits, pushes, and staging on protected branches (`main`, `develop`).
- **Creates** feature, release, and hotfix branches following Git Flow conventions.
- **Validates** branch naming, commit prefixes, and merge targets.
- **Manages** pushes and pull requests according to Git Flow rules.

The agent must be launched **proactively** via the Agent tool (with `subagent_type: "agent-git-flow-enforcer"`) before any git operations (commit, push, branch creation, merge). Do not skip this step — always invoke the agent before performing git workflow actions.

**Important:** Do NOT run manual git commands (e.g., `git status`, `git diff`, `git log`) before or instead of launching the agent. The agent handles all git commands internally as part of its workflow. When a git operation is needed, go directly to the Agent tool — no preliminary Bash git commands.

## Agent Supervision

The main assistant **MUST** supervise and validate the `agent-git-flow-enforcer`'s output before reporting success to the user. Do not blindly relay the agent's result.

**After the agent completes any operation, verify:**

1. **Branch names** — any branches created must use one of the five valid Git Flow prefixes (`feature/`, `hotfix/`, `release/`, `bugfix/`, `support/`). If the agent created a non-standard branch (e.g., `sync/`, `temp/`, `merge/`), intervene immediately: clean up the invalid branch and follow the correct Git Flow procedure.
2. **Commit location** — commits landed on the correct branch (not on `main` or `develop` directly).
3. **PR targets** — PRs target the correct base branches per Git Flow rules (e.g., feature → develop, hotfix → main AND develop).
4. **No autonomous merges** — the agent should not have performed direct merges between `main` and `develop`. If it did, flag this to the user.

**If any violation is detected:**
- Do NOT report the agent's action as successful
- Explain the violation to the user
- Clean up invalid branches/PRs if needed
- Propose the correct Git Flow procedure

## MCP GitHub Server

This project uses the GitHub MCP server via **stdio transport** with a Personal Access Token (PAT), configured at the project level.

### Configuration (two files)

1. **`.mcp.json`** (project root) — defines the server:

```json
{
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@github/mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
      }
    }
  }
}
```

2. **`.claude/settings.local.json`** — provides the token (not committed to git):

```json
{
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_YOUR_TOKEN_HERE"
  }
}
```

### Token requirements

- Must be a **Classic** token (not fine-grained).
- Needs the **`repo`** scope for PR creation and branch operations.
- Generate at: GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic).

### Marketplace plugin conflict

Claude Code's marketplace GitHub plugin (`~/.claude/plugins/.../github/.mcp.json`) uses HTTP/OAuth transport (`api.githubcopilot.com`) and **overrides** the project-level stdio config. To use the project-level PAT config, disable the marketplace plugin:

```bash
mv "$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/github/.mcp.json" \
   "$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/github/.mcp.json.disabled"
```

To re-enable later, rename it back to `.mcp.json`.

### After any config change

**Restart Claude Code** so the MCP server reconnects with the updated config.

### Troubleshooting

For additional troubleshooting (e.g., 403 errors), see the [MCP GitHub Token reference](/.claude/memory/reference_mcp_github_token.md).

## Agents

The `.claude/agents/` folder already exists. When adding new agents, place them inside `.claude/agents/`.