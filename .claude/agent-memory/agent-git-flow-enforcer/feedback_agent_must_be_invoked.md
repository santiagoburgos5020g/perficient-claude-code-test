---
name: Agent must be proactively invoked before git operations
description: Claude must launch agent-git-flow-enforcer before any commit, push, branch, or merge — it does not auto-trigger
type: feedback
---

The agent-git-flow-enforcer is NOT automatically triggered. Claude (the main assistant) must proactively launch it via the Agent tool before performing any git operations.

**Why:** On 2026-04-13, Claude committed and pushed directly to `main` without launching this agent, completely bypassing Git Flow enforcement. The hook also failed due to a pattern mismatch, so there was no safety net.

**How to apply:** Before any `git add`, `git commit`, `git push`, branch creation, or merge operation, Claude should invoke this agent with `subagent_type: "agent-git-flow-enforcer"` to validate the operation. The agent's description in its frontmatter already states this, but it depends on Claude reading and acting on it.
