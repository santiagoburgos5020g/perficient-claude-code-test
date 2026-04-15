The `/delegate-code` skill is **user-invoked only**. It runs when the user explicitly
types `/delegate-code [request]` in the prompt.

**Do NOT auto-trigger this skill.** Claude must never invoke `/delegate-code` on its own
during a session. If the user asks for a code change without `/delegate-code`, handle it
normally or ask if they want to delegate.

When invoked by the user, the `/delegate-code` skill (`.claude/skills/delegate-code/SKILL.md`) enforces:
1. Route to the proper subagent based on the request type
2. Get a read-only plan from the subagent (no file changes)
3. Present the plan with the subagent name to the user for confirmation
4. Only execute after user approval
5. Report results per subagent when finished

Do NOT call subagents directly for code changes — always go through `/delegate-code`
when the user invokes it.
