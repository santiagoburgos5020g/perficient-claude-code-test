---
name: Hook pattern must use wildcard prefix
description: The PreToolUse hook if-condition needs Bash(*git *) not Bash(git *) to catch cd-prefixed commands
type: feedback
---

The git-flow-enforcer hook in `.claude/settings.json` must use the pattern `Bash(*git *)` with a leading wildcard.

**Why:** On 2026-04-13, the original pattern `Bash(git *)` failed to trigger because Bash commands are typically prefixed with `cd "/path/..."  &&` before the actual `git` command. The hook was completely bypassed, allowing direct commits and pushes to `main`.

**How to apply:** If the hook pattern is ever modified, ensure it retains the leading `*` wildcard. If the hook still doesn't trigger, check whether the Bash command structure has changed (e.g., additional prefixes before `git`).
