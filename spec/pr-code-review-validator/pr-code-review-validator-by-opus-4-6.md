# PR Code Review Validator — Specification (Reviewed by Opus 4.6)

## Overview

A **GitHub Actions workflow** that automatically reviews every pull request targeting `main` against the project's skill rules. It uses a **multi-agent pipeline** (Haiku for classification, Sonnet for validation, Opus for review synthesis) via the **Claude Code CLI** to detect violations, post inline comments and a detailed summary on the PR, and **block merging** until all violations are resolved.

This is the PR-level counterpart to the `post-tool-use-code-validator` hook. It uses the **exact same skill rules, file classification logic, and scoping** — but instead of auto-fixing violations in real time, it reports them as a formal GitHub PR review with actionable feedback.

---

## Goals

- **Every PR to `main` is reviewed** — the workflow runs automatically on every qualifying PR event; no one can skip it
- **Same rules as the post-tool-use hook** — uses the project's skills in `.claude/skills/` as the single source of truth
- **Block merging on any violation** — acts as a required status check; any violation prevents merge regardless of severity
- **Actionable feedback** — inline comments on exact diff lines with explanations and fix suggestions, plus a full summary grouped by skill
- **Clean pass clears the gate** — once all violations are resolved, previous "request changes" reviews and violation comments are automatically dismissed/resolved
- **Human approval remains separate** — the workflow never approves the PR; it only blocks or unblocks. Design and logic review remain human responsibilities
- **Single notification per review** — all findings are bundled into one GitHub review to minimize notification noise

---

## Trigger Events

The workflow runs on pull requests targeting `main` with the following event types:

| Event | When it fires |
|-------|--------------|
| `opened` | PR is first created (non-draft only) |
| `synchronize` | New commits are pushed to the PR branch |
| `reopened` | A closed PR is reopened |
| `ready_for_review` | A draft PR is marked as ready for review |

### Skipped events

- **Draft PRs** — no review until marked "ready for review" (which triggers `ready_for_review`)
- Label changes, description edits, assignee changes, reviewer additions — no re-review needed
- PRs targeting branches other than `main` — not in scope

### Draft PR handling

The workflow checks `github.event.pull_request.draft` at the start. If `true`, the workflow exits immediately with success (exit 0) and posts no comments. When the PR is later marked ready, the `ready_for_review` event triggers a full review.

---

## Concurrency Control

To prevent duplicate reviews when multiple pushes happen in quick succession:

```yaml
concurrency:
  group: pr-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true
```

This ensures only one review runs per PR at a time. If a new push arrives while a review is in progress, the in-progress run is cancelled and a fresh run starts. This prevents stale results from being posted after newer code has already been pushed.

---

## Review Scope

The review is limited to:

1. **Files changed in the PR** — determined by `git diff --name-only origin/main...HEAD` (triple-dot to get the symmetric difference from the merge base)
2. **Related files (one level deep)** — files that import or are imported by the changed files, discovered via grep for `import` and `require` statements

This matches the post-tool-use validator's scoping. The entire codebase is never reviewed.

### Large PR guard

If the PR changes more than **50 code files** (after filtering non-code files), the workflow:
1. Posts a warning comment noting the PR is unusually large
2. Still runs the full review (does not skip)
3. Sets a longer timeout for the pipeline (see Timeout section)

This prevents silent failures on large PRs while alerting the team that the PR may be too large for effective review.

---

## File Classification — Which Skills Apply

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

Files that do not fall into either category:
- `types/` — classified based on **what imports them**. If only frontend files import a type file, it's frontend. If only backend files import it, it's backend. If both import it, **both skills apply**.
- `utils/` — same logic as `types/`; classification depends on consumers.
- Root-level files (e.g., `middleware.ts`) — classified as **backend** since Next.js middleware runs server-side.

### Test files

- Test files (`*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`, files in `__tests__/`) inherit the classification of the **source file they test**. A test for `components/Card.tsx` is frontend; a test for `pages/api/products.ts` is backend.

### Mixed changes

If a PR touches both frontend and backend files, **both skills apply** to their respective files. The Stage 2 pipeline runs both sub-agents in parallel.

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

## Scope Validation for New Files

When the PR introduces new files, the review additionally checks:

- **Folder Structure** — is the file in the correct directory per skill rules (Cat 2 for frontend, project convention for backend)?
- **Naming Conventions** — does the filename follow the conventions (Cat 3 for frontend, Rule 9 for backend)?
- **Internal Structure** — does the file have the correct internal organization (Cat 4 for frontend)?

If a new file is in the wrong directory, the inline comment should explain where it should be placed and suggest the correct path.

---

## Multi-Agent Pipeline Architecture

### Stage 1: Classification — Haiku Agent

**Purpose:** Fast, lightweight classification of what changed in the PR and what needs validation. This is the orchestrator that drives the entire pipeline.

**Actions:**
1. Run `git diff --name-only origin/main...HEAD` to get all changed files in the PR
2. Filter non-code files from the list using the ignore rules
3. Classify each remaining file as frontend, backend, or both based on path rules
4. Discover related files — for each changed file, trace **one level of imports/consumers**:
   - Search for files that `import` or `require` the changed file (consumers)
   - Read the changed file's own imports to find dependencies that may have contract expectations
   - Limit to one level deep to prevent scope explosion
5. Skip if no code files remain after filtering — output "no code files" result
6. Output a structured JSON payload listing: changed files, related files, and which skills apply to each

**Why Haiku:** Simple classification task — path matching, import tracing via grep, and filtering. No deep code understanding needed. Fast and cheap.

**Timeout:** 30 seconds. If exceeded, the stage fails and the workflow exits with an error.

### Stage 2: Validation — Sonnet Agents (Parallel)

**Purpose:** Read skill files and validate code against all applicable rules.

**Conditional execution:**
- If Stage 1 found **only frontend files** -> only Sub-Agent A runs (no backend validation)
- If Stage 1 found **only backend files** -> only Sub-Agent B runs (no frontend validation)
- If Stage 1 found **both** -> both sub-agents run in parallel

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
4. Outputs a structured violation list per file with: skill name, rule/category, file path, line number, description of violation

**Why Sonnet:** Accurate enough to evaluate rule compliance and understand code semantics, fast enough to run in parallel. Better cost/speed ratio than Opus for read-only analysis.

**Timeout:** 120 seconds per sub-agent. If exceeded, the stage fails and the workflow exits with an error.

### Stage 3: Review Synthesis — Opus Agent

**Purpose:** Curate findings, filter false positives, resolve conflicts, and produce the final PR review.

**Precondition:** Only runs if Stage 2 found at least one potential violation. If zero violations, the pipeline skips Stage 3 and proceeds directly to posting a "PASSED (clean)" summary.

**Actions:**
1. Receives the combined violation list from Stage 2 (both sub-agents)
2. Reads all skill files fresh from `.claude/skills/` (so it has the same rule context as Stage 2)
3. Reads all flagged files in full for complete context
4. **Filters false positives** — removes findings that aren't actual violations when broader context is considered (e.g., a pattern that looks like a violation in isolation but is correct in context)
5. **Adds architectural context** — for each confirmed violation, explains *why* it violates the rule, not just *that* it does
6. **Resolves conflicting rules** — when two skills disagree (e.g., a pattern helps backend performance but violates SOLID), makes the judgment call and explains the reasoning
7. **Writes actionable inline comments** — clear, specific comments for each confirmed violation, including a suggestion for how to fix it
8. **Produces the summary comment** — a cohesive overview tying all findings together, grouped by skill
9. **Determines the review verdict** — "request changes" if any violations remain after filtering, or "comment" if all findings were filtered as false positives

**Why Opus:** Fixing requires strong reasoning; so does deciding what is a *real* violation vs. a false positive. Opus handles trade-offs between conflicting constraints, filters noise, and writes explanations that developers can act on.

**Timeout:** 180 seconds. If exceeded, the stage fails and the workflow exits with an error.

### Total pipeline timeout

The workflow sets an overall **job timeout of 10 minutes** (`timeout-minutes: 10`). This accommodates:
- Stage 1 (Haiku): ~5-15 seconds
- Stage 2 (Sonnet, parallel): ~30-90 seconds
- Stage 3 (Opus): ~60-120 seconds
- GitHub API calls (cleanup, posting review): ~10-30 seconds
- Buffer for large PRs

If the job timeout is exceeded, GitHub cancels the workflow. The status check remains in a "pending" state, which blocks merging. A re-run can be triggered manually.

---

## GitHub PR Review Behavior

### Bot identification

The workflow posts all reviews and comments using the built-in `GITHUB_TOKEN`, which authenticates as the **`github-actions[bot]`** user. All cleanup logic identifies prior reviews/comments by checking:
- Author is `github-actions[bot]`
- Review body contains the marker string `<!-- pr-code-review-validator -->`

This HTML comment marker is invisible in the rendered review but allows precise identification of reviews posted by this workflow vs. other bots or workflows.

### When violations are found

The workflow posts a **single bundled GitHub review** containing:

1. **Inline comments** — one per confirmed violation, on the exact diff line, formatted as:

   ```markdown
   **backend-best-practices > Rule 6: Security**

   This API route handler does not check authentication before processing the request. Any unauthenticated user can access this endpoint.

   **Suggestion:** Add the `withAuth` middleware wrapper or check `req.session` before proceeding.

   <!-- pr-code-review-validator -->
   ```

2. **Summary comment** — the review body, with a full breakdown grouped by skill:

   ```markdown
   <!-- pr-code-review-validator -->
   ## REVIEW COMPLETE — VIOLATIONS FOUND

   | Metric | Value |
   |--------|-------|
   | Files checked | 5 (3 changed, 2 related) |
   | Skills applied | backend-best-practices, design-patterns (backend-scoped), SOLID (backend-scoped) |
   | Violations found | 4 |
   | False positives filtered | 1 |
   | Status | **BLOCKED** |

   ### backend-best-practices
   - [ ] **Rule 6: Security** — `pages/api/products.ts:15` — No auth middleware
   - [ ] **Rule 4: Zod Validation** — `pages/api/products.ts:22` — Request body not validated

   ### solid-principles-reference (backend-scoped)
   - [ ] **SRP** — `lib/productService.ts:22` — Class handles both validation and DB queries

   ### nextjs-react-best-practices
   - [ ] **Cat 5: TypeScript** — `components/Card.tsx:8` — Using `any` type

   ---
   *This review was generated by the PR Code Review Validator. All violations must be resolved before merging.*
   ```

3. **Review status** — `REQUEST_CHANGES` (formally blocks the PR in GitHub's review system)

4. **Workflow exit code** — non-zero (fails the required status check)

### When zero violations are found

1. **Cleanup** — dismiss any previous `REQUEST_CHANGES` reviews and resolve/delete inline comments from prior runs (identified by the `<!-- pr-code-review-validator -->` marker)

2. **Summary comment** — posted to confirm the review ran:

   ```markdown
   <!-- pr-code-review-validator -->
   ## REVIEW COMPLETE — PASSED (clean)

   | Metric | Value |
   |--------|-------|
   | Files checked | 3 (2 changed, 1 related) |
   | Skills applied | nextjs-react-best-practices, design-patterns (frontend-scoped), SOLID (frontend-scoped) |
   | Violations found | 0 |
   | Status | **PASSED** |

   ---
   *This review was generated by the PR Code Review Validator.*
   ```

3. **No approval** — approval is left to human reviewers

4. **Workflow exit code** — zero (status check passes)

### When no code files are changed

1. **Cleanup** — dismiss any previous `REQUEST_CHANGES` reviews from prior runs

2. **Summary comment:**

   ```markdown
   <!-- pr-code-review-validator -->
   ## REVIEW SKIPPED — no code files changed

   Only non-code files were modified in this PR. No skill-based review needed.
   Status: **PASSED**

   ---
   *This review was generated by the PR Code Review Validator.*
   ```

3. **Workflow exit code** — zero (status check passes)

### When Stage 3 filters all findings as false positives

If Stage 2 found violations but Stage 3 (Opus) determined they were all false positives:

1. **Summary comment:**

   ```markdown
   <!-- pr-code-review-validator -->
   ## REVIEW COMPLETE — PASSED (after review)

   | Metric | Value |
   |--------|-------|
   | Files checked | 4 (2 changed, 2 related) |
   | Skills applied | backend-best-practices, SOLID (backend-scoped) |
   | Initial findings | 2 |
   | False positives filtered | 2 |
   | Violations confirmed | 0 |
   | Status | **PASSED** |

   ### Filtered findings (informational)
   - ~Rule 4: Zod Validation — `pages/api/products.ts:10`~ — Input is already validated by upstream middleware in `lib/middleware.ts:25`
   - ~Rule 7: Database Optimization — `lib/productService.ts:30`~ — Query is correctly using `findUnique` for single-record lookup

   ---
   *This review was generated by the PR Code Review Validator.*
   ```

2. **Workflow exit code** — zero (status check passes)

This transparency shows the team that the pipeline is working and explains why certain patterns were not flagged.

---

## Blocking Behavior

- The workflow is configured as a **required status check** in GitHub branch protection rules for `main`
- **Any confirmed violation** blocks merging — there are no severity tiers; all rules are enforced equally
- Once all violations are resolved (developer pushes fixes, workflow re-runs and finds zero violations), the PR becomes mergeable
- No re-review cycle after fixes — the workflow runs fresh on each push, and a clean pass is the final word
- Human approval is a separate requirement — the workflow handles rule compliance, humans handle design/logic review

---

## Cleanup on Re-run

When the workflow runs on a new push to the PR branch, **before** running the pipeline:

1. **Find all previous reviews** posted by `github-actions[bot]` that contain the `<!-- pr-code-review-validator -->` marker
2. **Dismiss any `REQUEST_CHANGES` reviews** from prior runs using the GitHub API (`PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals`)
3. **Resolve or minimize previous inline comments** from prior runs — resolved comments collapse in the GitHub UI, reducing visual noise
4. Run the pipeline fresh and post new findings (if any)

This ensures the PR always reflects the **current state** of the code, not stale findings from old commits. Developers never have to manually dismiss outdated reviews.

### Cleanup API calls

```
# List reviews to find prior bot reviews
GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews

# Dismiss a previous REQUEST_CHANGES review
PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals
  Body: { "message": "Superseded by new review run" }

# List review comments to find prior inline comments
GET /repos/{owner}/{repo}/pulls/{pull_number}/comments

# Minimize (hide) outdated comments
POST /graphql
  mutation { minimizeComment(input: { subjectId: "<comment_node_id>", classifier: OUTDATED }) { ... } }
```

---

## CI/CD Configuration

### GitHub Actions Workflow

The workflow file lives at `.github/workflows/pr-code-review-validator.yml`.

```yaml
name: PR Code Review Validator

on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened, ready_for_review]

concurrency:
  group: pr-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  review:
    if: ${{ !github.event.pull_request.draft }}
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git diff against main

      - name: Install Claude Code CLI
        run: npm install -g @anthropic-ai/claude-code

      - name: Clean up prior reviews
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Dismiss prior REQUEST_CHANGES reviews and minimize old inline comments
          # (script details in Cleanup section)

      - name: Run review pipeline
        env:
          ANTHROPIC_BEDROCK_BASE_URL: ${{ secrets.BEDROCK_BASE_URL }}
          ANTHROPIC_CUSTOM_HEADERS: "x-portkey-api-key:${{ secrets.PORTKEY_API_KEY }}\nx-portkey-provider: @aws-bedrock-use2"
          CLAUDE_CODE_USE_BEDROCK: "1"
          CLAUDE_CODE_SKIP_BEDROCK_AUTH: "1"
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          # Invoke Claude Code CLI with the review pipeline prompt
          # Claude Code orchestrates Haiku -> Sonnet -> Opus stages
          # Output: JSON with review verdict and comments

      - name: Post review to PR
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Parse pipeline output
          # Post bundled review with inline comments via GitHub API
          # Set exit code based on verdict
```

### Required Secrets (GitHub Actions)

| Secret | Purpose |
|--------|---------|
| `BEDROCK_BASE_URL` | Portkey gateway URL (e.g., `https://portkeygateway.perficient.com/v1`) |
| `PORTKEY_API_KEY` | Portkey API key for authentication |

**Important:** These must be stored as **GitHub repository secrets** (Settings > Secrets and variables > Actions). Never hardcode these values in the workflow file.

### Non-secret Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_CODE_USE_BEDROCK` | `1` | Route Claude Code through Bedrock |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` | `1` | Skip native Bedrock auth (Portkey handles it) |

### GitHub Token

Uses the built-in `GITHUB_TOKEN` (automatically available in every workflow run) for:
- Posting PR reviews and inline comments
- Dismissing prior reviews
- Minimizing outdated comments via GraphQL API

The workflow requires `pull-requests: write` permission, which is declared in the workflow's `permissions` block. No personal PAT is needed.

### Prerequisites

1. **Network access**: The GitHub-hosted runner must be able to reach the Portkey gateway URL (`https://portkeygateway.perficient.com/v1`). Verify with the Perficient infrastructure team whether IP whitelisting or VPN is required. If the gateway is not reachable from GitHub-hosted runners, a **self-hosted runner** inside the corporate network may be needed.
2. **Branch protection**: `main` must have the workflow's status check (`PR Code Review Validator / review`) configured as a **required status check** in branch protection rules.
3. **Claude Code CLI compatibility**: The CLI must support the Bedrock/Portkey configuration via environment variables. Verify that the installed CLI version supports `ANTHROPIC_BEDROCK_BASE_URL` and `ANTHROPIC_CUSTOM_HEADERS`.

---

## Claude Code CLI Invocation

The workflow invokes Claude Code CLI with a structured prompt that orchestrates the three-stage pipeline. The CLI manages agent spawning (Haiku, Sonnet, Opus) internally.

### Invocation pattern

```bash
claude --print --model haiku --output-format json <<'PROMPT'
You are the PR Code Review Validator orchestrator.

[Stage 1 instructions: classification]
[Stage 2 instructions: spawn Sonnet agents for validation]
[Stage 3 instructions: spawn Opus agent for synthesis if violations found]

Output a JSON object with:
- verdict: "pass" | "fail" | "skip"
- summary: markdown string for the review body
- inline_comments: array of { path, line, body }
PROMPT
```

The `--print` flag runs non-interactively (no REPL). The `--output-format json` flag ensures structured output that the workflow can parse. The `--model haiku` flag sets the orchestrator model; sub-agents are spawned at their respective model tiers within the prompt.

### Output contract

The pipeline outputs a JSON object:

```json
{
  "verdict": "fail",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — VIOLATIONS FOUND\n...",
  "inline_comments": [
    {
      "path": "pages/api/products.ts",
      "line": 15,
      "side": "RIGHT",
      "body": "**backend-best-practices > Rule 6: Security**\n\nNo auth middleware...\n\n<!-- pr-code-review-validator -->"
    }
  ],
  "stats": {
    "files_checked": 5,
    "files_changed": 3,
    "files_related": 2,
    "skills_applied": ["backend-best-practices", "design-patterns (backend-scoped)", "SOLID (backend-scoped)"],
    "violations_found": 4,
    "false_positives_filtered": 1
  }
}
```

The workflow parses this JSON to post the review via the GitHub API.

---

## Notification Behavior

- **Single notification** per review — all inline comments are bundled into one GitHub review, so the PR author gets one email/notification, not one per violation
- On clean re-run, previous violation comments are minimized (collapsed in the UI), avoiding notification noise from deletion/recreation
- The review author is `github-actions[bot]`, so notifications come from a bot, not a teammate

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Skill file missing or unreadable | Log warning to workflow output, skip that skill's validation, proceed with remaining skills. If ALL skills are missing, fail the workflow. |
| Stage 1 (Haiku) timeout (>30s) | Fail the workflow with error message |
| Stage 2 (Sonnet) timeout (>120s) | Fail the workflow with error message |
| Stage 3 (Opus) timeout (>180s) | Fail the workflow with error message |
| Job timeout (>10 min) | GitHub cancels the workflow; status check stays pending (blocks merge) |
| Agent crash / unexpected error | Fail the workflow with error message |
| `git diff` fails | Fail the workflow with error message |
| No code files in PR | Post "REVIEW SKIPPED" comment, exit 0 (pass) |
| Portkey gateway unreachable | Fail the workflow with a clear connectivity error |
| GitHub API rate limit | Retry with exponential backoff (3 attempts), then fail |
| Claude Code CLI not installed | Fail at the install step with clear error |
| Pipeline outputs invalid JSON | Fail the workflow with parsing error |
| PR has more than 50 code files | Post large-PR warning, run review with extended timeout |

**Fail-closed policy:** Unlike the post-tool-use hook (which fails open to avoid deadlocking Claude), the PR review **fails closed** — if anything goes wrong, the status check fails and merging is blocked. This is the correct behavior for a merge gate: it's safer to block a merge on error than to silently allow unreviewed code through.

---

## Constraints

- The workflow must always read skill files fresh from `.claude/skills/` — never use hardcoded or cached rules
- Design patterns and SOLID are always scoped to the triggering skill context — never applied generically
- Non-code files are always skipped (see ignore list)
- Related file tracing is limited to **one level deep** to prevent scope explosion
- The workflow **never approves** the PR — it only blocks (request changes) or unblocks (dismiss + pass)
- Review comments are always bundled as a **single review** (one notification)
- Previous run findings are always cleaned up on re-run
- The workflow uses the built-in `GITHUB_TOKEN`, not a personal PAT
- The workflow fails closed on errors (blocks merge)
- The workflow respects `concurrency` to prevent duplicate reviews on rapid pushes
- New files are additionally validated for correct folder placement, naming, and internal structure

---

## Relationship to Post-Tool-Use Validator

| Aspect | Post-Tool-Use Hook | PR Code Review |
|--------|-------------------|----------------|
| **When** | Real-time, after every code change | On PR events (open, push, reopen) |
| **Where** | Local, in Claude Code session | CI, in GitHub Actions |
| **Rules** | Same `.claude/skills/` | Same `.claude/skills/` |
| **Classification** | Same path-based logic | Same path-based logic |
| **Scoping** | Changed file + 1 level related | PR diff + 1 level related |
| **On violation** | Auto-fix (up to 3 attempts) | Report as PR review (no auto-fix) |
| **Failure mode** | Fail-open (don't block Claude) | Fail-closed (block merge) |
| **Blocking** | Blocks Claude's next action | Blocks PR merge |
| **Toggle** | `isPostToolUseEnabledCodeChanges` env var | Always on for PRs to `main` |

The two systems are complementary: the hook catches violations during development (shift-left), while the PR review is the final enforcement gate before code reaches `main`. Code that passes the hook should also pass the PR review, since they use the same rules.

---

## Branch Protection Setup

To complete the setup, the following branch protection rules must be configured for `main`:

1. **Require status checks to pass before merging**: enabled
2. **Required status checks**: add `PR Code Review Validator / review`
3. **Require branches to be up to date before merging**: recommended (ensures the review ran against the latest base)
4. **Require pull request reviews before merging**: configure separately for human review (independent of this workflow)

This can be configured via GitHub UI (Settings > Branches > Branch protection rules) or via the GitHub API:

```bash
gh api repos/{owner}/{repo}/branches/main/protection --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["PR Code Review Validator / review"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}'
```
