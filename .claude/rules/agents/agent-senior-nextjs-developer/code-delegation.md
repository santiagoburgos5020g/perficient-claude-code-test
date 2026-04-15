For **every** code request (check, refactor, change, new feature, bug fix) involving
code files (`.ts`, `.tsx`, `.js`, `.jsx`, `.css`, `.json` in `pages/`, `features/`,
`lib/`, `styles/`), you MUST first execute the `/delegate-code` skill.

This skill lives at `.claude/skills/delegate-code/SKILL.md` and enforces
the plan-confirm-execute workflow:
1. Route to the proper subagent (e.g., `agent-senior-nextjs-developer` for frontend)
2. Get a read-only plan from the subagent (no file changes)
3. Present the plan to the user for confirmation
4. Only execute after user approval

Do NOT call subagents directly for code changes. Always go through `/delegate-code`.

## Exceptions (do NOT require /delegate-code)
- Editing `CLAUDE.md`, `.claude/` config files, or `README.md`
- Git operations (commits, branches, PRs)
- Read-only exploration (reading files, searching code)
- Running tests or dev server commands
