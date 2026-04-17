# Stateful PR Review System

## Overview

Replace the current ephemeral PR review system with a stateful, incremental review pipeline that persists issue state across pushes in a committed JSON file. The system tracks which violations have been fixed, which remain open, and which are newly introduced — providing a cumulative, accurate view of PR health over its lifetime.

## Goals

1. **Persistent state**: Store all review history in `.github/pr/pr-{number}.json`, committed to the repo automatically by the GitHub Action.
2. **Incremental verification**: On subsequent pushes, verify whether previously reported violations still exist rather than re-discovering them from scratch (avoids AI non-determinism).
3. **New change detection**: Validate only genuinely new changes (not previously reviewed) against `nextjs-react-best-practices` and `backend-best-practices`.
4. **Cumulative summary**: Always display a full picture — all historically fixed issues and all currently open issues.
5. **Automatic cleanup**: Delete the `pr-{number}.json` file when the PR is merged.

## Current System

The existing system consists of:

- **Workflow**: `.github/workflows/pr-code-review-validator.yml` — triggers on `opened`, `synchronize`, `reopened`, `ready_for_review`
- **Scripts**:
  - `detect-review-mode.sh` — determines full vs incremental by parsing prior GitHub review comments
  - `run-review-pipeline.sh` — invokes Claude CLI with a multi-agent pipeline (Haiku orchestrator -> Sonnet validators -> Opus synthesizer)
  - `post-review.sh` — posts bundled GitHub review with inline comments
  - `cleanup-prior-reviews.sh` — dismisses prior REQUEST_CHANGES reviews

### Current Limitations

- State is reconstructed from GitHub review comments on each run (fragile, comment-parsing dependent)
- `prior-findings.json` is ephemeral (not committed), only exists during the workflow run
- Incremental mode carries forward untouched violations verbatim but doesn't track fix history
- No cumulative view of what was fixed over time
- Re-runs generate fresh violation lists, making matching unreliable due to AI non-determinism

## New System Design

### State File: `.github/pr/pr-{number}.json`

Location: `.github/pr/pr-{number}.json` (committed to repo)

#### Schema

```json
{
  "pr_number": 42,
  "created_at": "2026-04-17T10:00:00Z",
  "last_updated": "2026-04-17T12:30:00Z",
  "reviews": [
    {
      "round": 1,
      "commit_sha": "abc1234",
      "timestamp": "2026-04-17T10:00:00Z",
      "type": "full",
      "current_issues": [
        {
          "id": "issue-1-abc123",
          "skill": "nextjs-react-best-practices",
          "rule": "Cat 5: TypeScript Strictness",
          "scope": "frontend",
          "path": "pages/test-r1.tsx",
          "line": 3,
          "description": "Todo interface defined inline instead of in types/ directory",
          "suggestion": "Move the Todo interface to types/todo.ts and import it",
          "severity": "Critical",
          "status": "open",
          "found_in_round": 1,
          "resolved_in_round": null,
          "inline_comment_body": "**nextjs-react-best-practices > Cat 5: TypeScript Strictness**\n\n..."
        }
      ],
      "fixed_issues": []
    },
    {
      "round": 2,
      "commit_sha": "def5678",
      "timestamp": "2026-04-17T12:30:00Z",
      "type": "incremental",
      "current_issues": [
        {
          "id": "issue-5-xyz789",
          "skill": "nextjs-react-best-practices",
          "rule": "Cat 8: Error Handling",
          "scope": "frontend",
          "path": "pages/test-r1.tsx",
          "line": 40,
          "description": "Missing ARIA roles for accessibility",
          "suggestion": "Add appropriate ARIA roles...",
          "severity": "Recommended",
          "status": "open",
          "found_in_round": 1,
          "resolved_in_round": null,
          "inline_comment_body": "..."
        }
      ],
      "fixed_issues": [
        {
          "id": "issue-1-abc123",
          "skill": "nextjs-react-best-practices",
          "rule": "Cat 5: TypeScript Strictness",
          "scope": "frontend",
          "path": "pages/test-r1.tsx",
          "line": 3,
          "description": "Todo interface defined inline instead of in types/ directory",
          "resolved_in_round": 2
        }
      ]
    }
  ],
  "all_fixed_issues": [
    {
      "id": "issue-1-abc123",
      "skill": "nextjs-react-best-practices",
      "rule": "Cat 5: TypeScript Strictness",
      "path": "pages/test-r1.tsx",
      "description": "Todo interface defined inline instead of in types/ directory",
      "found_in_round": 1,
      "resolved_in_round": 2
    }
  ],
  "all_current_issues": [
    {
      "id": "issue-5-xyz789",
      "skill": "nextjs-react-best-practices",
      "rule": "Cat 8: Error Handling",
      "path": "pages/test-r1.tsx",
      "description": "Missing ARIA roles for accessibility",
      "found_in_round": 1,
      "status": "open"
    }
  ]
}
```

#### Issue ID Generation

Each issue gets a unique ID composed of: `issue-{auto_increment}-{short_hash}` where the short hash is derived from `skill + rule + path` to aid in human readability. The auto-increment ensures uniqueness even if the same rule is violated in the same file in different ways.

### Workflow Phases

#### Phase 1: First Push (PR Opened)

1. GitHub Action triggers on `opened` / `ready_for_review`
2. No `pr-{number}.json` exists yet — run a **full review** (same as current Stage 1-3 pipeline)
3. Collect all violations from the pipeline
4. Create `.github/pr/pr-{number}.json` with:
   - `round: 1`, `type: "full"`
   - All violations as `current_issues` with `status: "open"`, `found_in_round: 1`
   - `fixed_issues: []`
   - `all_fixed_issues: []`
   - `all_current_issues: [all violations]`
5. Commit and push the JSON file (auto-commit by Action)
6. Post GitHub review as currently done (inline comments + summary)

#### Phase 2: Subsequent Pushes (Incremental)

1. GitHub Action triggers on `synchronize`
2. **Skip check**: If the only changed files are in `.github/pr/`, skip the workflow entirely
3. Read existing `.github/pr/pr-{number}.json` — this is the source of truth
4. Compute the diff from the last reviewed commit to HEAD
5. **Two-part review**:

   **Part A — Verify existing issues (touched files only):**
   - For each file that was modified in this push AND has open issues in the state file:
     - Read the current version of the file
     - For each open issue on that file, ask the AI: "Does this specific violation still exist in the current code?" (yes/no verification)
     - If no: mark as fixed (`resolved_in_round: N`)
     - If yes: keep as open
   - For open issues on files NOT touched in this push: carry forward as-is (still open)

   **Part B — Validate new changes:**
   - Identify files changed in this push that either:
     - Had no prior issues, OR
     - Have new code beyond what was previously reviewed
   - Run the current validation pipeline (Sonnet agents) on ONLY these new changes
   - Any new violations become new `current_issues` with `found_in_round: N`

6. Update `.github/pr/pr-{number}.json`:
   - Add new review round to `reviews[]`
   - Update `all_fixed_issues` (cumulative — never remove from this list)
   - Update `all_current_issues` (only currently open issues)
7. Commit and push the updated JSON file
8. Post GitHub review with the summary format (see below)

#### Phase 3: Regression Detection

- If a previously fixed issue's file is modified again in a later push, the verification step (Part A) will re-evaluate it
- If the violation reappears, it moves back from "fixed" to "current issues"
- The `all_fixed_issues` list removes it; `all_current_issues` adds it back
- This handles the scenario: "fix issues 1-5, then later undo fix for issue 4"

#### Phase 4: PR Merge Cleanup

- A separate workflow triggers on `pull_request: closed` (merged)
- Deletes `.github/pr/pr-{number}.json`
- Commits and pushes the deletion

### Summary Format

The GitHub review comment must always show:

```markdown
## PR Review — Round {N}

| Metric | Value |
|--------|-------|
| Review round | {N} |
| Review type | Full / Incremental |
| Files checked | {count} |
| Current issues | {count} |
| Fixed (this round) | {count} |
| Fixed (cumulative) | {count} |
| Status | **BLOCKED** / **PASSED** |

### List of Changes Fixed (Cumulative)

- [x] ~~**nextjs-react-best-practices > Cat 5: TypeScript Strictness** — `pages/test-r1.tsx:3` — Todo interface defined inline instead of in types/ directory~~ *(fixed in round 2)*
- [x] ~~**nextjs-react-best-practices > Cat 1: Container-Presentational** — `pages/test-r1.tsx:10` — Component mixes data fetching with rendering logic~~ *(fixed in round 2)*

### Current Issues

- [ ] **nextjs-react-best-practices > Cat 8: Error Handling** — `pages/test-r1.tsx:40` — Missing ARIA roles for accessibility *(since round 1)*
- [ ] **backend-best-practices > Rule 4: Zod Validation** — `pages/api/users.ts:12` — Missing input validation *(new in round 3)*
```

When there are zero current issues:

```markdown
## PR Review — Round {N}

| Metric | Value |
|--------|-------|
| Review round | {N} |
| Review type | Incremental |
| Current issues | 0 |
| Fixed (cumulative) | {count} |
| Status | **PASSED — Ready to merge** |

### List of Changes Fixed (Cumulative)

- [x] ~~**nextjs-react-best-practices > Cat 5: TypeScript Strictness** — `pages/test-r1.tsx:3` — Todo interface defined inline instead of in types/ directory~~ *(fixed in round 2)*
- [x] ~~**nextjs-react-best-practices > Cat 1: Container-Presentational** — `pages/test-r1.tsx:10` — Component mixes data fetching with rendering logic~~ *(fixed in round 3)*

All issues resolved. This PR is ready to merge.
```

### Bot Auto-Commit Handling

The GitHub Action must auto-commit the JSON state file after each review. To prevent infinite loops:

1. The commit message should follow a specific pattern, e.g.: `chore(review): update pr-{number} review state [skip ci]`
   - Note: `[skip ci]` alone may not prevent the `pull_request: synchronize` event from firing
2. **Primary skip mechanism**: At the start of the workflow, check if the push only modified files in `.github/pr/`. If so, skip the review entirely
3. The workflow step that auto-commits should use a bot token or `github-actions[bot]` identity

### AI Non-Determinism Strategy (Point 8)

The key design decision to handle non-determinism:

1. **Never re-detect to check if fixed**: Instead of running a fresh scan and comparing outputs, the AI is given each specific prior violation and asked: "Does this exact violation still exist in the current code?" This is a focused yes/no question with much higher consistency than open-ended detection.

2. **Fresh detection only for new code**: New changes (files or code sections not previously reviewed) go through the standard detection pipeline. This is acceptable because there's no prior state to match against — it's fresh discovery.

3. **Stable issue identity**: Issues are tracked by ID in the JSON file, not by trying to match AI-generated descriptions across runs. Once an issue is recorded, its identity is fixed.

4. **Verification prompt engineering**: The verification prompt should include:
   - The exact violation description from the state file
   - The exact file path and original line number
   - The current file contents
   - A clear instruction: "Determine if this specific violation has been addressed. Consider that the code may have moved to a different line or been refactored. Answer: FIXED or STILL_PRESENT with a brief explanation."

### Files to Modify / Create

1. **Modify**: `.github/workflows/pr-code-review-validator.yml` — add skip logic, auto-commit step, merge cleanup job
2. **Create**: `.github/workflows/pr-review-cleanup.yml` — separate workflow for merge-time cleanup
3. **Modify**: `.github/scripts/detect-review-mode.sh` — read state from JSON file instead of parsing GitHub comments
4. **Modify**: `.github/scripts/run-review-pipeline.sh` — restructure pipeline to support verification mode + new change detection
5. **Modify**: `.github/scripts/post-review.sh` — update summary format to show cumulative fixed/current
6. **Create**: `.github/scripts/commit-review-state.sh` — auto-commit the JSON state file
7. **Modify or remove**: `.github/scripts/cleanup-prior-reviews.sh` — may still be needed for dismissing GitHub reviews, but the comment-parsing logic is no longer needed
8. **Update**: `.gitignore` — ensure `.github/pr/` is NOT gitignored

### Constraints

- The review pipeline still uses Claude CLI with the multi-agent architecture (Haiku orchestrator, Sonnet validators, Opus synthesizer)
- The `nextjs-react-best-practices` and `backend-best-practices` skills remain the authoritative rules
- SOLID and design-patterns skills still apply as secondary checks
- The GitHub Action must not require developer intervention for state management
- The JSON file must be valid and parseable at all times
- If the JSON file is corrupted or missing when expected, fall back to a full review and recreate it

### Edge Cases

1. **Force push / rebase**: The commit ancestry breaks. Fall back to full review, but preserve the `all_fixed_issues` history from the existing JSON (if it exists). Reset `all_current_issues` from the fresh full review.
2. **File deleted**: If a file with open issues is deleted, mark all its issues as fixed.
3. **File renamed**: Track by content similarity — if a file is renamed but content is similar, map the old issues to the new path.
4. **Concurrent pushes**: The `concurrency` group in the workflow already handles this (cancel-in-progress).
5. **JSON file manually edited**: Trust the file as-is. If it's malformed, fall back to full review.
6. **PR reopened**: If the JSON file still exists, continue from where it left off. If deleted, start fresh.
7. **Draft PR**: Skip review (same as current behavior).
8. **Multiple files changed**: Group verification by file — read each file once, verify all its issues together.
