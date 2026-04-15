# Post Tool Use Code Validator — Specification

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
| Tool | Trigger Condition |
|------|-------------------|
| `Edit` | Always triggers |
| `Write` | Always triggers |
| `Bash` | Triggers only if files were actually changed (detected via `git diff --name-only` or file timestamps after command execution) |

### File types validated

**Code files (frontend + backend):**
- `.ts`, `.tsx`, `.js`, `.jsx`

**Backend-specific files:**
- `.prisma` (schema files)
- `.sql` (migration files)

The **path** determines which skill applies. `.prisma` and `.sql` files are always classified as backend.

### File types ignored
- `package.json`, `package-lock.json`
- `.gitignore`, `.env`, config files
- Image files, fonts, assets
- Markdown/documentation files
- Any other non-code files

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

The hook exits immediately if the variable is set to `"false"`.

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
- Any `.prisma` or `.sql` files regardless of path

### Mixed changes
If a change touches both frontend and backend files, **both skills apply** to their respective files.

---

## Validation Rules — Scoped by Skill Context

### When `backend-best-practices` applies

**Backend rules (from skill file):**
1. Rule 1 — Response envelope
2. Rule 2 — REST conventions
3. Rule 3 — Pagination
4. Rule 4 — Input validation (Zod)
5. Rule 5 — Error handling
6. Rule 6 — Security
7. Rule 7 — Database optimization
8. Rule 8 — Testing
9. Rule 9 — Naming
10. Rule 10 — Environment variables

**SOLID principles (backend-scoped):**
1. SRP first — Split responsibilities
2. ISP second — Narrow the interfaces
3. DIP third — Invert dependencies toward abstractions
4. OCP fourth — Design for extension
5. LSP last — Verify inheritance contracts

**Design patterns (backend-scoped):**
- Creational: Singleton, Factory Method, Abstract Factory, Builder, Prototype
- Structural: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy
- Behavioral: Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor

### When `nextjs-react-best-practices` applies

**Frontend categories (from skill file):**
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
**Purpose:** Fast, lightweight classification of what changed and what needs validation.

**Actions:**
1. Detect which files were changed or created
2. Classify each file as frontend, backend, or both based on its path
3. Filter out non-code files (configs, assets, docs, lock files)
4. Identify related files that might be impacted (imports, consumers, dependents)
5. Output a scoped list of files + which skills apply to each

**Why Haiku:** Simple classification task — no deep code understanding needed, just path matching and import tracing. Fast and cheap.

### Stage 2: Parallel Skill Validation — Sonnet Agents
**Purpose:** Read skill files and validate code against all applicable rules.

**Runs in parallel:**
- **Sub-Agent A (Frontend — Sonnet):** Validates frontend files against:
  - `nextjs-react-best-practices` (13 categories)
  - `design-patterns-reference` (frontend-scoped)
  - `solid-principles-reference` (frontend-scoped, categories 3.11–3.23)

- **Sub-Agent B (Backend — Sonnet):** Validates backend files against:
  - `backend-best-practices` (Rules 1–10)
  - `design-patterns-reference` (backend-scoped)
  - `solid-principles-reference` (backend-scoped, SRP → ISP → DIP → OCP → LSP)

**Each agent:**
1. Reads the actual skill files from `.claude/skills/` (always fresh, never cached)
2. Reads all files in its scope (changed + related)
3. Evaluates every applicable rule/category
4. Outputs a violation checklist per file

**Why Sonnet:** Accurate enough to evaluate rule compliance, fast enough to run in parallel.

### Stage 3: Fix & Re-evaluate — Opus Agent
**Purpose:** Fix all violations and verify the fixes are complete.

**Actions:**
1. Receives the combined violation checklist from Stage 2
2. Fixes all violations across changed and related files
3. Re-evaluates all files against all applicable rules
4. If violations remain → fix again (up to **3 total attempts**)
5. If violations still remain after 3 attempts → **escalate to user** with a checklist of what was fixed vs. what remains, asking for a judgment call

**Why Opus:** Fixing code that satisfies SOLID + design patterns + skill rules simultaneously requires the strongest reasoning. Opus handles trade-offs and conflicting constraints best.

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

---

## Progress Updates

The hook provides real-time progress updates throughout the entire cycle:

```
[Stage 1] Detecting changes... 3 code files classified (2 frontend, 1 backend)
[Stage 2] Validating frontend (2 files + 1 related)... 2 violations found
[Stage 2] Validating backend (1 file + 0 related)... 0 violations
[Stage 3] Fixing 2 violations (attempt 1 of 3)...
[Stage 3] Re-evaluating... 0 violations remaining
VALIDATION COMPLETE — all violations resolved
```

---

## Final Summary Report

Always displayed at the end of every validation cycle:

```
VALIDATION COMPLETE

Files checked: 5 (2 changed, 3 related)
Skills applied: nextjs-react-best-practices, design-patterns, SOLID
Violations found: 3
Violations fixed: 3 (attempt 1)
Status: PASSED
```

If escalated to user after 3 attempts:

```
VALIDATION INCOMPLETE — ESCALATED

Files checked: 5 (2 changed, 3 related)
Skills applied: backend-best-practices, design-patterns, SOLID
Violations found: 4
Violations fixed: 2
Violations remaining: 2
Status: NEEDS USER INPUT

Remaining violations:
[ ] solid-principles-reference > SRP — lib/productService.ts:22 — Class handles validation and DB queries
[ ] design-patterns-reference > Strategy — lib/productService.ts:30 — Hardcoded pricing logic

These violations may involve trade-offs that require your judgment.
```

---

## Execution Behavior

- **Synchronous** — Claude waits for the full validation-fix cycle to complete before doing anything else
- **Blocking** — if violations exist, Claude cannot make new changes or respond until fixed or escalated
- **New file/folder validation** — the hook validates new files for correct placement (folder structure), naming conventions, and internal structure, not just code content
- **Related file validation** — the hook traces imports and consumers to find impacted files, validates them, and fixes violations in them too (even though Claude didn't directly touch them)

---

## Scope Validation for New Files/Folders

When new files or folders are created, the hook additionally checks:
- **Folder Structure** — is the file in the correct directory per skill rules?
- **Naming Conventions** — does the filename follow the conventions?
- **Internal Structure** — does the file have the correct internal organization?

---

## Escalation Flow (After 3 Failed Attempts)

1. Hook presents the remaining violations as a checklist
2. Hook explains why the violations might conflict or require a trade-off
3. Hook asks the user for input on how to proceed
4. User makes the judgment call
5. Hook applies the user's decision and runs one final validation

---

## Hook Configuration Location

The hook is configured in `.claude/settings.json` at the project level, so it can be committed to the repo and shared with the team.

---

## Constraints

- The hook must never modify files outside the project directory
- The hook must always read skill files fresh from `.claude/skills/` — never use hardcoded rules
- Design patterns and SOLID are always scoped to the triggering skill context
- Maximum 3 fix attempts before escalation — no infinite loops
- Non-code files are always skipped
- The hook respects the `isPostToolUseEnabledCodeChanges` environment variable
