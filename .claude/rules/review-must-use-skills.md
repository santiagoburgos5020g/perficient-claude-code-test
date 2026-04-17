When reviewing, auditing, or checking code for refactoring, you MUST use the project's own skills as the authoritative benchmark. Never perform a generic code review.

## Required Steps

1. **Load skills first** — Before evaluating any code, read all applicable skills from `.claude/skills/`:
   - `nextjs-react-best-practices` — for frontend code (components, hooks, pages, styles)
   - `design-patterns-reference` — for structural and behavioral patterns in any code
   - `solid-principles-reference` — for class/module design in any code
   - `backend-best-practices` — for API routes, database operations, and server-side code

2. **Read all source files** — Read every file being reviewed before making any assessment.

3. **Evaluate against each applicable skill** — For each file, check every category/rule from every relevant skill. Do not skip categories.

4. **Report using skill terminology** — Every finding must include:
   - Skill name (e.g., `nextjs-react-best-practices`)
   - Category or rule (e.g., `Cat 7: useSWR` or `Rule 4: Zod Validation`)
   - Severity level per the skill's own definitions (Critical, Recommended, Informational)
   - File path and line numbers
   - Why the rule applies (not just the rule name)

5. **Full category checklist** — After listing violations, include a checklist of ALL categories from each applicable skill. Every category must appear exactly once, marked as either:
   - **Violation** — with details per step 4
   - **Passed** — confirmed compliant after review
   
   If a category does not appear in both the violations and the passed list, the review is incomplete. This prevents categories from being silently skipped in the initial review.

## What NOT to Do

- Do not delegate reviews to a generic explore agent that has no awareness of the skills
- Do not rely on general "code review instincts" or generic best practices
- Do not report findings without tying them back to a specific skill category/rule
- Do not skip any skill that applies to the files being reviewed
