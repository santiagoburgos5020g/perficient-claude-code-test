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

## Agents

The `.claude/agents/` folder already exists. When adding new agents, place them inside `.claude/agents/`.