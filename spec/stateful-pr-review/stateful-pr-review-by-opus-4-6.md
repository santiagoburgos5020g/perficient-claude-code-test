# Stateful PR Review System

## Overview

Replace the current ephemeral PR review system with a stateful, incremental review pipeline that persists issue state across pushes in a committed JSON file (`.github/pr/pr-{number}.json`). The system tracks which violations have been fixed, which remain open, and which are newly introduced — providing a cumulative, accurate view of PR health over its lifetime.

The core innovation is **verification over re-detection**: instead of running a fresh scan and trying to match violations across runs (which fails due to AI non-determinism), the system asks the AI a focused yes/no question for each prior violation: "Does this specific violation still exist?"

## Goals

1. **Persistent state**: Store all review history in `.github/pr/pr-{number}.json`, committed to the repo automatically by the GitHub Action.
2. **Incremental verification**: On subsequent pushes, verify whether previously reported violations still exist rather than re-discovering them from scratch.
3. **New change detection**: Validate only genuinely new changes (not previously reviewed) against `nextjs-react-best-practices` and `backend-best-practices`.
4. **Cumulative summary**: Always display a full picture — all currently fixed issues and all currently open issues.
5. **Regression detection**: If a previously fixed violation reappears after later changes, move it back to current issues.
6. **Automatic cleanup**: Delete the `pr-{number}.json` file when the PR is merged.

## Current System

### Existing Components

- **Workflow**: `.github/workflows/pr-code-review-validator.yml` — triggers on `opened`, `synchronize`, `reopened`, `ready_for_review`
- **Scripts**:
  - `detect-review-mode.sh` — determines full vs incremental by parsing prior GitHub review comments
  - `run-review-pipeline.sh` — invokes Claude CLI with a multi-agent pipeline (Haiku orchestrator -> Sonnet validators -> Opus synthesizer)
  - `post-review.sh` — posts bundled GitHub review with inline comments
  - `cleanup-prior-reviews.sh` — dismisses prior REQUEST_CHANGES reviews and minimizes old inline comments

### Current Limitations

- State is reconstructed from GitHub review comments on each run (fragile, comment-parsing dependent)
- `prior-findings.json` is ephemeral (not committed), only exists during the workflow run
- Incremental mode carries forward untouched violations verbatim but doesn't track fix history
- No cumulative view of what was fixed over time
- Re-runs generate fresh violation lists, making matching unreliable due to AI non-determinism
- No regression detection — once an issue is marked as carried forward, it stays that way until the file is touched

---

## New System Design

### State File: `.github/pr/pr-{number}.json`

Location: `.github/pr/pr-{number}.json` (committed to the repo by the GitHub Action)

#### Schema

```json
{
  "pr_number": 42,
  "base_branch": "main",
  "head_branch": "feature/my-feature",
  "created_at": "2026-04-17T10:00:00Z",
  "last_updated": "2026-04-17T14:00:00Z",
  "next_issue_id": 6,
  "reviews": [
    {
      "round": 1,
      "commit_sha": "abc1234",
      "timestamp": "2026-04-17T10:00:00Z",
      "type": "full",
      "files_checked": ["pages/test-r1.tsx", "pages/api/users.ts"],
      "newly_fixed_ids": [],
      "newly_found_ids": ["issue-1", "issue-2", "issue-3", "issue-4", "issue-5"],
      "regressed_ids": []
    },
    {
      "round": 2,
      "commit_sha": "def5678",
      "timestamp": "2026-04-17T12:30:00Z",
      "type": "incremental",
      "files_checked": ["pages/test-r1.tsx"],
      "newly_fixed_ids": ["issue-1", "issue-2", "issue-3", "issue-4"],
      "newly_found_ids": [],
      "regressed_ids": []
    },
    {
      "round": 3,
      "commit_sha": "ghi9012",
      "timestamp": "2026-04-17T14:00:00Z",
      "type": "incremental",
      "files_checked": ["pages/test-r1.tsx", "components/NewWidget.tsx"],
      "newly_fixed_ids": ["issue-5"],
      "newly_found_ids": ["issue-6"],
      "regressed_ids": []
    }
  ],
  "issues": {
    "issue-1": {
      "skill": "nextjs-react-best-practices",
      "rule": "Cat 5: TypeScript Strictness",
      "scope": "frontend",
      "path": "pages/test-r1.tsx",
      "line": 3,
      "description": "Todo interface defined inline instead of in types/ directory",
      "suggestion": "Move the Todo interface to types/todo.ts and import it",
      "severity": "Critical",
      "status": "fixed",
      "found_in_round": 1,
      "resolved_in_round": 2,
      "inline_comment_body": "**nextjs-react-best-practices > Cat 5: TypeScript Strictness**\n\nThe Todo interface is defined inline...\n\n**Suggestion:** Move to types/todo.ts\n\n<!-- pr-code-review-validator -->"
    },
    "issue-2": {
      "skill": "nextjs-react-best-practices",
      "rule": "Cat 1: Container-Presentational Component Pattern",
      "scope": "frontend",
      "path": "pages/test-r1.tsx",
      "line": 10,
      "description": "Component mixes data fetching with rendering logic",
      "suggestion": "Split into a container (data fetching) and presentational (rendering) component",
      "severity": "Critical",
      "status": "fixed",
      "found_in_round": 1,
      "resolved_in_round": 2,
      "inline_comment_body": "..."
    },
    "issue-6": {
      "skill": "nextjs-react-best-practices",
      "rule": "Cat 13: Accessibility",
      "scope": "frontend",
      "path": "components/NewWidget.tsx",
      "line": 22,
      "description": "Interactive element missing keyboard event handler",
      "suggestion": "Add onKeyDown handler alongside onClick",
      "severity": "Recommended",
      "status": "open",
      "found_in_round": 3,
      "resolved_in_round": null,
      "inline_comment_body": "..."
    }
  }
}
```

#### Design Decisions for the Schema

1. **Flat `issues` map keyed by ID**: Instead of nesting issues inside each review round, all issues live in a single `issues` map. Each round references issue IDs. This avoids duplication and makes lookups O(1).

2. **Simple auto-increment IDs**: `issue-1`, `issue-2`, etc. The `next_issue_id` counter in the root ensures uniqueness. No hash needed — the ID is just a stable reference, not a semantic key.

3. **Status field**: Each issue has `status: "open" | "fixed"`. When a regression occurs, the status flips back to `"open"` and `resolved_in_round` resets to `null`.

4. **Compact review rounds**: Each round stores only IDs (`newly_fixed_ids`, `newly_found_ids`, `regressed_ids`), not full issue objects. This keeps the file small across many rounds.

5. **Derived lists**: `all_current_issues` and `all_fixed_issues` are NOT stored in the JSON — they are computed from the `issues` map by filtering on `status`. This avoids stale data.

---

### Workflow Phases

#### Phase 1: First Push (PR Opened)

1. GitHub Action triggers on `opened` / `reopened` / `ready_for_review`
2. No `.github/pr/pr-{number}.json` exists yet — run a **full review**
3. Execute the current 3-stage pipeline (Haiku orchestrator -> Sonnet validators -> Opus synthesizer) against all changed files vs `origin/main`
4. Collect confirmed violations from the pipeline output
5. Create `.github/pr/pr-{number}.json`:
   - `round: 1`, `type: "full"`
   - All violations added to `issues` map with `status: "open"`, `found_in_round: 1`
   - `newly_found_ids` lists all issue IDs
   - `newly_fixed_ids: []`, `regressed_ids: []`
6. Auto-commit and push the JSON file (see [Bot Auto-Commit](#bot-auto-commit-handling))
7. Post GitHub review: inline comments for each violation + summary

#### Phase 2: Subsequent Pushes (Incremental)

1. GitHub Action triggers on `synchronize`
2. **Skip check** (see [Skip Logic](#skip-logic-for-bot-commits)): exit early if this push only modified `.github/pr/` files
3. Read existing `.github/pr/pr-{number}.json`
   - If missing or malformed: fall back to Phase 1 (full review), preserving any previously fixed issues if the JSON was partially readable
4. Compute incremental diff: `git diff --name-only {last_reviewed_commit}..HEAD`
5. Filter to code files (same patterns as current `detect-review-mode.sh`)

6. **Part A — Verify existing open issues on touched files:**
   - Collect all issues from the `issues` map where `status == "open"` AND `path` is in the changed file list
   - For each such file, read its current contents
   - Send the AI a **verification prompt** (see [Verification Agent](#verification-agent-prompt)): for each open issue on that file, determine FIXED or STILL_PRESENT
   - Mark fixed issues: set `status: "fixed"`, `resolved_in_round: N`
   - Keep still-present issues as `status: "open"`

7. **Part A.2 — Check for regressions on touched files:**
   - Collect all issues from the `issues` map where `status == "fixed"` AND `path` is in the changed file list
   - For each such file (which is already read from Part A), send the AI the same verification prompt for the fixed issues
   - If a previously fixed violation is now STILL_PRESENT: set `status: "open"`, `resolved_in_round: null`, add to `regressed_ids`

8. **Part A.3 — Handle deleted files:**
   - If a file in the diff was deleted (exists in state but not on disk), mark ALL its open issues as fixed
   - Do NOT regress its fixed issues (file no longer exists)

9. **Part B — Validate new changes:**
   - Identify code files in the diff that are NOT referenced by any issue in the state file (completely new to the review)
   - ALSO: for files that DO have prior issues but have new/changed code beyond the violation sites, the validation agent should scan the entire file for new violations (the verification agent already reads the whole file, so this can be combined)
   - Run the standard validation pipeline (Sonnet agents) on these files, classifying as frontend/backend per existing rules
   - Run the Opus synthesis agent to filter false positives (same as current Stage 3)
   - Add confirmed new violations to the `issues` map with `found_in_round: N`

10. **Update state file:**
    - Append a new round to `reviews[]` with `newly_fixed_ids`, `newly_found_ids`, `regressed_ids`
    - Update `next_issue_id` counter
    - Set `last_updated` timestamp

11. Auto-commit and push the updated JSON file
12. Post GitHub review with cumulative summary

#### Phase 3: PR Merge Cleanup

- A **separate workflow** (`.github/workflows/pr-review-cleanup.yml`) triggers on `pull_request: types: [closed]`
- **Only runs if merged**: check `github.event.pull_request.merged == true`
- Deletes `.github/pr/pr-{number}.json` if it exists
- Commits and pushes the deletion with message: `chore(review): cleanup pr-{number} review state`

---

### Summary Format

The GitHub review comment posted on every round:

#### When issues exist (BLOCKED)

```markdown
<!-- pr-code-review-validator -->
## PR Review — Round {N}

| Metric | Value |
|--------|-------|
| Review round | {N} |
| Review type | Full / Incremental |
| Files checked | {count} |
| Current issues | {open_count} |
| Fixed (this round) | {newly_fixed_count} |
| Fixed (cumulative) | {total_fixed_count} |
| Regressions | {regressed_count} |
| Status | **BLOCKED** |

### List of Changes Fixed

- [x] ~~**nextjs-react-best-practices > Cat 5: TypeScript Strictness** — `pages/test-r1.tsx:3` — Todo interface defined inline instead of in types/ directory~~ *(fixed in round 2)*
- [x] ~~**nextjs-react-best-practices > Cat 1: Container-Presentational** — `pages/test-r1.tsx:10` — Component mixes data fetching with rendering logic~~ *(fixed in round 2)*
- [x] ~~**nextjs-react-best-practices > Cat 7: useSWR Best Practices** — `pages/test-r1.tsx:15` — Uses forbidden useEffect+fetch pattern instead of useSWR~~ *(fixed in round 3)*

### Current Issues

- [ ] **nextjs-react-best-practices > Cat 8: Error Handling** — `pages/test-r1.tsx:40` — Missing ARIA roles for accessibility *(since round 1)*
- [ ] **nextjs-react-best-practices > Cat 13: Accessibility** — `components/NewWidget.tsx:22` — Interactive element missing keyboard event handler *(new in round 3)*

---
*This review was generated by the PR Code Review Validator (stateful mode).*
*Review state: `.github/pr/pr-{N}.json`*
```

#### When regressions are found

Add a section before Current Issues:

```markdown
### Regressions

- [ ] **nextjs-react-best-practices > Cat 5: TypeScript Strictness** — `pages/test-r1.tsx:3` — Todo interface defined inline instead of in types/ directory *(was fixed in round 2, regressed in round 5)*
```

#### When all issues are resolved (PASSED)

```markdown
<!-- pr-code-review-validator -->
## PR Review — Round {N}

| Metric | Value |
|--------|-------|
| Review round | {N} |
| Review type | Incremental |
| Current issues | 0 |
| Fixed (cumulative) | {total_fixed_count} |
| Status | **PASSED — Ready to merge** |

### List of Changes Fixed

- [x] ~~**nextjs-react-best-practices > Cat 5: TypeScript Strictness** — `pages/test-r1.tsx:3` — Todo interface defined inline instead of in types/ directory~~ *(fixed in round 2)*
- [x] ~~**nextjs-react-best-practices > Cat 1: Container-Presentational** — `pages/test-r1.tsx:10` — Component mixes data fetching with rendering logic~~ *(fixed in round 3)*

All issues resolved. This PR is ready to merge.

---
*This review was generated by the PR Code Review Validator (stateful mode).*
```

#### First round with no issues (clean PR)

```markdown
<!-- pr-code-review-validator -->
## PR Review — Round 1

| Metric | Value |
|--------|-------|
| Review round | 1 |
| Review type | Full |
| Files checked | {count} |
| Current issues | 0 |
| Status | **PASSED** |

No violations found. This PR is ready to merge.

---
*This review was generated by the PR Code Review Validator (stateful mode).*
```

---

### Verification Agent Prompt

This is the new agent type introduced by this system. It runs in incremental mode (Part A) to verify whether specific prior violations still exist.

```
You are the Issue Verification Agent. You are given a list of previously reported
violations and the current code. For each violation, determine if it has been FIXED
or is STILL_PRESENT.

FILE: {path}
CURRENT FILE CONTENTS:
{full file contents}

VIOLATIONS TO VERIFY:
{JSON array of issues from the state file for this file}

For each violation:
1. Read the violation description, rule, original line number, and suggestion
2. Examine the current file contents — the code may have moved to a different
   line, been refactored, or been removed entirely
3. Determine:
   - FIXED: The violation no longer exists. The code was changed, moved to the
     correct location, refactored to comply with the rule, or the offending code
     was removed.
   - STILL_PRESENT: The same violation still exists in the file, even if at a
     different line number.

IMPORTANT:
- Judge based on the RULE and DESCRIPTION, not the exact line number. Code shifts.
- If the offending code was deleted entirely, that counts as FIXED.
- If the code was moved to another file, check the violation's path — if the file
  no longer contains the offending code, mark as FIXED for this file.
- Be conservative: if unsure, mark as STILL_PRESENT.

Output ONLY a JSON array:
[
  {
    "id": "issue-1",
    "status": "FIXED" | "STILL_PRESENT",
    "explanation": "Brief explanation of why (1-2 sentences)"
  }
]
```

The verification agent should be invoked with model `sonnet` for cost efficiency, since it's doing focused yes/no evaluation rather than open-ended analysis.

---

### Skip Logic for Bot Commits

When the GitHub Action commits the JSON state file back to the PR branch, this push fires a `synchronize` event. Two layers prevent infinite loops:

**Layer 1 — GitHub Token behavior (primary):**
The auto-commit step uses the repository's `GITHUB_TOKEN`. Per GitHub docs, events triggered by `GITHUB_TOKEN` do not create new workflow runs. This means the bot's push will NOT trigger another `pull_request: synchronize` event. This is the primary safeguard.

**Layer 2 — Diff-based skip (fallback safety net):**
At the start of the workflow, after checkout, compute the files changed in the triggering push. If ALL changed files match the pattern `.github/pr/*`, skip the review:

```bash
CHANGED_IN_PUSH=$(git diff --name-only ${{ github.event.before }}..${{ github.event.after }})
NON_REVIEW_FILES=$(echo "$CHANGED_IN_PUSH" | grep -v '^\.github/pr/' || true)
if [[ -z "$NON_REVIEW_FILES" ]]; then
  echo "Skip: only review state files changed"
  exit 0
fi
```

This covers the case where a PAT is used instead of GITHUB_TOKEN (PATs DO trigger workflows).

---

### Bot Auto-Commit Handling

After the review pipeline completes and the JSON state file is written:

```bash
# commit-review-state.sh
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

PR_BRANCH="${{ github.head_ref }}"
git checkout "$PR_BRANCH"

git add ".github/pr/pr-${PR_NUMBER}.json"

# Check if there are actually changes to commit
if git diff --cached --quiet; then
  echo "No changes to review state file. Skipping commit."
  exit 0
fi

git commit -m "chore(review): update pr-${PR_NUMBER} review state [skip ci]"
git push origin "$PR_BRANCH"
```

**Workflow permissions required:**

```yaml
permissions:
  contents: write       # was: read — needed for pushing commits
  pull-requests: write  # unchanged — needed for posting reviews
```

**Checkout configuration:**

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    ref: ${{ github.head_ref }}           # checkout the PR branch, not the merge commit
    token: ${{ secrets.GITHUB_TOKEN }}     # use GITHUB_TOKEN to prevent triggering workflows
```

---

### Files to Modify / Create

| # | Action | File | Changes |
|---|--------|------|---------|
| 1 | **Modify** | `.github/workflows/pr-code-review-validator.yml` | Add `contents: write` permission, change checkout to `ref: github.head_ref`, add skip-logic step, add auto-commit step after post-review, update `detect` step to use JSON state |
| 2 | **Create** | `.github/workflows/pr-review-cleanup.yml` | New workflow: triggers on `pull_request: closed`, deletes JSON file if merged |
| 3 | **Rewrite** | `.github/scripts/detect-review-mode.sh` | Read state from `.github/pr/pr-{number}.json` instead of parsing GitHub comments. Output: `review_mode` (full/incremental), write `review-context.json` with open issues, touched files, new files |
| 4 | **Rewrite** | `.github/scripts/run-review-pipeline.sh` | Split into two paths: full (same as current) and incremental (verification agent + new change detection). Both paths output `pipeline-output.json` AND update the state JSON |
| 5 | **Modify** | `.github/scripts/post-review.sh` | Update summary format to show cumulative fixed/current sections. Read from state JSON for the summary. Still post inline comments for current issues only |
| 6 | **Create** | `.github/scripts/commit-review-state.sh` | Auto-commit the JSON state file to the PR branch |
| 7 | **Simplify** | `.github/scripts/cleanup-prior-reviews.sh` | Keep: dismiss prior REQUEST_CHANGES reviews. Remove: comment-parsing logic (no longer needed for state reconstruction) |

---

### Pipeline Architecture Changes

The current 3-stage pipeline (Classification -> Validation -> Synthesis) remains for:
- **Full reviews** (Phase 1)
- **Part B of incremental reviews** (new change detection)

A new **Verification stage** is added for incremental reviews (Part A):

```
INCREMENTAL REVIEW PIPELINE:
                                          
  ┌──────────────────────┐               
  │  Read state JSON     │               
  │  Compute diff        │               
  └──────────┬───────────┘               
             │                            
     ┌───────┴────────┐                  
     │                │                  
     ▼                ▼                  
  Part A           Part B               
  Verification     New Changes          
  (Sonnet)         (Haiku->Sonnet->Opus)
     │                │                  
     │  FIXED/        │  New violations  
     │  STILL_PRESENT │  (after Opus     
     │                │   filtering)     
     └───────┬────────┘                  
             │                            
             ▼                            
  ┌──────────────────────┐               
  │  Merge results       │               
  │  Update state JSON   │               
  │  Build summary       │               
  └──────────────────────┘               
```

**Part A (Verification)** uses a single Sonnet agent per file (or batched by file group). It reads the file once and evaluates all open issues + fixed issues on that file.

**Part B (New Changes)** uses the existing 3-stage pipeline but scoped to only the new/unreviewed files.

Both parts can run **in parallel** since they operate on different concerns.

---

### AI Non-Determinism Strategy

1. **Never re-detect to check if fixed**: The verification agent is given each specific prior violation and asked "Does this exact violation still exist?" — a focused yes/no question with high consistency.

2. **Fresh detection only for new code**: New changes go through the standard pipeline. No prior state to match against, so non-determinism is irrelevant.

3. **Stable issue identity via IDs**: Issues are tracked by auto-increment ID in the JSON file. Identity is assigned once at creation and never changes.

4. **Conservative verification**: The prompt instructs the agent to mark as STILL_PRESENT when unsure. False negatives (marking a fix as still present) are annoying but safe; false positives (marking an open issue as fixed) could let violations slip through.

5. **Regression verification uses the same prompt**: Previously fixed issues on touched files go through the same verification. If the AI says STILL_PRESENT for a "fixed" issue, it becomes a regression.

---

### Edge Cases

| # | Scenario | Handling |
|---|----------|----------|
| 1 | **Force push / rebase** | Commit ancestry breaks. Fall back to full review. If existing JSON is readable, preserve the `issues` map for historical context but re-verify all issues against the rebased code. |
| 2 | **File deleted** | Mark all open issues on that file as fixed in the current round. Do not regress fixed issues on deleted files. |
| 3 | **File renamed** | Git detects renames in `git diff --name-only -M`. If detected, update the `path` field of all issues referencing the old path to the new path before verification. |
| 4 | **Concurrent pushes** | The `concurrency` group with `cancel-in-progress: true` handles this — only the latest push runs. |
| 5 | **JSON file corrupted / malformed** | Fall back to full review. Log a warning. Recreate the JSON from scratch. |
| 6 | **JSON file missing on incremental** | Fall back to full review. This handles the case where someone manually deleted the file. |
| 7 | **PR reopened** | If JSON file exists, continue from the last round. If deleted (e.g., by merge cleanup), start fresh. |
| 8 | **Draft PR** | Skip review entirely (same as current behavior). |
| 9 | **Multiple files with many issues** | Group verification by file — read each file once, verify all its issues (open + fixed) in a single agent call. |
| 10 | **No code files changed** | Output "skip" verdict, no state file update needed. |
| 11 | **First push has zero violations** | Create JSON with empty `issues` map, `round: 1`. Post PASSED review. The JSON still exists to track future rounds. |
| 12 | **Issue moves to a different file** | The verification agent marks it as FIXED on the original file. If the same violation exists in the new file, Part B's new-change detection will find it as a new issue. This is acceptable — the issue gets a new ID. |
| 13 | **Merge conflict in JSON file** | This shouldn't happen since only the bot writes to this file. If it does (manual edit), the workflow will fail to checkout and the full-review fallback handles it. |
| 14 | **Very large PR (>50 code files)** | Keep the existing large PR warning. For verification, batch issues by file to avoid token limit issues. For new changes, the pipeline already handles large sets. |
| 15 | **PR closed without merging** | The cleanup workflow checks `github.event.pull_request.merged == true`. If closed without merge, the JSON file stays (can be cleaned manually or on reopen). |

---

### Constraints

- The review pipeline retains the multi-agent architecture (Haiku orchestrator, Sonnet validators, Opus synthesizer) for full reviews and new-change detection
- The `nextjs-react-best-practices` and `backend-best-practices` skills remain the authoritative rules
- SOLID and design-patterns skills still apply as secondary checks
- The GitHub Action must not require developer intervention for state management
- The JSON file must be valid and parseable at all times
- The summary must always contain `<!-- pr-code-review-validator -->` marker for identification
- Inline comments must always contain `<!-- pr-code-review-validator -->` marker
- The `.github/pr/` directory should NOT be gitignored

---

### Walkthrough Examples

#### Example 1: Clean resolution over 3 rounds

**Push 1 (PR opened):**
```
Round 1 — Full review
Current issues: issue-1, issue-2, issue-3, issue-4, issue-5
Fixed: (none)
Status: BLOCKED
```

**Push 2 (developer fixes issues 1-4):**
```
Round 2 — Incremental
Verification: issue-1 FIXED, issue-2 FIXED, issue-3 FIXED, issue-4 FIXED, issue-5 STILL_PRESENT
New changes: none
Fixed: issue-1, issue-2, issue-3, issue-4
Current issues: issue-5
Status: BLOCKED
```

**Push 3 (developer fixes issue 5):**
```
Round 3 — Incremental
Verification: issue-5 FIXED
New changes: none
Fixed: issue-1, issue-2, issue-3, issue-4, issue-5
Current issues: (none)
Status: PASSED — Ready to merge
```

#### Example 2: Fixes introduce new issues

**Push 1:**
```
Round 1 — Current issues: issue-1, issue-2, issue-3
```

**Push 2 (fixes all 3 but introduces new code):**
```
Round 2 — Verification: issue-1 FIXED, issue-2 FIXED, issue-3 FIXED
New changes detected in components/NewWidget.tsx → new violations: issue-4, issue-5
Fixed: issue-1, issue-2, issue-3
Current issues: issue-4, issue-5
Status: BLOCKED
```

**Push 3 (fixes issues 4-5):**
```
Round 3 — Verification: issue-4 FIXED, issue-5 FIXED
Fixed: issue-1, issue-2, issue-3, issue-4, issue-5
Current issues: (none)
Status: PASSED — Ready to merge
```

#### Example 3: Regression after fix

**Push 1:**
```
Round 1 — Current issues: issue-1, issue-2, issue-3
```

**Push 2 (fixes all):**
```
Round 2 — Fixed: issue-1, issue-2, issue-3. Current: (none). PASSED.
```

**Push 3 (developer adds more code, accidentally reintroduces issue-2's pattern):**
```
Round 3 — Regression: issue-2 is STILL_PRESENT again
New changes: issue-4 found in new code
Fixed: issue-1, issue-3
Current issues: issue-2 (regressed), issue-4 (new)
Status: BLOCKED
```

**Push 4 (fixes issue-2 and issue-4):**
```
Round 4 — Verification: issue-2 FIXED, issue-4 FIXED
Fixed: issue-1, issue-2, issue-3, issue-4
Current issues: (none)
Status: PASSED — Ready to merge
```
