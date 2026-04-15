# PR Code Review Validator — Specification

## Overview

A **GitHub Actions workflow** that automatically reviews every pull request targeting `main` against the project's skill rules. It uses a **multi-agent pipeline** (Haiku for classification, Sonnet for validation, Opus for review synthesis) via the Claude Code CLI to detect violations, post inline comments and a summary on the PR, and **block merging** until all violations are resolved.

This is the PR-level counterpart to the `post-tool-use-code-validator` hook. It uses the **exact same skill rules, file classification logic, and scoping** — but instead of auto-fixing violations in real time, it reports them as a formal GitHub PR review.

---

## Goals

- **Every PR to `main` is reviewed** — the workflow runs automatically, no one can skip it
- **Same rules as the post-tool-use hook** — uses the project's skills as the single source of truth
- **Block merging on any violation** — acts as a required status check; any violation prevents merge
- **Actionable feedback** — inline comments on exact lines with explanations, plus a full summary
- **Clean pass clears the gate** — once all violations are resolved, previous "request changes" and violation comments are dismissed/removed automatically
- **Human approval remains separate** — the workflow never approves; it only blocks or unblocks

---

## Trigger Events

The workflow runs on pull requests targeting `main` with the following event types:

| Event | When it fires |
|-------|--------------|
| `opened` | PR is first created |
| `synchronize` | New commits are pushed to the PR branch |
| `reopened` | A closed PR is reopened |

### Skipped events

- **Draft PRs** — no review until marked "ready for review"
- Label changes, description edits, assignee changes — no re-review needed

---

## Review Scope

The review is limited to:

1. **Files changed in the PR** — determined by `git diff` against the base branch
2. **Related files (one level deep)** — files that import or are imported by the changed files

This matches the post-tool-use validator's scoping. The entire codebase is never reviewed.

---

## File Classification — Which Skills Apply

### File types validated

**Code files (frontend + backend):**
- `.ts`, `.tsx`, `.js`, `.jsx`

**Backend-specific files:**
- `.prisma` (schema files)
- `.sql` (migration files)

### File types ignored
- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- `.gitignore`, `.env`, `.env.*`, config files (`.eslintrc`, `tsconfig.json`, `next.config.js`, `tailwind.config.js`, `prettier.config.js`)
- Image files (`.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.ico`, `.webp`)
- Font files (`.woff`, `.woff2`, `.ttf`, `.eot`)
- Markdown/documentation files (`.md`, `.mdx`, `.txt`)
- JSON data files (`.json`) — except when inside `pages/api/` (API response fixtures)
- CSS/SCSS files that are not Tailwind utility files
- Any files inside `node_modules/`, `.next/`, `.git/`, `dist/`, `build/`, `coverage/`

### Frontend paths -> `nextjs-react-best-practices`
- `pages/` (excluding `pages/api/`)
- `components/`
- `containers/`
- `hooks/`
- `styles/`

### Backend paths -> `backend-best-practices`
- `pages/api/`
- `lib/`
- `services/`
- `prisma/`
- Any `.prisma` or `.sql` files regardless of location

### Shared/ambiguous paths
- `types/` — classified based on what imports them (frontend, backend, or both)
- `utils/` — same logic as `types/`
- Root-level files (e.g., `middleware.ts`) — classified as backend

### Test files
- Test files (`*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`, files in `__tests__/`) inherit the classification of the source file they test.

### Mixed changes
If a PR touches both frontend and backend files, both skills apply to their respective files. Stage 2 runs both sub-agents in parallel.

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
1. SRP — Split responsibilities
2. ISP — Narrow the interfaces
3. DIP — Invert dependencies toward abstractions
4. OCP — Design for extension
5. LSP — Verify inheritance contracts

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

**SOLID principles (frontend-scoped):**
- Mapped to frontend categories 3.11-3.23

**Design patterns (frontend-scoped):**
- Same catalog as backend, evaluated through frontend lens

### Key principle
Design patterns and SOLID principles are never applied generically. They are always evaluated through the lens of the skill context that triggered the validation.

---

## Multi-Agent Pipeline Architecture

### Stage 1: Classification — Haiku Agent

**Purpose:** Fast, lightweight classification of what changed in the PR and what needs validation.

**Actions:**
1. Run `git diff --name-only` against the base branch to get all changed files in the PR
2. Filter non-code files from the list
3. Classify each file as frontend, backend, or both based on path rules
4. Discover related files — trace one level of imports/consumers for each changed file
5. Skip if no code files remain after filtering
6. Output a structured JSON payload: changed files, related files, which skills apply to each

**Why Haiku:** Simple classification task — path matching, import tracing via grep, filtering. No deep code understanding needed.

### Stage 2: Validation — Sonnet Agents (Parallel)

**Purpose:** Read skill files and validate code against all applicable rules.

**Conditional execution:**
- Only frontend files -> only frontend sub-agent runs
- Only backend files -> only backend sub-agent runs
- Both -> both sub-agents run in parallel

**Sub-Agent A (Frontend — Sonnet):** Validates frontend files against:
- `nextjs-react-best-practices` (13 categories)
- `design-patterns-reference` (frontend-scoped)
- `solid-principles-reference` (frontend-scoped)

**Sub-Agent B (Backend — Sonnet):** Validates backend files against:
- `backend-best-practices` (Rules 1-10)
- `design-patterns-reference` (backend-scoped)
- `solid-principles-reference` (backend-scoped)

**Each agent:**
1. Reads the actual skill files from `.claude/skills/` (always fresh)
2. Reads all files in its scope (changed + related)
3. Evaluates every applicable rule/category
4. Outputs a structured violation list per file (skill, rule/category, file:line, description)

**Why Sonnet:** Accurate enough for rule compliance analysis, fast enough for parallel execution.

### Stage 3: Review Synthesis — Opus Agent

**Purpose:** Curate findings, filter false positives, and produce the final PR review.

**Precondition:** Only runs if Stage 2 found at least one potential violation. If zero violations, the pipeline posts a "PASSED (clean)" summary and exits.

**Actions:**
1. Receives combined violation list from Stage 2
2. Reads all skill files fresh from `.claude/skills/`
3. Reads all flagged files for full context
4. Filters false positives — removes findings that aren't actual violations when broader context is considered
5. Adds architectural context — explains *why* something violates the rule
6. Resolves conflicting rules — when two skills disagree, makes the judgment call
7. Writes actionable inline comments for each confirmed violation
8. Produces the summary comment tying all findings together
9. Posts the review as a single bundled GitHub review with "request changes" status

**Why Opus:** Requires strongest reasoning to filter false positives, resolve rule conflicts, and write clear explanations.

---

## GitHub PR Review Behavior

### When violations are found

The workflow posts a **single bundled GitHub review** containing:

1. **Inline comments** — one per violation, on the exact line, with:
   - Skill name (e.g., `backend-best-practices`)
   - Rule or category (e.g., `Rule 6: Security`)
   - Explanation of why the code violates the rule
   - Suggestion for how to fix it

2. **Summary comment** — a full breakdown grouped by skill:
   ```
   REVIEW COMPLETE — VIOLATIONS FOUND

   Files checked: 5 (3 changed, 2 related)
   Skills applied: backend-best-practices, design-patterns (backend-scoped), SOLID (backend-scoped)
   Violations found: 4

   ## backend-best-practices
   - [ ] Rule 6: Security — pages/api/products.ts:15 — No auth middleware
   - [ ] Rule 4: Zod Validation — pages/api/products.ts:22 — Request body not validated

   ## solid-principles-reference (backend-scoped)
   - [ ] SRP — lib/productService.ts:22 — Class handles both validation and DB queries

   ## nextjs-react-best-practices
   - [ ] Cat 5: TypeScript — components/Card.tsx:8 — Using `any` type
   ```

3. **Review status** — "Request changes" (blocks merging)

4. **Workflow exit code** — non-zero (fails the required status check)

### When zero violations are found

1. **Summary comment** — posted to confirm the review ran:
   ```
   REVIEW COMPLETE — PASSED (clean)

   Files checked: 3 (2 changed, 1 related)
   Skills applied: nextjs-react-best-practices, design-patterns (frontend-scoped), SOLID (frontend-scoped)
   Violations found: 0
   Status: PASSED
   ```

2. **Dismiss previous "request changes"** — if a prior run had blocked the PR, that review is dismissed
3. **Remove/resolve previous violation comments** — all inline comments from prior runs are cleaned up
4. **No approval** — approval is left to human reviewers
5. **Workflow exit code** — zero (status check passes)

### When no code files are changed

```
REVIEW SKIPPED — no code files changed

Only non-code files were modified in this PR. No skill-based review needed.
Status: PASSED
```

---

## Blocking Behavior

- The workflow is configured as a **required status check** in GitHub branch protection rules for `main`
- **Any violation** blocks merging — there are no severity tiers
- Once all violations are resolved (developer pushes fixes, workflow re-runs and finds zero violations), the PR becomes mergeable
- No re-review cycle after fixes — the workflow runs fresh on each push, and a clean pass is the final word
- Human approval is a separate requirement — the workflow handles rule compliance, humans handle design/logic review

---

## Cleanup on Re-run

When the workflow runs on a new push to the PR branch:

1. **Find all previous reviews** posted by the workflow's bot/user
2. **Dismiss any "request changes" reviews** from prior runs
3. **Resolve/delete inline comments** from prior runs
4. Then run the pipeline fresh and post new findings (if any)

This ensures the PR always reflects the current state, not stale findings from old commits.

---

## CI/CD Configuration

### GitHub Actions Workflow

The workflow file lives at `.github/workflows/pr-code-review-validator.yml`.

**Trigger:**
```yaml
on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]
```

**Draft PR skip:**
- The workflow checks if the PR is a draft and exits early if so

**Steps:**
1. Checkout the repo (full history for `git diff`)
2. Install Claude Code CLI
3. Set environment variables from GitHub secrets
4. Run the multi-agent pipeline via Claude Code CLI
5. Post review to the PR (inline comments + summary)
6. Set exit code based on whether violations were found

### Required Secrets (GitHub Actions)

| Secret | Purpose |
|--------|---------|
| `BEDROCK_BASE_URL` | Portkey gateway URL for Claude API access |
| `PORTKEY_API_KEY` | Portkey API key for authentication |

### Non-secret Environment Variables

| Variable | Value |
|----------|-------|
| `CLAUDE_CODE_USE_BEDROCK` | `1` |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | `1` |

### GitHub Token

Uses the built-in `GITHUB_TOKEN` (automatically available in workflows) for posting PR reviews and comments. No personal PAT needed.

### Prerequisites

- **Network access**: The GitHub-hosted runner must be able to reach the Portkey gateway URL. Verify with the infrastructure team whether IP whitelisting or VPN is required.
- **Branch protection**: `main` must have the workflow configured as a required status check.

---

## Notification Behavior

- **Single notification** per review — all inline comments are bundled into one GitHub review, so the PR author gets one email/notification, not one per violation
- On clean re-run, previous violation comments are resolved (no notification noise from old findings)

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Skill file missing or unreadable | Log warning, skip that skill's validation, proceed with remaining skills |
| Agent timeout | Fail the workflow with an error message — do NOT silently pass |
| Agent crash / unexpected error | Fail the workflow with an error message |
| `git` diff fails | Fail the workflow with an error message |
| No code files in PR | Post "REVIEW SKIPPED" comment, exit 0 (pass) |
| Portkey gateway unreachable | Fail the workflow with a clear error about connectivity |
| GitHub API rate limit | Retry with backoff, fail after 3 attempts |

**Note:** Unlike the post-tool-use hook (which fails open), the PR review **fails closed** — if something goes wrong, the status check fails and merging is blocked. This is safer for a merge gate.

---

## Constraints

- The workflow must always read skill files fresh from `.claude/skills/` — never hardcoded rules
- Design patterns and SOLID are always scoped to the triggering skill context
- Non-code files are always skipped
- Related file tracing is limited to one level deep
- The workflow never approves the PR — only blocks or unblocks
- Review comments are always bundled as a single review (one notification)
- Previous run findings are always cleaned up on re-run
- The workflow uses the built-in `GITHUB_TOKEN`, not a personal PAT
