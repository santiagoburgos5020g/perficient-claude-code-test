#!/usr/bin/env bash
# run-review-pipeline.sh
# Stateful PR review pipeline with two execution paths:
#   REVIEW_MODE=full        — validate all changed files, create initial state JSON
#   REVIEW_MODE=incremental — verify existing issues (Part A) + detect new violations (Part B)
#
# Full mode:  Haiku orchestrates -> Sonnet validates -> Opus synthesizes -> state JSON created
# Incremental: Sonnet verifies existing issues + existing pipeline for new files -> state JSON updated
#
# Required env vars: ANTHROPIC_BEDROCK_BASE_URL, ANTHROPIC_CUSTOM_HEADERS,
#   CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_SKIP_BEDROCK_AUTH, GH_TOKEN,
#   PR_NUMBER, REPO
# Optional env vars: REVIEW_MODE, HEAD_BRANCH

set -euo pipefail

STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"
CONTEXT_FILE="review-context.json"

# ---------------------------------------------------------------------------
# 1. Large PR detection — warn if >50 code files (full mode only)
# ---------------------------------------------------------------------------
if [[ "${REVIEW_MODE:-full}" == "full" ]]; then
  CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
  CODE_FILE_COUNT=$(echo "$CHANGED_FILES" | grep -cE '\.(ts|tsx|js|jsx|prisma|sql)$' || true)

  if (( CODE_FILE_COUNT > 50 )); then
    echo "::warning::Large PR detected: ${CODE_FILE_COUNT} code files changed"
    gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
      --method POST \
      --field body="<!-- pr-code-review-validator -->
> **Warning:** This PR changes **${CODE_FILE_COUNT}** code files, which is unusually large. The review will still run but may take longer than usual. Consider splitting this PR into smaller, focused changes." \
      2>/dev/null || echo "::warning::Failed to post large PR warning"
  fi
fi

# ============================================================================
# INCREMENTAL MODE
# ============================================================================
if [[ "${REVIEW_MODE:-full}" == "incremental" ]] && [[ -f "$CONTEXT_FILE" ]]; then
  ROUND=$(jq '.round' "$CONTEXT_FILE")
  echo "=== INCREMENTAL REVIEW — Round ${ROUND} ==="

  # Read context
  OPEN_TO_VERIFY=$(jq -c '.open_issues_to_verify' "$CONTEXT_FILE")
  FIXED_TO_CHECK=$(jq -c '.fixed_issues_to_check_regression' "$CONTEXT_FILE")
  DELETED_FILES=$(jq -c '.deleted_files' "$CONTEXT_FILE")
  NEW_FILES=$(jq -c '.new_files_to_validate' "$CONTEXT_FILE")
  STATE_FILE_PATH=$(jq -r '.state_file' "$CONTEXT_FILE")

  OPEN_VERIFY_COUNT=$(echo "$OPEN_TO_VERIFY" | jq 'length')
  FIXED_CHECK_COUNT=$(echo "$FIXED_TO_CHECK" | jq 'length')
  DELETED_COUNT=$(echo "$DELETED_FILES" | jq 'length')
  NEW_FILES_COUNT=$(echo "$NEW_FILES" | jq 'length')

  # Read current state
  STATE_JSON=$(cat "$STATE_FILE_PATH")

  # Tracking arrays for this round
  NEWLY_FIXED_IDS='[]'
  NEWLY_FOUND_IDS='[]'
  REGRESSED_IDS='[]'

  # -----------------------------------------------------------------------
  # Part A.0: Handle deleted files — mark all open issues as fixed
  # -----------------------------------------------------------------------
  if (( DELETED_COUNT > 0 )); then
    echo "Handling ${DELETED_COUNT} deleted file(s)..."
    for del_file in $(echo "$DELETED_FILES" | jq -r '.[]'); do
      # Find open issues on this deleted file
      DEL_ISSUE_IDS=$(echo "$STATE_JSON" | jq -r --arg path "$del_file" '
        .issues | to_entries[] | select(.value.status == "open" and .value.path == $path) | .key
      ')
      for issue_id in $DEL_ISSUE_IDS; do
        echo "  Marking ${issue_id} as fixed (file deleted: ${del_file})"
        STATE_JSON=$(echo "$STATE_JSON" | jq \
          --arg id "$issue_id" \
          --argjson round "$ROUND" \
          '.issues[$id].status = "fixed" | .issues[$id].resolved_in_round = $round')
        NEWLY_FIXED_IDS=$(echo "$NEWLY_FIXED_IDS" | jq --arg id "$issue_id" '. + [$id]')
      done
    done
  fi

  # -----------------------------------------------------------------------
  # Part A.1: Verify open issues on touched files
  # Part A.2: Check regressions on touched files
  # -----------------------------------------------------------------------
  # Combine open + fixed issues by file for a single verification call per file
  ALL_ISSUES_TO_VERIFY=$(jq -n \
    --argjson open "$OPEN_TO_VERIFY" \
    --argjson fixed "$FIXED_TO_CHECK" \
    '$open + $fixed')

  VERIFY_COUNT=$(echo "$ALL_ISSUES_TO_VERIFY" | jq 'length')

  if (( VERIFY_COUNT > 0 )); then
    echo "Verifying ${VERIFY_COUNT} issue(s) across touched files..."

    # Group issues by file path
    FILE_PATHS=$(echo "$ALL_ISSUES_TO_VERIFY" | jq -r '[.[].path] | unique | .[]')

    for file_path in $FILE_PATHS; do
      if [[ ! -f "$file_path" ]]; then
        echo "  Skipping ${file_path} (file no longer exists)"
        continue
      fi

      FILE_CONTENTS=$(cat "$file_path")
      FILE_ISSUES=$(echo "$ALL_ISSUES_TO_VERIFY" | jq -c --arg path "$file_path" '[.[] | select(.path == $path)]')

      echo "  Verifying $(echo "$FILE_ISSUES" | jq 'length') issue(s) on ${file_path}..."

      # Build verification prompt per spec
      VERIFICATION_PROMPT="You are the Issue Verification Agent. You are given a list of previously reported
violations and the current code. For each violation, determine if it has been FIXED
or is STILL_PRESENT.

FILE: ${file_path}
CURRENT FILE CONTENTS:
${FILE_CONTENTS}

VIOLATIONS TO VERIFY:
${FILE_ISSUES}

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
    \"id\": \"issue-1\",
    \"status\": \"FIXED\" | \"STILL_PRESENT\",
    \"explanation\": \"Brief explanation of why (1-2 sentences)\"
  }
]"

      # Invoke Sonnet verification agent
      VERIFY_RAW=$(echo "$VERIFICATION_PROMPT" | timeout 120 claude --print --model sonnet --output-format json 2>/dev/null) || {
        echo "::warning::Verification failed for ${file_path} — treating all issues as STILL_PRESENT"
        continue
      }

      # Extract JSON from CLI output (same strategies as full pipeline)
      VERIFY_RESULT=""

      # Strategy 1: Direct JSON array
      if echo "$VERIFY_RAW" | jq -e '.[0].id' >/dev/null 2>&1; then
        VERIFY_RESULT="$VERIFY_RAW"
      fi

      # Strategy 2: CLI envelope with .result
      if [[ -z "$VERIFY_RESULT" ]]; then
        RESULT_TEXT=$(echo "$VERIFY_RAW" | jq -r '.result // empty' 2>/dev/null)
        if [[ -n "$RESULT_TEXT" ]] && echo "$RESULT_TEXT" | jq -e '.[0].id' >/dev/null 2>&1; then
          VERIFY_RESULT="$RESULT_TEXT"
        fi
      fi

      # Strategy 3: Content blocks
      if [[ -z "$VERIFY_RESULT" ]]; then
        CONTENT_TEXT=$(echo "$VERIFY_RAW" | jq -r '
          if (.result | type) == "array" then
            [.result[] | .text // empty] | join("")
          elif (.content | type) == "array" then
            [.content[] | .text // empty] | join("")
          else
            empty
          end
        ' 2>/dev/null)
        if [[ -n "$CONTENT_TEXT" ]] && echo "$CONTENT_TEXT" | jq -e '.[0].id' >/dev/null 2>&1; then
          VERIFY_RESULT="$CONTENT_TEXT"
        fi
      fi

      if [[ -z "$VERIFY_RESULT" ]]; then
        echo "::warning::Could not parse verification output for ${file_path} — treating as STILL_PRESENT"
        continue
      fi

      # Process each verification result
      for row in $(echo "$VERIFY_RESULT" | jq -c '.[]'); do
        ISSUE_ID=$(echo "$row" | jq -r '.id')
        ISSUE_STATUS=$(echo "$row" | jq -r '.status')
        EXPLANATION=$(echo "$row" | jq -r '.explanation')

        # Get current status of this issue in state
        CURRENT_STATUS=$(echo "$STATE_JSON" | jq -r --arg id "$ISSUE_ID" '.issues[$id].status // empty')

        if [[ "$CURRENT_STATUS" == "open" ]] && [[ "$ISSUE_STATUS" == "FIXED" ]]; then
          echo "    ${ISSUE_ID}: FIXED — ${EXPLANATION}"
          STATE_JSON=$(echo "$STATE_JSON" | jq \
            --arg id "$ISSUE_ID" \
            --argjson round "$ROUND" \
            '.issues[$id].status = "fixed" | .issues[$id].resolved_in_round = $round')
          NEWLY_FIXED_IDS=$(echo "$NEWLY_FIXED_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')

        elif [[ "$CURRENT_STATUS" == "open" ]] && [[ "$ISSUE_STATUS" == "STILL_PRESENT" ]]; then
          echo "    ${ISSUE_ID}: STILL_PRESENT — ${EXPLANATION}"

        elif [[ "$CURRENT_STATUS" == "fixed" ]] && [[ "$ISSUE_STATUS" == "STILL_PRESENT" ]]; then
          echo "    ${ISSUE_ID}: REGRESSION — ${EXPLANATION}"
          STATE_JSON=$(echo "$STATE_JSON" | jq \
            --arg id "$ISSUE_ID" \
            '.issues[$id].status = "open" | .issues[$id].resolved_in_round = null')
          REGRESSED_IDS=$(echo "$REGRESSED_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')

        elif [[ "$CURRENT_STATUS" == "fixed" ]] && [[ "$ISSUE_STATUS" == "FIXED" ]]; then
          echo "    ${ISSUE_ID}: still fixed"
        fi
      done
    done
  else
    echo "No issues to verify on touched files."
  fi

  # -----------------------------------------------------------------------
  # Part B: Validate new files (if any)
  # -----------------------------------------------------------------------
  if (( NEW_FILES_COUNT > 0 )); then
    echo ""
    echo "=== Part B: Validating ${NEW_FILES_COUNT} new file(s) ==="

    # Build a scoped pipeline prompt for new files only
    NEW_FILES_LIST=$(echo "$NEW_FILES" | jq -r 'join(", ")')

    cat > pipeline-prompt-partb.txt <<PARTB_PROMPT
You are the PR Code Review Validator orchestrator. You will execute a 3-stage
pipeline to review ONLY the following new/changed files against the project's
skill rules. You MUST output ONLY a single JSON object as your final response.
No markdown, no explanation, no preamble — just the JSON.

FILES TO REVIEW (only these files):
${NEW_FILES_LIST}

================================================================================
STAGE 1: CLASSIFICATION (you execute this directly)
================================================================================

Step 1.1: The files to review are listed above. Do NOT run git diff.
Read each file listed above.

Step 1.2: Filter non-code files.
Remove any file matching these patterns:
- package.json, package-lock.json, yarn.lock, pnpm-lock.yaml
- .gitignore, .env, .env.*
- .eslintrc*, tsconfig.json, next.config.js, next.config.mjs
- tailwind.config.*, prettier.config.*, postcss.config.*
- jest.config.*, jest.setup.*
- *.png, *.jpg, *.jpeg, *.gif, *.svg, *.ico, *.webp
- *.woff, *.woff2, *.ttf, *.eot
- *.md, *.mdx, *.txt
- *.json (EXCEPT files inside pages/api/)
- *.css, *.scss (EXCEPT Tailwind utility files)
- Any file inside: node_modules/, .next/, .git/, dist/, build/, coverage/,
  .claude/, .github/, .husky/, spec/, examples/, templates-example/,
  chrome-dev-tools/, public/, scripts/

Keep only files with extensions: .ts, .tsx, .js, .jsx, .prisma, .sql

Step 1.3: If ZERO code files remain after filtering, output this exact JSON and STOP:
{
  "verdict": "skip",
  "summary": "no new code files to validate",
  "inline_comments": [],
  "stats": {"files_checked": 0, "violations_found": 0}
}

Step 1.4: Classify each remaining code file.

FRONTEND paths (apply nextjs-react-best-practices):
- pages/ (EXCLUDING pages/api/)
- components/
- containers/
- hooks/
- styles/
- features/**/components/
- features/**/hooks/

BACKEND paths (apply backend-best-practices):
- pages/api/
- lib/
- services/
- prisma/
- Any .prisma or .sql file regardless of location
- Root-level .ts/.tsx files (e.g., middleware.ts)

AMBIGUOUS paths (classify by who imports them):
- types/ or features/**/types/
- utils/ or features/**/utils/
For these, use grep to check what imports them.
- If only frontend paths import it -> frontend
- If only backend paths import it -> backend
- If both import it -> classify as BOTH (both skills apply)
- If no importers found -> classify based on file contents

TEST FILES (*.test.ts, *.test.tsx, *.spec.ts, *.spec.tsx, files in __tests__/):
  Inherit classification from the source file they test.

Step 1.5: Build the classification result.

================================================================================
STAGE 2: VALIDATION (spawn Sonnet sub-agents via the Agent tool)
================================================================================

Based on the classification from Stage 1, spawn validation agents.

IF has_frontend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt (replace <FRONTEND_FILES> and <NEW_FRONTEND_FILES>
with the actual file lists from Stage 1):

---BEGIN FRONTEND AGENT PROMPT---
You are the Frontend Validation Agent. Validate the listed files against
the project's frontend skill rules.

FILES TO VALIDATE:
<FRONTEND_FILES>

NEW FILES (additionally check folder placement, naming, internal structure):
<NEW_FRONTEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 13 frontend categories:
   - Cat 1: Container-Presentational Component Pattern
   - Cat 2: Folder Structure
   - Cat 3: Naming Conventions
   - Cat 4: Component File Internal Structure
   - Cat 5: TypeScript Strictness
   - Cat 6: React 18 Hooks Best Practices
   - Cat 7: useSWR Best Practices
   - Cat 8: Error Handling
   - Cat 9: Testing Patterns
   - Cat 10: Tailwind CSS Conventions
   - Cat 11: Pages Router Data Fetching Strategy
   - Cat 12: Performance Optimization
   - Cat 13: Accessibility (a11y)

4. Also evaluate SOLID principles in frontend context.

5. Also evaluate design patterns in frontend context — only flag patterns that
   are genuinely misused or clearly needed but missing.

6. For NEW FILES, additionally check:
   - Cat 2: Is the file in the correct directory?
   - Cat 3: Does the filename follow conventions?
   - Cat 4: Does the internal structure follow the expected order?

7. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "nextjs-react-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Cat 5: TypeScript Strictness" | "SRP" | "Strategy" | etc.,
  "scope": "frontend",
  "path": "relative/path/to/file.tsx",
  "line": 15,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
Do NOT include Informational-severity findings.
---END FRONTEND AGENT PROMPT---

IF has_backend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt:

---BEGIN BACKEND AGENT PROMPT---
You are the Backend Validation Agent. Validate the listed files against
the project's backend skill rules.

FILES TO VALIDATE:
<BACKEND_FILES>

NEW FILES (additionally check folder placement and naming):
<NEW_BACKEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 10 core backend rules:
   - Rule 1: Standard API Response Envelope
   - Rule 2: RESTful API Design
   - Rule 3: Pagination Standard
   - Rule 4: Input Validation with Zod
   - Rule 5: Centralized Error Handling
   - Rule 6: Security
   - Rule 7: Database Optimization (Prisma)
   - Rule 8: Testing API Routes
   - Rule 9: Naming Conventions
   - Rule 10: Environment Variables & Configuration

4. Also evaluate SOLID principles in backend context.

5. Also evaluate design patterns in backend context.

6. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "backend-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Rule 6: Security" | "SRP" | "Factory Method" | etc.,
  "scope": "backend",
  "path": "relative/path/to/file.ts",
  "line": 22,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
---END BACKEND AGENT PROMPT---

IMPORTANT: If has_frontend AND has_backend are BOTH true, spawn BOTH agents
in parallel. After ALL sub-agents complete, combine their output arrays into
a single array called all_violations.

IF all_violations is empty, output:
{
  "verdict": "pass",
  "summary": "no new violations found",
  "inline_comments": [],
  "stats": {"files_checked": <N>, "violations_found": 0, "false_positives_filtered": 0}
}

================================================================================
STAGE 3: REVIEW SYNTHESIS (spawn Opus sub-agent — ONLY if violations found)
================================================================================

IF all_violations is NOT empty, use the Agent tool to spawn a sub-agent with
model "opus" and the following prompt:

---BEGIN SYNTHESIS AGENT PROMPT---
You are the Review Synthesis Agent. You receive potential violations found by
validation agents. Your job is to filter false positives, add architectural
context, resolve conflicting rules, and produce the final curated review.

POTENTIAL VIOLATIONS:
<ALL_VIOLATIONS_JSON>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file referenced in the violations list using the Read tool.

3. For EACH potential violation, determine:
   a. TRUE VIOLATION — the code genuinely violates the rule
   b. FALSE POSITIVE — correct when broader context is considered

4. For TRUE violations, write an inline comment body in this exact format:
   **<skill-name> > <rule>**

   <Explanation of WHY the code violates the rule>

   **Suggestion:** <Specific, actionable fix>

   <!-- pr-code-review-validator -->

5. Output ONLY a JSON object:
{
  "confirmed_violations": [
    {
      "skill": "...",
      "rule": "...",
      "scope": "...",
      "path": "...",
      "line": N,
      "description": "...",
      "suggestion": "...",
      "severity": "...",
      "body": "**skill > rule**\n\n...\n\n<!-- pr-code-review-validator -->"
    }
  ],
  "false_positives": [
    {
      "skill": "...",
      "rule": "...",
      "path": "...",
      "line": N,
      "reason": "..."
    }
  ]
}
---END SYNTHESIS AGENT PROMPT---

After the Opus agent returns, output:
{
  "verdict": "pass" or "fail",
  "confirmed_violations": [...],
  "false_positives": [...],
  "stats": {"files_checked": N, "violations_found": N, "false_positives_filtered": N}
}

================================================================================
CRITICAL OUTPUT REQUIREMENTS
================================================================================
- Your FINAL output must be ONLY the JSON object. No markdown, no code fences.
- The JSON must be parseable by jq.
- "verdict" must be exactly one of: "pass", "fail", "skip"
- Every confirmed violation body MUST contain <!-- pr-code-review-validator -->
- Replace ALL <PLACEHOLDERS> with actual computed values

Now execute Stage 1. Begin by reading the files listed above.
PARTB_PROMPT

    echo "Running Part B pipeline for new files..."
    timeout 540 claude --print --model haiku --output-format json < pipeline-prompt-partb.txt > partb-output-raw.json || {
      echo "::warning::Part B pipeline failed"
      echo '{"verdict":"skip","confirmed_violations":[],"false_positives":[],"stats":{"files_checked":0,"violations_found":0}}' > partb-output.json
    }

    # Extract Part B output (same strategies as full pipeline)
    PARTB_EXTRACTED=false

    if jq -e '.verdict' partb-output-raw.json >/dev/null 2>&1; then
      cp partb-output-raw.json partb-output.json
      PARTB_EXTRACTED=true
    fi

    if [ "$PARTB_EXTRACTED" = false ]; then
      RESULT_TEXT=$(jq -r '.result // empty' partb-output-raw.json 2>/dev/null)
      if [ -n "$RESULT_TEXT" ] && echo "$RESULT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
        echo "$RESULT_TEXT" | jq '.' > partb-output.json
        PARTB_EXTRACTED=true
      fi
    fi

    if [ "$PARTB_EXTRACTED" = false ]; then
      CONTENT_TEXT=$(jq -r '
        if (.result | type) == "array" then
          [.result[] | .text // empty] | join("")
        elif (.content | type) == "array" then
          [.content[] | .text // empty] | join("")
        else
          empty
        end
      ' partb-output-raw.json 2>/dev/null)
      if [ -n "$CONTENT_TEXT" ] && echo "$CONTENT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
        echo "$CONTENT_TEXT" | jq '.' > partb-output.json
        PARTB_EXTRACTED=true
      fi
    fi

    if [ "$PARTB_EXTRACTED" = false ]; then
      echo "::warning::Could not extract Part B output — treating as no new violations"
      echo '{"verdict":"skip","confirmed_violations":[],"false_positives":[],"stats":{"files_checked":0,"violations_found":0}}' > partb-output.json
    fi

    # Add new violations to state
    NEXT_ID=$(echo "$STATE_JSON" | jq '.next_issue_id')
    NEW_VIOLATIONS=$(jq -c '.confirmed_violations // .inline_comments // []' partb-output.json)
    NEW_VIOLATION_COUNT=$(echo "$NEW_VIOLATIONS" | jq 'length')

    if (( NEW_VIOLATION_COUNT > 0 )); then
      echo "Part B found ${NEW_VIOLATION_COUNT} new violation(s)"
      for row in $(echo "$NEW_VIOLATIONS" | jq -c '.[]'); do
        ISSUE_ID="issue-${NEXT_ID}"
        SKILL=$(echo "$row" | jq -r '.skill // "unknown"')
        RULE=$(echo "$row" | jq -r '.rule // "unknown"')
        SCOPE=$(echo "$row" | jq -r '.scope // "frontend"')
        FPATH=$(echo "$row" | jq -r '.path')
        LINE=$(echo "$row" | jq '.line // 1')
        DESC=$(echo "$row" | jq -r '.description // ""')
        SUGGESTION=$(echo "$row" | jq -r '.suggestion // ""')
        SEVERITY=$(echo "$row" | jq -r '.severity // "Critical"')
        BODY=$(echo "$row" | jq -r '.body // ""')

        STATE_JSON=$(echo "$STATE_JSON" | jq \
          --arg id "$ISSUE_ID" \
          --arg skill "$SKILL" \
          --arg rule "$RULE" \
          --arg scope "$SCOPE" \
          --arg path "$FPATH" \
          --argjson line "$LINE" \
          --arg desc "$DESC" \
          --arg suggestion "$SUGGESTION" \
          --arg severity "$SEVERITY" \
          --arg body "$BODY" \
          --argjson round "$ROUND" \
          '.issues[$id] = {
            skill: $skill,
            rule: $rule,
            scope: $scope,
            path: $path,
            line: $line,
            description: $desc,
            suggestion: $suggestion,
            severity: $severity,
            status: "open",
            found_in_round: $round,
            resolved_in_round: null,
            inline_comment_body: $body
          }')
        NEWLY_FOUND_IDS=$(echo "$NEWLY_FOUND_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')
        NEXT_ID=$((NEXT_ID + 1))
      done

      STATE_JSON=$(echo "$STATE_JSON" | jq --argjson next "$NEXT_ID" '.next_issue_id = $next')
    else
      echo "Part B: no new violations found"
    fi

    rm -f pipeline-prompt-partb.txt partb-output-raw.json
  else
    echo "No new files to validate — skipping Part B"
  fi

  # -----------------------------------------------------------------------
  # Merge results: update state JSON with new round
  # -----------------------------------------------------------------------
  echo ""
  echo "=== Updating state with Round ${ROUND} results ==="

  COMMIT_SHA=$(git rev-parse HEAD)
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Get list of files checked this round
  FILES_CHECKED=$(jq -c '.touched_files + .new_files_to_validate + .deleted_files | unique' "$CONTEXT_FILE")

  # Append new review round
  STATE_JSON=$(echo "$STATE_JSON" | jq \
    --argjson round "$ROUND" \
    --arg sha "$COMMIT_SHA" \
    --arg ts "$TIMESTAMP" \
    --argjson files_checked "$FILES_CHECKED" \
    --argjson fixed "$NEWLY_FIXED_IDS" \
    --argjson found "$NEWLY_FOUND_IDS" \
    --argjson regressed "$REGRESSED_IDS" \
    '.reviews += [{
      round: $round,
      commit_sha: $sha,
      timestamp: $ts,
      type: "incremental",
      files_checked: $files_checked,
      newly_fixed_ids: $fixed,
      newly_found_ids: $found,
      regressed_ids: $regressed
    }] | .last_updated = $ts')

  # Write updated state
  mkdir -p .github/pr
  echo "$STATE_JSON" | jq '.' > "$STATE_FILE_PATH"

  # -----------------------------------------------------------------------
  # Build pipeline-output.json with cumulative summary
  # -----------------------------------------------------------------------
  ALL_OPEN=$(echo "$STATE_JSON" | jq '[.issues | to_entries[] | select(.value.status == "open") | .value + {id: .key}]')
  ALL_FIXED=$(echo "$STATE_JSON" | jq '[.issues | to_entries[] | select(.value.status == "fixed") | .value + {id: .key}]')

  OPEN_TOTAL=$(echo "$ALL_OPEN" | jq 'length')
  FIXED_TOTAL=$(echo "$ALL_FIXED" | jq 'length')
  NEWLY_FIXED_COUNT=$(echo "$NEWLY_FIXED_IDS" | jq 'length')
  NEWLY_FOUND_COUNT=$(echo "$NEWLY_FOUND_IDS" | jq 'length')
  REGRESSED_COUNT=$(echo "$REGRESSED_IDS" | jq 'length')
  FILES_CHECKED_COUNT=$(echo "$FILES_CHECKED" | jq 'length')

  # Determine verdict
  if (( OPEN_TOTAL == 0 )); then
    VERDICT="pass"
    STATUS_TEXT="**PASSED — Ready to merge**"
  else
    VERDICT="fail"
    STATUS_TEXT="**BLOCKED**"
  fi

  # Build fixed list
  FIXED_LIST=""
  if (( FIXED_TOTAL > 0 )); then
    FIXED_LIST=$(echo "$ALL_FIXED" | jq -r '.[] | "- [x] ~~**\(.skill) > \(.rule)** — `\(.path):\(.line)` — \(.description)~~ *(fixed in round \(.resolved_in_round))*"')
  fi

  # Build regressions list
  REGRESSED_LIST=""
  if (( REGRESSED_COUNT > 0 )); then
    REGRESSED_LIST=$(echo "$ALL_OPEN" | jq -r --argjson ids "$REGRESSED_IDS" '
      [.[] | select(.id as $id | $ids | index($id) != null)] |
      .[] | "- [ ] **\(.skill) > \(.rule)** — `\(.path):\(.line)` — \(.description) *(regressed in round \(.found_in_round))*"
    ')
  fi

  # Build current issues list
  CURRENT_LIST=""
  if (( OPEN_TOTAL > 0 )); then
    CURRENT_LIST=$(echo "$ALL_OPEN" | jq -r '.[] | "- [ ] **\(.skill) > \(.rule)** — `\(.path):\(.line)` — \(.description) *(since round \(.found_in_round))*"')
  fi

  # Assemble summary
  SUMMARY="<!-- pr-code-review-validator -->
## PR Review — Round ${ROUND}

| Metric | Value |
|--------|-------|
| Review round | ${ROUND} |
| Review type | Incremental |
| Files checked | ${FILES_CHECKED_COUNT} |
| Current issues | ${OPEN_TOTAL} |
| Fixed (this round) | ${NEWLY_FIXED_COUNT} |
| Fixed (cumulative) | ${FIXED_TOTAL} |
| Regressions | ${REGRESSED_COUNT} |
| Status | ${STATUS_TEXT} |"

  if (( FIXED_TOTAL > 0 )); then
    SUMMARY="${SUMMARY}

### List of Changes Fixed

${FIXED_LIST}"
  fi

  if (( REGRESSED_COUNT > 0 )); then
    SUMMARY="${SUMMARY}

### Regressions

${REGRESSED_LIST}"
  fi

  if (( OPEN_TOTAL > 0 )); then
    SUMMARY="${SUMMARY}

### Current Issues

${CURRENT_LIST}"
  fi

  if (( OPEN_TOTAL == 0 )); then
    SUMMARY="${SUMMARY}

All issues resolved. This PR is ready to merge."
  fi

  SUMMARY="${SUMMARY}

---
*This review was generated by the PR Code Review Validator (stateful mode).*
*Review state: \`.github/pr/pr-${PR_NUMBER}.json\`*"

  # Build inline_comments for currently open issues only
  INLINE_COMMENTS=$(echo "$ALL_OPEN" | jq '[.[] | {
    path: .path,
    line: .line,
    side: "RIGHT",
    body: .inline_comment_body
  }] | [.[] | select(.body != null and .body != "")]')

  # Write pipeline-output.json
  jq -n \
    --arg verdict "$VERDICT" \
    --arg summary "$SUMMARY" \
    --argjson inline_comments "$INLINE_COMMENTS" \
    --argjson open "$OPEN_TOTAL" \
    --argjson fixed "$FIXED_TOTAL" \
    --argjson newly_fixed "$NEWLY_FIXED_COUNT" \
    --argjson newly_found "$NEWLY_FOUND_COUNT" \
    --argjson regressed "$REGRESSED_COUNT" \
    --argjson files_checked "$FILES_CHECKED_COUNT" \
    '{
      verdict: $verdict,
      summary: $summary,
      inline_comments: $inline_comments,
      stats: {
        files_checked: $files_checked,
        current_issues: $open,
        fixed_cumulative: $fixed,
        newly_fixed: $newly_fixed,
        newly_found: $newly_found,
        regressions: $regressed
      }
    }' > pipeline-output.json

  echo ""
  echo "=============================="
  echo "  Round ${ROUND} Results"
  echo "=============================="
  echo "  Verdict:          ${VERDICT}"
  echo "  Current issues:   ${OPEN_TOTAL}"
  echo "  Fixed this round: ${NEWLY_FIXED_COUNT}"
  echo "  Fixed cumulative: ${FIXED_TOTAL}"
  echo "  New violations:   ${NEWLY_FOUND_COUNT}"
  echo "  Regressions:      ${REGRESSED_COUNT}"
  echo "=============================="

  exit 0
fi

# ============================================================================
# FULL MODE
# ============================================================================
echo "=== FULL REVIEW — Round 1 ==="
echo "Starting review pipeline..."

# ---------------------------------------------------------------------------
# Build pipeline prompt (same as original Stage 1-3 prompt)
# ---------------------------------------------------------------------------
cat > pipeline-prompt.txt <<'PIPELINE_PROMPT'
You are the PR Code Review Validator orchestrator. You will execute a 3-stage
pipeline to review code changes in this pull request against the project's
skill rules. You MUST output ONLY a single JSON object as your final response.
No markdown, no explanation, no preamble — just the JSON.

================================================================================
STAGE 1: CLASSIFICATION (you execute this directly)
================================================================================

Step 1.1: Get changed files.
Run this command via the Bash tool:
  git diff --name-only origin/main...HEAD

Step 1.2: Get newly added files.
Run this command via the Bash tool:
  git diff --diff-filter=A --name-only origin/main...HEAD

Step 1.3: Filter non-code files.
Remove any file matching these patterns:
- package.json, package-lock.json, yarn.lock, pnpm-lock.yaml
- .gitignore, .env, .env.*
- .eslintrc*, tsconfig.json, next.config.js, next.config.mjs
- tailwind.config.*, prettier.config.*, postcss.config.*
- jest.config.*, jest.setup.*
- *.png, *.jpg, *.jpeg, *.gif, *.svg, *.ico, *.webp
- *.woff, *.woff2, *.ttf, *.eot
- *.md, *.mdx, *.txt
- *.json (EXCEPT files inside pages/api/)
- *.css, *.scss (EXCEPT Tailwind utility files)
- Any file inside: node_modules/, .next/, .git/, dist/, build/, coverage/,
  .claude/, .github/, .husky/, spec/, examples/, templates-example/,
  chrome-dev-tools/, public/, scripts/

Keep only files with extensions: .ts, .tsx, .js, .jsx, .prisma, .sql

Step 1.4: If ZERO code files remain after filtering, output this exact JSON and STOP:
{
  "verdict": "skip",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW SKIPPED — no code files changed\n\nOnly non-code files were modified in this PR. No skill-based review needed.\nStatus: **PASSED**\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "stats": {
    "files_checked": 0,
    "files_changed": 0,
    "files_related": 0,
    "skills_applied": [],
    "violations_found": 0,
    "false_positives_filtered": 0
  }
}

Step 1.5: Classify each remaining code file.

FRONTEND paths (apply nextjs-react-best-practices):
- pages/ (EXCLUDING pages/api/)
- components/
- containers/
- hooks/
- styles/
- features/**/components/
- features/**/hooks/

BACKEND paths (apply backend-best-practices):
- pages/api/
- lib/
- services/
- prisma/
- Any .prisma or .sql file regardless of location
- Root-level .ts/.tsx files (e.g., middleware.ts)

AMBIGUOUS paths (classify by who imports them):
- types/ or features/**/types/
- utils/ or features/**/utils/
For these, use grep to check what imports them:
  grep -rl "from.*['\"]\.\./types/<filename>" --include="*.ts" --include="*.tsx" .
  grep -rl "from.*['\"]\.\./utils/<filename>" --include="*.ts" --include="*.tsx" .
- If only frontend paths import it -> frontend
- If only backend paths import it -> backend
- If both import it -> classify as BOTH (both skills apply)
- If no importers found -> classify based on file contents (React imports = frontend, otherwise backend)

TEST FILES (*.test.ts, *.test.tsx, *.spec.ts, *.spec.tsx, files in __tests__/):
  Inherit classification from the source file they test. For example:
  - features/products/components/Card.test.tsx -> frontend (tests Card.tsx in components/)
  - pages/api/products.test.ts -> backend (tests the API route)

Step 1.6: Trace related files (ONE level deep only).
For each changed code file, find files that import it and files it imports:
  a. Read the file to extract its import paths
  b. Run: grep -rl "from.*['\"].*<module-name>['\"]" --include="*.ts" --include="*.tsx" .
  c. Add discovered files to scope with their own classification
  d. Do NOT trace further — one level only

Step 1.7: Build the classification result:
  - frontend_files: array of file paths classified as frontend
  - backend_files: array of file paths classified as backend
  - new_files: array of newly added file paths
  - has_frontend: boolean
  - has_backend: boolean
  - total_changed: count of changed code files
  - total_related: count of related files discovered

================================================================================
STAGE 2: VALIDATION (spawn Sonnet sub-agents via the Agent tool)
================================================================================

Based on the classification from Stage 1, spawn validation agents.

IF has_frontend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt (replace <FRONTEND_FILES> and <NEW_FRONTEND_FILES>
with the actual file lists from Stage 1):

---BEGIN FRONTEND AGENT PROMPT---
You are the Frontend Validation Agent. Validate the listed files against
the project's frontend skill rules.

FILES TO VALIDATE:
<FRONTEND_FILES>

NEW FILES (additionally check folder placement, naming, internal structure):
<NEW_FRONTEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 13 frontend categories:
   - Cat 1: Container-Presentational Component Pattern
   - Cat 2: Folder Structure
   - Cat 3: Naming Conventions
   - Cat 4: Component File Internal Structure
   - Cat 5: TypeScript Strictness
   - Cat 6: React 18 Hooks Best Practices
   - Cat 7: useSWR Best Practices
   - Cat 8: Error Handling
   - Cat 9: Testing Patterns
   - Cat 10: Tailwind CSS Conventions
   - Cat 11: Pages Router Data Fetching Strategy
   - Cat 12: Performance Optimization
   - Cat 13: Accessibility (a11y)

4. Also evaluate SOLID principles in frontend context (SRP, OCP, LSP, ISP, DIP
   as they map to frontend categories 3.11-3.23 in the SOLID skill).

5. Also evaluate design patterns in frontend context — only flag patterns that
   are genuinely misused or clearly needed but missing. Never flag absence of
   a pattern in simple code.

6. For NEW FILES, additionally check:
   - Cat 2: Is the file in the correct directory?
   - Cat 3: Does the filename follow conventions?
   - Cat 4: Does the internal structure follow the expected order?
   If a file is in the wrong directory, explain where it should be placed.

7. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "nextjs-react-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Cat 5: TypeScript Strictness" | "SRP" | "Strategy" | etc.,
  "scope": "frontend",
  "path": "relative/path/to/file.tsx",
  "line": 15,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
Do NOT include Informational-severity findings.
Do NOT flag patterns in trivially simple code.
---END FRONTEND AGENT PROMPT---

IF has_backend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt (replace <BACKEND_FILES> and <NEW_BACKEND_FILES>
with the actual file lists from Stage 1):

---BEGIN BACKEND AGENT PROMPT---
You are the Backend Validation Agent. Validate the listed files against
the project's backend skill rules.

FILES TO VALIDATE:
<BACKEND_FILES>

NEW FILES (additionally check folder placement and naming):
<NEW_BACKEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 10 core backend rules:
   - Rule 1: Standard API Response Envelope
   - Rule 2: RESTful API Design
   - Rule 3: Pagination Standard
   - Rule 4: Input Validation with Zod
   - Rule 5: Centralized Error Handling
   - Rule 6: Security
   - Rule 7: Database Optimization (Prisma)
   - Rule 8: Testing API Routes
   - Rule 9: Naming Conventions
   - Rule 10: Environment Variables & Configuration

4. Also evaluate SOLID principles in backend context:
   Priority order: SRP > ISP > DIP > OCP > LSP

5. Also evaluate design patterns in backend context — only flag patterns that
   are genuinely misused or clearly needed but missing. Never flag absence of
   a pattern in simple code.

6. For NEW FILES, additionally check:
   - Is the file in the correct directory per project conventions?
   - Rule 9: Does the filename follow naming conventions?

7. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "backend-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Rule 6: Security" | "SRP" | "Factory Method" | etc.,
  "scope": "backend",
  "path": "relative/path/to/file.ts",
  "line": 22,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
Do NOT include Informational-severity findings.
Do NOT flag patterns in trivially simple code.
---END BACKEND AGENT PROMPT---

IMPORTANT: If has_frontend AND has_backend are BOTH true, spawn BOTH agents
in parallel (in the same message with two Agent tool calls).

After ALL sub-agents complete, combine their output arrays into a single
array called all_violations.

IF all_violations is empty (zero violations from all agents), build and output
the following JSON as your FINAL output and STOP:
{
  "verdict": "pass",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — PASSED (clean)\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <TOTAL_CHANGED + TOTAL_RELATED> (<TOTAL_CHANGED> changed, <TOTAL_RELATED> related) |\n| Skills applied | <COMMA_SEPARATED_SKILLS_LIST> |\n| Violations found | 0 |\n| Status | **PASSED** |\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "stats": {
    "files_checked": <TOTAL>,
    "files_changed": <TOTAL_CHANGED>,
    "files_related": <TOTAL_RELATED>,
    "skills_applied": [<SKILLS_ARRAY>],
    "violations_found": 0,
    "false_positives_filtered": 0
  }
}

Replace all <PLACEHOLDERS> with actual computed values. The skills_applied
array should list which skills were actually evaluated (e.g.,
["nextjs-react-best-practices", "design-patterns (frontend-scoped)", "SOLID (frontend-scoped)"]).

================================================================================
STAGE 3: REVIEW SYNTHESIS (spawn Opus sub-agent — ONLY if violations found)
================================================================================

IF all_violations is NOT empty, use the Agent tool to spawn a sub-agent with
model "opus" and the following prompt (replace <ALL_VIOLATIONS_JSON> with the
actual JSON array):

---BEGIN SYNTHESIS AGENT PROMPT---
You are the Review Synthesis Agent. You receive potential violations found by
validation agents. Your job is to filter false positives, add architectural
context, resolve conflicting rules, and produce the final curated review.

POTENTIAL VIOLATIONS:
<ALL_VIOLATIONS_JSON>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file referenced in the violations list using the Read tool.
   Read the FULL file, not just the flagged line — you need complete context.

3. For EACH potential violation, determine:
   a. TRUE VIOLATION — the code genuinely violates the rule when full context
      is considered. The rule clearly applies and the code is wrong.
   b. FALSE POSITIVE — the code appears to violate the rule in isolation but
      is actually correct when broader context is considered. Examples:
      - A "missing Zod validation" finding when upstream middleware already validates
      - A "missing error handling" when the framework handles it
      - A pattern absence in code too simple to warrant the pattern

4. For TRUE violations, write an inline comment body in this exact format:
   **<skill-name> > <rule>**

   <Explanation of WHY the code violates the rule — not just THAT it does.
   Include the architectural context and what impact the violation has.>

   **Suggestion:** <Specific, actionable fix with enough detail to implement>

   <!-- pr-code-review-validator -->

5. For FALSE positives, record:
   - The original skill/rule/path/line
   - A clear explanation of why it is NOT a violation in context

6. Resolve conflicting rules:
   - If two skills disagree (e.g., splitting a class for SRP would break the
     API response envelope pattern), make the judgment call
   - Explain the trade-off in the inline comment
   - Prefer: Security > Data Integrity > Correctness > Maintainability

7. Output ONLY a JSON object with this exact structure:
{
  "confirmed_violations": [
    {
      "skill": "backend-best-practices",
      "rule": "Rule 6: Security",
      "scope": "backend",
      "path": "pages/api/products.ts",
      "line": 15,
      "description": "Clear description of the violation",
      "suggestion": "Specific fix suggestion",
      "severity": "Critical",
      "body": "**backend-best-practices > Rule 6: Security**\n\n<full explanation>\n\n**Suggestion:** <fix>\n\n<!-- pr-code-review-validator -->"
    }
  ],
  "false_positives": [
    {
      "skill": "backend-best-practices",
      "rule": "Rule 4: Zod Validation",
      "path": "pages/api/products.ts",
      "line": 10,
      "reason": "Input is validated by upstream middleware in lib/middleware.ts:25"
    }
  ]
}
---END SYNTHESIS AGENT PROMPT---

After the Opus agent returns, use its output to build the FINAL JSON.

Count: confirmed_count = length of confirmed_violations
Count: filtered_count = length of false_positives

IF confirmed_count == 0 (all were false positives), output:
{
  "verdict": "pass",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — PASSED (after review)\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <N> (<CHANGED> changed, <RELATED> related) |\n| Skills applied | <LIST> |\n| Initial findings | <TOTAL_INITIAL> |\n| False positives filtered | <FILTERED_COUNT> |\n| Violations confirmed | 0 |\n| Status | **PASSED** |\n\n### Filtered findings (informational)\n<For each false positive: - ~<rule> — `<path>:<line>`~ — <reason>>\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "confirmed_violations": [],
  "false_positives": [<FROM_OPUS>],
  "stats": {
    "files_checked": <N>,
    "files_changed": <CHANGED>,
    "files_related": <RELATED>,
    "skills_applied": [<SKILLS>],
    "violations_found": 0,
    "false_positives_filtered": <FILTERED_COUNT>
  }
}

IF confirmed_count > 0, output:
{
  "verdict": "fail",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — VIOLATIONS FOUND\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <N> (<CHANGED> changed, <RELATED> related) |\n| Skills applied | <LIST> |\n| Violations found | <CONFIRMED_COUNT> |\n| False positives filtered | <FILTERED_COUNT> |\n| Status | **BLOCKED** |\n\n<For each skill that has violations, create a ### heading with the skill name, then list violations as:\n- [ ] **<rule>** — `<path>:<line>` — <short description>\n>\n\n---\n*This review was generated by the PR Code Review Validator. All violations must be resolved before merging.*",
  "inline_comments": [
    <For each confirmed violation:
    {
      "path": "<path>",
      "line": <line>,
      "side": "RIGHT",
      "body": "<the body field from confirmed_violations>"
    }
    >
  ],
  "confirmed_violations": [<FROM_OPUS>],
  "false_positives": [<FROM_OPUS>],
  "stats": {
    "files_checked": <N>,
    "files_changed": <CHANGED>,
    "files_related": <RELATED>,
    "skills_applied": [<SKILLS>],
    "violations_found": <CONFIRMED_COUNT>,
    "false_positives_filtered": <FILTERED_COUNT>
  }
}

================================================================================
CRITICAL OUTPUT REQUIREMENTS
================================================================================
- Your FINAL output must be ONLY the JSON object. No markdown wrapping, no
  explanation text, no code fences. Just raw JSON.
- The JSON must be parseable by jq.
- "verdict" must be exactly one of: "pass", "fail", "skip"
- Every inline_comments[].body MUST contain <!-- pr-code-review-validator -->
- The "summary" field MUST start with <!-- pr-code-review-validator -->
- Replace ALL <PLACEHOLDERS> with actual computed values
- If any stage encounters an error reading skill files, log a warning and
  continue with remaining skills. If ALL skill files are unreadable, output
  a fail verdict with an error explanation in the summary.

Now execute Stage 1. Begin by running: git diff --name-only origin/main...HEAD
PIPELINE_PROMPT

# ---------------------------------------------------------------------------
# Run the pipeline via Claude Code CLI
# ---------------------------------------------------------------------------
echo "Running full review pipeline..."
timeout 540 claude --print --model haiku --output-format json < pipeline-prompt.txt > pipeline-output-raw.json

# ---------------------------------------------------------------------------
# Log token usage and duration from the CLI envelope
# ---------------------------------------------------------------------------
if jq -e '.type' pipeline-output-raw.json >/dev/null 2>&1; then
  DURATION_MS=$(jq -r '.duration_ms // "N/A"' pipeline-output-raw.json)
  DURATION_API_MS=$(jq -r '.duration_api_ms // "N/A"' pipeline-output-raw.json)
  NUM_TURNS=$(jq -r '.num_turns // "N/A"' pipeline-output-raw.json)
  INPUT_TOKENS=$(jq -r '.usage.input_tokens // .input_tokens // "N/A"' pipeline-output-raw.json)
  OUTPUT_TOKENS=$(jq -r '.usage.output_tokens // .output_tokens // "N/A"' pipeline-output-raw.json)
  TOTAL_TOKENS=$(jq -r '.usage.total_tokens // .total_tokens // "N/A"' pipeline-output-raw.json)
  CACHE_READ=$(jq -r '.usage.cache_read_input_tokens // .cache_read_input_tokens // "N/A"' pipeline-output-raw.json)
  CACHE_CREATION=$(jq -r '.usage.cache_creation_input_tokens // .cache_creation_input_tokens // "N/A"' pipeline-output-raw.json)

  echo ""
  echo "=============================="
  echo "  Pipeline Usage Stats"
  echo "=============================="
  echo "  Duration (total):  ${DURATION_MS} ms"
  echo "  Duration (API):    ${DURATION_API_MS} ms"
  echo "  Turns:             ${NUM_TURNS}"
  echo "  Input tokens:      ${INPUT_TOKENS}"
  echo "  Output tokens:     ${OUTPUT_TOKENS}"
  echo "  Total tokens:      ${TOTAL_TOKENS}"
  echo "  Cache read:        ${CACHE_READ}"
  echo "  Cache creation:    ${CACHE_CREATION}"
  echo "=============================="
  echo ""
fi

# ---------------------------------------------------------------------------
# Extract and validate output
# ---------------------------------------------------------------------------
echo "Raw CLI output (first 500 chars):"
head -c 500 pipeline-output-raw.json
echo ""

EXTRACTED=false

# Strategy 1: Direct — the file itself is the pipeline JSON (has .verdict)
if jq -e '.verdict' pipeline-output-raw.json >/dev/null 2>&1; then
  echo "Output is direct pipeline JSON"
  cp pipeline-output-raw.json pipeline-output.json
  EXTRACTED=true
fi

# Strategy 2: CLI envelope — extract .result field
if [ "$EXTRACTED" = false ]; then
  RESULT_TEXT=$(jq -r '.result // empty' pipeline-output-raw.json 2>/dev/null)
  if [ -n "$RESULT_TEXT" ]; then
    echo "Extracting from CLI envelope .result field..."
    if echo "$RESULT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
      echo "$RESULT_TEXT" | jq '.' > pipeline-output.json
      EXTRACTED=true
    fi
  fi
fi

# Strategy 3: CLI envelope may have result as an array of content blocks
if [ "$EXTRACTED" = false ]; then
  CONTENT_TEXT=$(jq -r '
    if (.result | type) == "array" then
      [.result[] | .text // empty] | join("")
    elif (.content | type) == "array" then
      [.content[] | .text // empty] | join("")
    else
      empty
    end
  ' pipeline-output-raw.json 2>/dev/null)
  if [ -n "$CONTENT_TEXT" ] && echo "$CONTENT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
    echo "Extracting from content blocks..."
    echo "$CONTENT_TEXT" | jq '.' > pipeline-output.json
    EXTRACTED=true
  fi
fi

# Strategy 4: Try to find JSON embedded in text
if [ "$EXTRACTED" = false ]; then
  echo "Attempting to extract embedded JSON from output..."
  RAW_TEXT=$(jq -r '.result // .' pipeline-output-raw.json 2>/dev/null || cat pipeline-output-raw.json)
  EMBEDDED_JSON=$(echo "$RAW_TEXT" | sed -n '/^{/,/^}/p' | head -200)
  if [ -n "$EMBEDDED_JSON" ] && echo "$EMBEDDED_JSON" | jq -e '.verdict' >/dev/null 2>&1; then
    echo "$EMBEDDED_JSON" | jq '.' > pipeline-output.json
    EXTRACTED=true
  fi
fi

if [ "$EXTRACTED" = false ]; then
  echo "::error::Could not extract pipeline JSON from CLI output"
  echo "Full output:"
  cat pipeline-output-raw.json
  exit 1
fi

# Final validation
if ! jq empty pipeline-output.json 2>/dev/null; then
  echo "::error::Extracted output is not valid JSON"
  cat pipeline-output.json
  exit 1
fi

VERDICT=$(jq -r '.verdict' pipeline-output.json)
echo "Pipeline complete. Verdict: ${VERDICT}"

if [[ "$VERDICT" != "pass" && "$VERDICT" != "fail" && "$VERDICT" != "skip" ]]; then
  echo "::error::Invalid verdict: ${VERDICT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Create state JSON from full review results
# ---------------------------------------------------------------------------
echo "Creating state file: ${STATE_FILE}"
mkdir -p .github/pr

COMMIT_SHA=$(git rev-parse HEAD)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HEAD_BRANCH_NAME="${HEAD_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

CONFIRMED_VIOLATIONS=$(jq -c '.confirmed_violations // .inline_comments // []' pipeline-output.json)
VIOLATION_COUNT=$(echo "$CONFIRMED_VIOLATIONS" | jq 'length')

NEXT_ID=1
ISSUES='{}'
FOUND_IDS='[]'

if (( VIOLATION_COUNT > 0 )); then
  for row in $(echo "$CONFIRMED_VIOLATIONS" | jq -c '.[]'); do
    ISSUE_ID="issue-${NEXT_ID}"
    SKILL=$(echo "$row" | jq -r '.skill // "unknown"')
    RULE=$(echo "$row" | jq -r '.rule // "unknown"')
    SCOPE=$(echo "$row" | jq -r '.scope // "frontend"')
    FPATH=$(echo "$row" | jq -r '.path')
    LINE=$(echo "$row" | jq '.line // 1')
    DESC=$(echo "$row" | jq -r '.description // ""')
    SUGGESTION=$(echo "$row" | jq -r '.suggestion // ""')
    SEVERITY=$(echo "$row" | jq -r '.severity // "Critical"')
    BODY=$(echo "$row" | jq -r '.body // ""')

    ISSUES=$(echo "$ISSUES" | jq \
      --arg id "$ISSUE_ID" \
      --arg skill "$SKILL" \
      --arg rule "$RULE" \
      --arg scope "$SCOPE" \
      --arg path "$FPATH" \
      --argjson line "$LINE" \
      --arg desc "$DESC" \
      --arg suggestion "$SUGGESTION" \
      --arg severity "$SEVERITY" \
      --arg body "$BODY" \
      '. + {($id): {
        skill: $skill,
        rule: $rule,
        scope: $scope,
        path: $path,
        line: $line,
        description: $desc,
        suggestion: $suggestion,
        severity: $severity,
        status: "open",
        found_in_round: 1,
        resolved_in_round: null,
        inline_comment_body: $body
      }}')
    FOUND_IDS=$(echo "$FOUND_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')
    NEXT_ID=$((NEXT_ID + 1))
  done
fi

FILES_CHECKED=$(jq -c '.stats.files_checked // 0' pipeline-output.json)

jq -n \
  --argjson pr "$PR_NUMBER" \
  --arg base "main" \
  --arg head "$HEAD_BRANCH_NAME" \
  --arg created "$TIMESTAMP" \
  --arg updated "$TIMESTAMP" \
  --argjson next_id "$NEXT_ID" \
  --arg sha "$COMMIT_SHA" \
  --arg ts "$TIMESTAMP" \
  --argjson files_checked "$FILES_CHECKED" \
  --argjson found_ids "$FOUND_IDS" \
  --argjson issues "$ISSUES" \
  '{
    pr_number: $pr,
    base_branch: $base,
    head_branch: $head,
    created_at: $created,
    last_updated: $updated,
    next_issue_id: $next_id,
    reviews: [{
      round: 1,
      commit_sha: $sha,
      timestamp: $ts,
      type: "full",
      files_checked: $files_checked,
      newly_fixed_ids: [],
      newly_found_ids: $found_ids,
      regressed_ids: []
    }],
    issues: $issues
  }' > "$STATE_FILE"

echo "State file created with ${VIOLATION_COUNT} issue(s)"

# ---------------------------------------------------------------------------
# Rebuild pipeline-output.json with the stateful summary format
# ---------------------------------------------------------------------------
echo "Rebuilding summary in stateful format..."

if (( VIOLATION_COUNT == 0 )); then
  R1_VERDICT="pass"
  R1_STATUS="**PASSED**"
else
  R1_VERDICT="fail"
  R1_STATUS="**BLOCKED**"
fi

R1_SUMMARY="<!-- pr-code-review-validator -->
## PR Review — Round 1

| Metric | Value |
|--------|-------|
| Review round | 1 |
| Review type | Full |
| Files checked | ${FILES_CHECKED} |
| Current issues | ${VIOLATION_COUNT} |
| Fixed (cumulative) | 0 |
| Status | ${R1_STATUS} |"

if (( VIOLATION_COUNT > 0 )); then
  R1_CURRENT_LIST=$(echo "$ISSUES" | jq -r 'to_entries[] | "- [ ] **\(.value.skill) > \(.value.rule)** — `\(.value.path):\(.value.line)` — \(.value.description) *(since round 1)*"')
  R1_SUMMARY="${R1_SUMMARY}

### Current Issues

${R1_CURRENT_LIST}"
else
  R1_SUMMARY="${R1_SUMMARY}

No violations found. This PR is ready to merge."
fi

R1_SUMMARY="${R1_SUMMARY}

---
*This review was generated by the PR Code Review Validator (stateful mode).*
*Review state: \`.github/pr/pr-${PR_NUMBER}.json\`*"

# Rebuild inline comments from state issues
R1_INLINE=$(echo "$ISSUES" | jq '[to_entries[] | select(.value.inline_comment_body != null and .value.inline_comment_body != "") | {
  path: .value.path,
  line: .value.line,
  side: "RIGHT",
  body: .value.inline_comment_body
}]')

jq -n \
  --arg verdict "$R1_VERDICT" \
  --arg summary "$R1_SUMMARY" \
  --argjson inline_comments "$R1_INLINE" \
  --argjson files_checked "$FILES_CHECKED" \
  --argjson violations "$VIOLATION_COUNT" \
  '{
    verdict: $verdict,
    summary: $summary,
    inline_comments: $inline_comments,
    stats: {
      files_checked: $files_checked,
      current_issues: $violations,
      fixed_cumulative: 0,
      newly_fixed: 0,
      newly_found: $violations,
      regressions: 0
    }
  }' > pipeline-output.json

echo "Summary rebuilt in stateful format. Verdict: ${R1_VERDICT}"

# Clean up temp files
rm -f pipeline-output-raw.json pipeline-prompt.txt
