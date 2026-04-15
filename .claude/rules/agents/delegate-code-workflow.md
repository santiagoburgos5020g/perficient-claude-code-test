For **every** code request (check, refactor, change, new feature, bug fix) involving
code files, you MUST execute the `/delegate-code` skill FIRST.

Do NOT call subagents directly for code changes. Always go through `/delegate-code`.

The `/delegate-code` skill (`.claude/skills/delegate-code/SKILL.md`) enforces:
1. Route to the proper subagent based on the request type
2. Get a read-only plan from the subagent (no file changes)
3. Present the plan with the subagent name to the user for confirmation
4. Only execute after user approval
5. Report results per subagent when finished

## Exceptions (do NOT require /delegate-code)
- Editing `CLAUDE.md`, `.claude/` config files, or `README.md`
- Git operations (commits, branches, PRs)
- Read-only exploration (reading files, searching code)
- Running tests or dev server commands
