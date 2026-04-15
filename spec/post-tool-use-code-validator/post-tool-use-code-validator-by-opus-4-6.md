# Post Tool Use Code Validator — Specification (Reviewed by Opus 4.6)

## Overview

An **agent-based Claude Code hook** that automatically validates every code change against the project's skill rules immediately after file modifications. It acts as a **hard quality gate** — blocking Claude from proceeding until all violations are resolved or escalated to the user.

The hook fires on `PostToolUse` events for `Edit`, `Write`, and `Bash` (when files are actually changed), runs a multi-stage agent pipeline to detect violations, fixes them automatically, and re-evaluates until the code is clean.

---

## Goals

- **Zero tolerance for rule violations** — every code change must comply with applicable project skills before Claude continues
- **Automatic self-correction** — Claude fixes violations without user intervention (up to 3 attempts)
- **Scoped validation** — rules are applied based on which skill context the changed files belong to
- **Impact awareness** — validates not just changed files but related files impacted by the change
- **Always fresh rules** — reads skill files from `.claude/skills/` on every run, never hardcoded
- **Toggleable** — can be enabled/disabled via an environment variable

---

## Trigger Events

### Tools that trigger the hook

| Tool | Matcher | Trigger Condition |
|------|---------|-------------------|
| `Edit` | `Edit` | Always triggers after a successful edit |
| `Write` | `Write` | Always triggers after a successful file write |
| `Bash` | `Bash` | Triggers only if code files were actually changed (see detection method below) |

### Bash change detection method

When the `Bash` tool fires, the hook must determine whether files actually changed. The approach:

1. **Before the hook logic runs**, execute `git diff --name-only` (for tracked files) and `git ls-files --others --exclude-standard` (for new untracked files)
2. Compare against a **baseline snapshot** taken at session start or after the last validated change
3. If no code files appear in the diff, **exit immediately** (exit 0, no validation)
4. If the working directory is not a git repo, fall back to file modification timestamps

This ensures the hook has zero overhead for Bash commands that don't modify files (e.g., `npm test`, `ls`, `git log`).

### File types validated

**Code files (frontend + backend):**
- `.ts`, `.tsx`, `.js`, `.jsx`

**Backend-specific files:**
- `.prisma` (schema files)
- `.sql` (migration files)

The **path** determines which skill applies. `.prisma` and `.sql` files are always classified as backend.

### File types ignored
- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- `.gitignore`, `.env`, `.env.*`, config files (`.eslintrc`, `tsconfig.json`, `next.config.js`, `tailwind.config.js`, `prettier.config.js`)
- Image files (`.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.ico`, `.webp`)
- Font files (`.woff`, `.woff2`, `.ttf`, `.eot`)
- Markdown/documentation files (`.md`, `.mdx`, `.txt`)
- JSON data files (`.json`) — except when inside `pages/api/` (API response fixtures)
- CSS/SCSS files that are not Tailwind utility files
- Any files inside `node_modules/`, `.next/`, `.git/`, `dist/`, `build/`, `coverage/`

---

## Enable/Disable Toggle

The hook checks an environment variable in `.claude/settings.json`:

```json
{
  "env": {
    "isPostToolUseEnabledCodeChanges": "true"
  }
}
```

- `"true"` — hook is active, validates all code changes
- `"false"` — hook is disabled, Claude proceeds without validation

The hook's agent prompt **must check this variable first** and exit immediately with no output if set to `"false"`.

---

## Hook Configuration — JSON Structure

The hook is registered in `.claude/settings.json` under the `hooks` key. Because the validation logic requires reading files, analyzing code, running tools, and making multi-turn decisions, it uses `"type": "agent"` hooks.

```json
{
  "env": {
    "isPostToolUseEnabledCodeChanges": "true"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "agent",
            "prompt": "<see Agent Prompt section below>",
            "model": "haiku",
            "timeout": 120
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "agent",
            "prompt": "<see Agent Prompt section below — includes Bash-specific change detection preamble>",
            "model": "haiku",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

**Note on architecture:** The hook configuration itself launches a **Haiku agent** (Stage 1). That agent is responsible for orchestrating the full pipeline — it spawns the Stage 2 Sonnet sub-agents and the Stage 3 Opus agent as needed. This keeps the hook entry point lightweight while allowing the full multi-agent pipeline inside.

### Timeout considerations

- The outer hook timeout is set to **120 seconds** to accommodate the full 3-stage pipeline
- Stage 1 (Haiku) should complete in ~5-10 seconds
- Stage 2 (Sonnet, parallel) should complete in ~15-30 seconds
- Stage 3 (Opus, per attempt) should complete in ~20-40 seconds
- With up to 3 fix attempts, worst case is ~120 seconds
- If the timeout is exceeded, the hook exits with an error and Claude proceeds (fail-open to avoid deadlocks)

---

## File Classification — Which Skills Apply

### Frontend paths → `nextjs-react-best-practices`
- `pages/` (excluding `pages/api/`)
- `components/`
- `containers/`
- `hooks/`
- `styles/`

### Backend paths → `backend-best-practices`
- `pages/api/`
- `lib/`
- `services/`
- `prisma/`
- Any `.prisma` or `.sql` files regardless of location

### Shared/ambiguous paths
Files that do not fall into either category:
- `types/` — classified based on **what imports them**. If only frontend files import a type file, it's frontend. If only backend files import it, it's backend. If both import it, **both skills apply**.
- `utils/` — same logic as `types/`; classification depends on consumers.
- Root-level files (e.g., `middleware.ts`) — classified as **backend** since Next.js middleware runs server-side.

### Test files
- Test files (`*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`, files in `__tests__/`) inherit the classification of the **source file they test**. A test for `components/Card.tsx` is frontend; a test for `pages/api/products.ts` is backend.

### Mixed changes
If a change touches both frontend and backend files, **both skills apply** to their respective files. The Stage 2 pipeline runs both sub-agents in parallel.

---

## Validation Rules — Scoped by Skill Context

### When `backend-best-practices` applies

**Backend rules (read fresh from `.claude/skills/backend-best-practices/`):**
1. Rule 1 — Standard API response envelope
2. Rule 2 — REST conventions
3. Rule 3 — Pagination
4. Rule 4 — Input validation with Zod
5. Rule 5 — Centralized error handling
6. Rule 6 — Security
7. Rule 7 — Database optimization
8. Rule 8 — API testing
9. Rule 9 — Naming conventions
10. Rule 10 — Environment variables

**SOLID principles (backend-scoped, read from `.claude/skills/solid-principles-reference/`):**
1. SRP first — Split responsibilities. This often resolves or simplifies other violations.
2. ISP second — Narrow the interfaces. This makes the remaining principles easier to satisfy.
3. DIP third — Invert dependencies toward abstractions. This unlocks OCP.
4. OCP fourth — Design for extension. This is now possible because dependencies are inverted.
5. LSP last — Verify that all inheritance hierarchies honor their contracts. This is the final validation.

**Design patterns (backend-scoped, read from `.claude/skills/design-patterns-reference/`):**
- Creational: Singleton, Factory Method, Abstract Factory, Builder, Prototype
- Structural: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy
- Behavioral: Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

### When `nextjs-react-best-practices` applies

**Frontend categories (read fresh from `.claude/skills/nextjs-react-best-practices/`):**
1. Container-Presentational Component Pattern
2. Folder Structure
3. Naming Conventions
4. Component File Internal Structure
5. TypeScript Strictness
6. React 18 Hooks Best Practices
7. useSWR Best Practices
8. Error Handling
9. Testing Patterns
10. Tailwind CSS Conventions
11. Pages Router Data Fetching Strategy
12. Performance Optimization
13. Accessibility (a11y)

**SOLID principles (frontend-scoped, mapped to categories):**
- 3.11 Container-Presentational Component Pattern
- 3.12 Folder Structure
- 3.13 Naming Conventions
- 3.14 Component File Internal Structure
- 3.15 TypeScript Strictness
- 3.16 React 18 Hooks Best Practices
- 3.17 useSWR Best Practices
- 3.18 Error Handling
- 3.19 Testing Patterns
- 3.20 Tailwind CSS Conventions
- 3.21 Pages Router Data Fetching Strategy
- 3.22 Performance Optimization
- 3.23 Accessibility (a11y)

**Design patterns (frontend-scoped):**
- Creational: Singleton, Factory Method, Abstract Factory, Builder, Prototype
- Structural: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy
- Behavioral: Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

### Key principle
Design patterns and SOLID principles are **never applied generically**. They are always evaluated through the lens of the skill context that triggered the validation. The same pattern or principle is assessed differently for backend vs. frontend code.

---

## Multi-Agent Pipeline Architecture

### Stage 1: Change Detection — Haiku Agent
**Purpose:** Fast, lightweight classification of what changed and what needs validation. This is the orchestrator agent that drives the entire pipeline.

**Actions:**
1. **Check toggle** — Read `isPostToolUseEnabledCodeChanges` env var. Exit immediately if `"false"`.
2. **Detect changes** — For `Edit`/`Write` hooks, extract the file path from `tool_input.file_path`. For `Bash` hooks, run `git diff --name-only` and `git ls-files --others --exclude-standard` to find changed/new files.
3. **Filter non-code files** — Remove ignored file types from the list.
4. **Classify each file** — Assign frontend, backend, or both based on path rules.
5. **Discover related files** — For each changed file, trace **one level of imports/consumers**:
   - Search for files that `import` or `require` the changed file (consumers)
   - Read the changed file's own imports to find dependencies that may have contract expectations
   - Limit to one level deep to prevent scope explosion
6. **Skip if no code files** — If after filtering no code files remain, exit with no output (hook passes).
7. **Output** — A structured JSON payload listing: changed files, related files, and which skills apply to each.

**Why Haiku:** Simple classification task — path matching, import tracing via grep, and filtering. No deep code understanding needed. Fast and cheap.

### Stage 2: Parallel Skill Validation — Sonnet Agents
**Purpose:** Read skill files and validate code against all applicable rules.

**Conditional execution:**
- If Stage 1 found **only frontend files** → only Sub-Agent A runs (no backend validation)
- If Stage 1 found **only backend files** → only Sub-Agent B runs (no frontend validation)
- If Stage 1 found **both** → both sub-agents run in parallel

**Sub-Agent A (Frontend — Sonnet):** Validates frontend files against:
- `nextjs-react-best-practices` (13 categories)
- `design-patterns-reference` (frontend-scoped)
- `solid-principles-reference` (frontend-scoped, categories 3.11-3.23)

**Sub-Agent B (Backend — Sonnet):** Validates backend files against:
- `backend-best-practices` (Rules 1-10)
- `design-patterns-reference` (backend-scoped)
- `solid-principles-reference` (backend-scoped, SRP -> ISP -> DIP -> OCP -> LSP)

**Each agent:**
1. Reads the actual skill files from `.claude/skills/` (always fresh, never cached)
2. Reads all files in its scope (changed + related)
3. Evaluates every applicable rule/category against the code
4. Outputs a structured violation checklist per file (skill, rule/category, file:line, description)

**Why Sonnet:** Accurate enough to evaluate rule compliance and understand code semantics, fast enough to run in parallel. Better cost/speed ratio than Opus for read-only analysis.

### Stage 3: Fix & Re-evaluate — Opus Agent
**Purpose:** Fix all violations and verify the fixes are complete.

**Precondition:** Only runs if Stage 2 found at least one violation. If zero violations, the pipeline ends with a PASSED summary.

**Actions:**
1. Receives the combined violation checklist from Stage 2
2. Reads all skill files fresh from `.claude/skills/` (so it has the same rule context as Stage 2)
3. Reads all violated files
4. Fixes all violations across changed and related files
5. **Re-evaluation:** After fixing, Stage 2 is re-run (Sonnet agents) to validate the fixes independently — the Opus agent does NOT self-evaluate, to avoid bias
6. If violations remain → Opus fixes again (up to **3 total attempts**, each followed by a Sonnet re-evaluation)
7. If violations still remain after 3 attempts → **escalate to user** with a checklist of what was fixed vs. what remains, asking for a judgment call

**Why Opus:** Fixing code that satisfies SOLID + design patterns + skill rules simultaneously requires the strongest reasoning. Opus handles trade-offs and conflicting constraints best.

**Why Sonnet re-evaluates (not Opus):** An independent evaluator avoids the bias of the fixer grading its own work. The same Sonnet agents that found the original violations verify the fixes.

---

## Recursion Prevention

### Hook re-triggering
When Stage 3 (Opus) fixes files using `Edit`/`Write`, those tool calls would normally trigger the `PostToolUse` hook again, creating an infinite loop. To prevent this:

- The agent hook operates **within the hook context** — tool calls made by hook agents do not re-trigger hooks. This is built into Claude Code's hook execution model (hooks do not fire on tool calls made by hook agents).
- If this isolation is not guaranteed by the runtime, the hook must set an internal flag (e.g., write a temporary marker to `$CLAUDE_PROJECT_DIR/.claude/.hook-running`) and check for it at the start of every invocation, exiting immediately if present.

### Fix creates new files
If a fix involves splitting a file (e.g., to satisfy SRP), the new file(s) are included in the next re-evaluation cycle automatically — Stage 2 re-runs against all files touched by the fix, not just the original change list.

---

## Violation Report Format

When violations are found, they are displayed as a checklist:

```
VIOLATIONS FOUND (3)

[ ] backend-best-practices > Rule 6: Security — pages/api/products.ts:15 — No auth middleware
[ ] nextjs-react-best-practices > Cat 5: TypeScript — components/Card.tsx:8 — Using `any` type
[ ] solid-principles-reference > SRP — lib/productService.ts:22 — Class handles both validation and DB queries

Fixing...
```

Each violation includes:
- **Skill name** (e.g., `backend-best-practices`)
- **Rule or category** (e.g., `Rule 6: Security` or `Cat 5: TypeScript`)
- **File path and line number** (e.g., `pages/api/products.ts:15`)
- **Description of the violation** (e.g., `No auth middleware`)

After each fix attempt, the checklist is updated:

```
VIOLATIONS FIXED (attempt 1 of 3)

[x] backend-best-practices > Rule 6: Security — pages/api/products.ts:15 — Added auth middleware
[x] nextjs-react-best-practices > Cat 5: TypeScript — components/Card.tsx:8 — Replaced `any` with proper type
[ ] solid-principles-reference > SRP — lib/productService.ts:22 — Still needs splitting

Re-evaluating...
```

---

## Progress Updates

The hook provides real-time progress updates throughout the entire cycle:

```
[Hook] Post-tool-use validator triggered (Edit on components/Card.tsx)
[Stage 1] Detecting changes... 1 code file changed, 2 related files found
[Stage 1] Classification: 3 frontend files
[Stage 2] Validating frontend (3 files)... 2 violations found
[Stage 2] Backend validation skipped (no backend files)
[Stage 3] Fixing 2 violations (attempt 1 of 3)...
[Stage 3] Re-evaluating via Sonnet... 0 violations remaining
VALIDATION COMPLETE — all violations resolved (attempt 1)
```

For a failing cycle:

```
[Hook] Post-tool-use validator triggered (Edit on pages/api/products.ts)
[Stage 1] Detecting changes... 1 code file changed, 1 related file found
[Stage 1] Classification: 2 backend files
[Stage 2] Validating backend (2 files)... 4 violations found
[Stage 3] Fixing 4 violations (attempt 1 of 3)...
[Stage 3] Re-evaluating via Sonnet... 2 violations remaining
[Stage 3] Fixing 2 violations (attempt 2 of 3)...
[Stage 3] Re-evaluating via Sonnet... 1 violation remaining
[Stage 3] Fixing 1 violation (attempt 3 of 3)...
[Stage 3] Re-evaluating via Sonnet... 1 violation remaining
VALIDATION INCOMPLETE — ESCALATED (after 3 attempts)
```

---

## Final Summary Report

Always displayed at the end of every validation cycle:

### When all violations are resolved:
```
VALIDATION COMPLETE

Files checked: 5 (2 changed, 3 related)
Skills applied: nextjs-react-best-practices, design-patterns (frontend-scoped), SOLID (frontend-scoped)
Violations found: 3
Violations fixed: 3
Fix attempts: 1 of 3
Status: PASSED
```

### When no violations are found:
```
VALIDATION COMPLETE

Files checked: 3 (1 changed, 2 related)
Skills applied: backend-best-practices, design-patterns (backend-scoped), SOLID (backend-scoped)
Violations found: 0
Status: PASSED (clean)
```

### When escalated to user after 3 attempts:
```
VALIDATION INCOMPLETE — ESCALATED

Files checked: 5 (2 changed, 3 related)
Skills applied: backend-best-practices, design-patterns (backend-scoped), SOLID (backend-scoped)
Violations found: 4
Violations fixed: 3
Violations remaining: 1
Fix attempts: 3 of 3
Status: NEEDS USER INPUT

Remaining violations:
[ ] solid-principles-reference > SRP — lib/productService.ts:22 — Class handles validation and DB queries
    Conflict: Splitting this class would require changing the import in pages/api/products.ts,
    which may affect the response envelope structure (Rule 1).

These violations may involve trade-offs that require your judgment.
```

### When no code files are affected (Bash command that didn't change code):
```
[Hook] Post-tool-use validator triggered (Bash)
[Stage 1] No code file changes detected. Skipping validation.
```

---

## Execution Behavior

- **Synchronous** — Claude waits for the full validation-fix cycle to complete before doing anything else
- **Blocking** — if violations exist, Claude cannot make new changes or respond until fixed or escalated
- **New file/folder validation** — the hook validates new files for correct placement (folder structure), naming conventions, and internal structure, not just code content
- **Related file validation** — the hook traces imports and consumers (one level deep) to find impacted files, validates them, and fixes violations in them too (even though Claude didn't directly touch them)
- **Fail-open on timeout** — if the hook exceeds its timeout (120s), it exits with an error notice and Claude proceeds. This prevents deadlocks but should be rare.
- **Fail-open on agent error** — if any stage encounters an unrecoverable error (e.g., skill file missing, agent crash), the hook logs the error to stderr and exits, allowing Claude to proceed rather than blocking indefinitely.

---

## Scope Validation for New Files/Folders

When new files or folders are created, the hook additionally checks:
- **Folder Structure** — is the file in the correct directory per skill rules (Cat 2 for frontend, project convention for backend)?
- **Naming Conventions** — does the filename follow the conventions (Cat 3 for frontend, Rule 9 for backend)?
- **Internal Structure** — does the file have the correct internal organization (Cat 4 for frontend)?

If a new file is created in the wrong directory, the fix should **move the file** to the correct location and update all imports that reference it.

---

## Escalation Flow (After 3 Failed Attempts)

1. Hook presents the remaining violations as a checklist with full context
2. For each remaining violation, the hook explains **why it could not be auto-fixed** (e.g., conflicting rules, architectural trade-off, requires broader refactor outside the changed scope)
3. Hook asks the user for input on how to proceed
4. User makes the judgment call
5. If the user provides a decision, the hook applies it and runs **one final Sonnet re-evaluation** to confirm
6. If the user chooses to skip/accept the remaining violations, the hook exits and Claude proceeds

---

## Hook Configuration Location

The hook is configured in `.claude/settings.json` at the project level, so it can be committed to the repo and shared with the team.

```
.claude/settings.json          ← hook registration + env toggle
.claude/skills/                ← rule definitions (read fresh every run)
  backend-best-practices/
  nextjs-react-best-practices/
  solid-principles-reference/
  design-patterns-reference/
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Skill file missing or unreadable | Log warning to stderr, skip that skill's validation, proceed with remaining skills |
| Agent timeout (>120s) | Exit with error, Claude proceeds (fail-open) |
| Agent crash / unexpected error | Log error to stderr, Claude proceeds (fail-open) |
| `git` not available (Bash detection) | Fall back to file timestamp comparison |
| No code files in change | Exit immediately, no validation |
| `isPostToolUseEnabledCodeChanges` is `"false"` | Exit immediately, no validation |
| `isPostToolUseEnabledCodeChanges` is unset/missing | Treat as `"false"` (opt-in, not opt-out) |
| Fix attempt creates a file outside project directory | Block the fix, report as an error, do not write the file |

---

## Constraints

- The hook must never modify files outside the project directory
- The hook must always read skill files fresh from `.claude/skills/` — never use hardcoded rules
- Design patterns and SOLID are always scoped to the triggering skill context
- Maximum 3 fix attempts before escalation — no infinite loops
- Non-code files are always skipped
- The hook respects the `isPostToolUseEnabledCodeChanges` environment variable (opt-in: unset = disabled)
- Related file tracing is limited to **one level deep** to prevent scope explosion
- Re-evaluation after fixes is performed by **Sonnet** (independent evaluator), not by the Opus fixer
- Hook agents cannot re-trigger the hook (recursion prevention)
- The hook must fail-open (allow Claude to proceed) rather than fail-closed (block indefinitely) on errors and timeouts
