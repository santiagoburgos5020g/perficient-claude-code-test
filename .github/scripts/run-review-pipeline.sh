#!/usr/bin/env bash
# run-review-pipeline.sh
# Invokes the Claude Code CLI with the review pipeline.
#
# Supports two modes:
#   REVIEW_MODE=full        — validate all changed files vs origin/main, create state file
#   REVIEW_MODE=incremental — verify existing issues + detect new violations, update state file
#
# Required env vars: ANTHROPIC_BEDROCK_BASE_URL, ANTHROPIC_CUSTOM_HEADERS,
#   CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_SKIP_BEDROCK_AUTH, GH_TOKEN,
#   PR_NUMBER, REPO, HEAD_REF, BASE_REF
# Optional env vars: REVIEW_MODE

set -euo pipefail

STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"

# ---------------------------------------------------------------------------
# 1. Large PR detection — warn if >50 code files
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Helper: Extract pipeline JSON from Claude CLI output
# ---------------------------------------------------------------------------
extract_pipeline_json() {
  local input_file="$1"
  local output_file="$2"
  local EXTRACTED=false

  # Strategy 1: Direct — the file itself is the pipeline JSON (has .verdict)
  if jq -e '.verdict' "$input_file" >/dev/null 2>&1; then
    cp "$input_file" "$output_file"
    EXTRACTED=true
  fi

  # Strategy 2: CLI envelope — extract .result field
  if [ "$EXTRACTED" = false ]; then
    local RESULT_TEXT
    RESULT_TEXT=$(jq -r '.result // empty' "$input_file" 2>/dev/null)
    if [ -n "$RESULT_TEXT" ]; then
      if echo "$RESULT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
        echo "$RESULT_TEXT" | jq '.' > "$output_file"
        EXTRACTED=true
      fi
    fi
  fi

  # Strategy 3: CLI envelope may have result as array of content blocks
  if [ "$EXTRACTED" = false ]; then
    local CONTENT_TEXT
    CONTENT_TEXT=$(jq -r '
      if (.result | type) == "array" then
        [.result[] | .text // empty] | join("")
      elif (.content | type) == "array" then
        [.content[] | .text // empty] | join("")
      else
        empty
      end
    ' "$input_file" 2>/dev/null)
    if [ -n "$CONTENT_TEXT" ] && echo "$CONTENT_TEXT" | jq -e '.verdict' >/dev/null 2>&1; then
      echo "$CONTENT_TEXT" | jq '.' > "$output_file"
      EXTRACTED=true
    fi
  fi

  # Strategy 4: Try to find JSON embedded in text
  if [ "$EXTRACTED" = false ]; then
    local RAW_TEXT
    RAW_TEXT=$(jq -r '.result // .' "$input_file" 2>/dev/null || cat "$input_file")
    local EMBEDDED_JSON
    EMBEDDED_JSON=$(echo "$RAW_TEXT" | sed -n '/^{/,/^}/p' | head -200)
    if [ -n "$EMBEDDED_JSON" ] && echo "$EMBEDDED_JSON" | jq -e '.verdict' >/dev/null 2>&1; then
      echo "$EMBEDDED_JSON" | jq '.' > "$output_file"
      EXTRACTED=true
    fi
  fi

  if [ "$EXTRACTED" = false ]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Helper: Log token usage from CLI envelope
# ---------------------------------------------------------------------------
log_usage_stats() {
  local file="$1"
  if jq -e '.type' "$file" >/dev/null 2>&1; then
    local DURATION_MS DURATION_API_MS NUM_TURNS INPUT_TOKENS OUTPUT_TOKENS
    DURATION_MS=$(jq -r '.duration_ms // "N/A"' "$file")
    DURATION_API_MS=$(jq -r '.duration_api_ms // "N/A"' "$file")
    NUM_TURNS=$(jq -r '.num_turns // "N/A"' "$file")
    INPUT_TOKENS=$(jq -r '.usage.input_tokens // .input_tokens // "N/A"' "$file")
    OUTPUT_TOKENS=$(jq -r '.usage.output_tokens // .output_tokens // "N/A"' "$file")

    echo ""
    echo "  Duration (total):  ${DURATION_MS} ms"
    echo "  Duration (API):    ${DURATION_API_MS} ms"
    echo "  Turns:             ${NUM_TURNS}"
    echo "  Input tokens:      ${INPUT_TOKENS}"
    echo "  Output tokens:     ${OUTPUT_TOKENS}"
  fi
}

# ---------------------------------------------------------------------------
# Helper: Extract verification JSON from Claude CLI output
# ---------------------------------------------------------------------------
extract_verification_json() {
  local input_file="$1"
  local output_file="$2"
  local EXTRACTED=false

  # Strategy 1: Direct JSON array
  if jq -e 'type == "array"' "$input_file" >/dev/null 2>&1; then
    cp "$input_file" "$output_file"
    EXTRACTED=true
  fi

  # Strategy 2: CLI envelope with .result as string containing JSON array
  if [ "$EXTRACTED" = false ]; then
    local RESULT_TEXT
    RESULT_TEXT=$(jq -r '.result // empty' "$input_file" 2>/dev/null)
    if [ -n "$RESULT_TEXT" ] && echo "$RESULT_TEXT" | jq -e 'type == "array"' >/dev/null 2>&1; then
      echo "$RESULT_TEXT" | jq '.' > "$output_file"
      EXTRACTED=true
    fi
  fi

  # Strategy 3: Content blocks
  if [ "$EXTRACTED" = false ]; then
    local CONTENT_TEXT
    CONTENT_TEXT=$(jq -r '
      if (.result | type) == "array" then
        [.result[] | .text // empty] | join("")
      elif (.content | type) == "array" then
        [.content[] | .text // empty] | join("")
      else
        empty
      end
    ' "$input_file" 2>/dev/null)
    if [ -n "$CONTENT_TEXT" ] && echo "$CONTENT_TEXT" | jq -e 'type == "array"' >/dev/null 2>&1; then
      echo "$CONTENT_TEXT" | jq '.' > "$output_file"
      EXTRACTED=true
    fi
  fi

  # Strategy 4: Embedded JSON array in text
  if [ "$EXTRACTED" = false ]; then
    local RAW_TEXT
    RAW_TEXT=$(jq -r '.result // .' "$input_file" 2>/dev/null || cat "$input_file")
    local EMBEDDED
    EMBEDDED=$(echo "$RAW_TEXT" | sed -n '/^\[/,/^\]/p' | head -200)
    if [ -n "$EMBEDDED" ] && echo "$EMBEDDED" | jq -e 'type == "array"' >/dev/null 2>&1; then
      echo "$EMBEDDED" | jq '.' > "$output_file"
      EXTRACTED=true
    fi
  fi

  if [ "$EXTRACTED" = false ]; then
    return 1
  fi
  return 0
}

# ===========================================================================
# FULL MODE
# ===========================================================================
run_full_review() {
  echo "========================================="
  echo "  Running FULL review pipeline"
  echo "========================================="

  # Write the base pipeline prompt
  write_base_pipeline_prompt

  # Run the pipeline via Claude Code CLI
  echo "Starting full review pipeline..."
  timeout 540 claude --print --model haiku --output-format json < pipeline-prompt.txt > cli-output-raw.json

  if [ ! -f cli-output-raw.json ]; then
    echo "::error::Pipeline did not produce output file"
    exit 1
  fi

  echo "Raw CLI output (first 500 chars):"
  head -c 500 cli-output-raw.json
  echo ""

  log_usage_stats cli-output-raw.json

  if ! extract_pipeline_json cli-output-raw.json pipeline-output.json; then
    echo "::error::Could not extract pipeline JSON from CLI output"
    cat cli-output-raw.json
    exit 1
  fi

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

  # Create state file from pipeline output
  create_state_file_from_pipeline
}

# ===========================================================================
# INCREMENTAL MODE
# ===========================================================================
run_incremental_review() {
  echo "========================================="
  echo "  Running INCREMENTAL review pipeline"
  echo "========================================="

  if [[ ! -f review-context.json ]]; then
    echo "::error::review-context.json not found for incremental mode"
    exit 1
  fi

  local ROUND
  ROUND=$(jq -r '.round' review-context.json)
  echo "Round: ${ROUND}"

  # Initialize result collectors
  echo '[]' > verification-results.json
  echo '[]' > new-violations.json

  # -----------------------------------------------------------------------
  # Part A: Verification Agent — verify existing issues on touched files
  # -----------------------------------------------------------------------
  local VERIF_FILES
  VERIF_FILES=$(jq -r '.files_for_verification | length' review-context.json)

  if (( VERIF_FILES > 0 )); then
    echo ""
    echo "--- Part A: Verification (${VERIF_FILES} files) ---"
    run_verification_agent
  else
    echo ""
    echo "--- Part A: No files need verification ---"
  fi

  # -----------------------------------------------------------------------
  # Part A.2: Handle deleted files — auto-fix all open issues
  # -----------------------------------------------------------------------
  local DELETED_COUNT
  DELETED_COUNT=$(jq '.open_issues_on_deleted | length' review-context.json)

  if (( DELETED_COUNT > 0 )); then
    echo ""
    echo "--- Part A.2: Auto-fixing ${DELETED_COUNT} issues on deleted files ---"
    # Generate FIXED results for all deleted file issues
    jq '.open_issues_on_deleted | [.[] | {id: .id, status: "FIXED", new_line: null, explanation: "File was deleted"}]' \
      review-context.json > deleted-results.json

    # Merge into verification results
    jq -s '.[0] + .[1]' verification-results.json deleted-results.json > verification-results-tmp.json
    mv verification-results-tmp.json verification-results.json
    rm -f deleted-results.json
  fi

  # -----------------------------------------------------------------------
  # Part B: New change detection — validate new/unreviewed files
  # -----------------------------------------------------------------------
  local NEW_DETECT_FILES
  NEW_DETECT_FILES=$(jq -r '.files_for_new_detection | length' review-context.json)

  if (( NEW_DETECT_FILES > 0 )); then
    echo ""
    echo "--- Part B: New change detection (${NEW_DETECT_FILES} files) ---"
    run_scoped_pipeline
  else
    echo ""
    echo "--- Part B: No new files to detect ---"
  fi

  # -----------------------------------------------------------------------
  # Merge results and update state file
  # -----------------------------------------------------------------------
  echo ""
  echo "--- Merging results and updating state ---"
  update_state_file_incremental

  echo ""
  echo "Incremental review complete."
}

# ---------------------------------------------------------------------------
# Verification agent: per-file issue verification
# ---------------------------------------------------------------------------
run_verification_agent() {
  local files_json
  files_json=$(jq -r '.files_for_verification[]' review-context.json)

  while IFS= read -r file_path; do
    [[ -z "$file_path" ]] && continue

    echo "  Verifying issues on: ${file_path}"

    if [[ ! -f "$file_path" ]]; then
      echo "    File not found — treating as deleted, all issues FIXED"
      # Generate FIXED for all issues on this file
      jq --arg path "$file_path" '
        [(.open_issues_on_touched + .fixed_issues_on_touched)[] |
          select(.path == $path) |
          {id: .id, status: "FIXED", new_line: null, explanation: "File no longer exists"}
        ]
      ' review-context.json > "verif-${file_path//\//_}.json"

      jq -s '.[0] + .[1]' verification-results.json "verif-${file_path//\//_}.json" > verification-results-tmp.json
      mv verification-results-tmp.json verification-results.json
      rm -f "verif-${file_path//\//_}.json"
      continue
    fi

    # Collect open + fixed issues for this file
    local open_issues fixed_issues
    open_issues=$(jq -c --arg path "$file_path" \
      '[.open_issues_on_touched[] | select(.path == $path)]' review-context.json)
    fixed_issues=$(jq -c --arg path "$file_path" \
      '[.fixed_issues_on_touched[] | select(.path == $path)]' review-context.json)

    local open_count fixed_count
    open_count=$(echo "$open_issues" | jq 'length')
    fixed_count=$(echo "$fixed_issues" | jq 'length')

    if (( open_count == 0 && fixed_count == 0 )); then
      echo "    No issues to verify on this file. Skipping."
      continue
    fi

    echo "    Open issues: ${open_count}, Fixed issues (regression check): ${fixed_count}"

    # Read file contents with line numbers
    local file_contents
    file_contents=$(cat -n "$file_path")

    # Build verification prompt
    cat > "verification-prompt.txt" <<VERIFICATION_PROMPT
You are the Issue Verification Agent. You are given a list of previously reported
code violations and the current state of the source file. For each violation,
determine whether it has been FIXED or is STILL_PRESENT in the current code.

FILE: ${file_path}

CURRENT FILE CONTENTS:
\`\`\`
${file_contents}
\`\`\`

OPEN VIOLATIONS TO VERIFY (currently reported as issues):
${open_issues}

PREVIOUSLY FIXED VIOLATIONS TO CHECK FOR REGRESSION:
${fixed_issues}

INSTRUCTIONS:

For each violation (both open and previously fixed):
1. Read the violation's rule, description, original line number, and suggestion
2. Examine the CURRENT file contents carefully:
   - The code may have moved to a different line number
   - The code may have been refactored
   - The offending code may have been removed entirely
   - The file structure may have changed significantly
3. Determine one of:
   - FIXED: The violation no longer exists in this file. The offending code was
     changed to comply with the rule, moved to the correct location, refactored
     appropriately, or removed.
   - STILL_PRESENT: The same violation still exists in this file, even if the
     code has moved to a different line number.

JUDGMENT RULES:
- Judge based on the RULE and DESCRIPTION, not the exact line number. Code shifts
  are normal during development.
- If the offending code was deleted entirely, that counts as FIXED.
- If the code was moved to a different file entirely (no longer in this file),
  mark FIXED for this file's evaluation.
- Be CONSERVATIVE: when genuinely uncertain, mark as STILL_PRESENT. It is far
  better to report a false "still present" (developer can explain) than a false
  "fixed" (violation slips through).
- For previously FIXED violations: only mark STILL_PRESENT if you see clear
  evidence that the same pattern/violation has been reintroduced.

OUTPUT FORMAT:
Return ONLY a valid JSON array. No markdown, no explanation text, no code fences.

[
  {
    "id": "issue-1",
    "status": "FIXED",
    "new_line": null,
    "explanation": "The Todo interface was moved to types/todo.ts and is now imported."
  },
  {
    "id": "issue-3",
    "status": "STILL_PRESENT",
    "new_line": 18,
    "explanation": "The useEffect+fetch pattern is still present, now at line 18."
  }
]

The "new_line" field:
- For STILL_PRESENT: the current line number where the violation exists (may differ from original)
- For FIXED: null
VERIFICATION_PROMPT

    # Invoke verification agent
    local verif_raw="verif-raw-${file_path//\//_}.json"
    local verif_parsed="verif-parsed-${file_path//\//_}.json"

    if timeout 120 claude --print --model sonnet --output-format json < verification-prompt.txt > "$verif_raw" 2>/dev/null; then
      echo "    Verification agent completed."
      log_usage_stats "$verif_raw"

      if extract_verification_json "$verif_raw" "$verif_parsed"; then
        echo "    Parsed $(jq 'length' "$verif_parsed") verification results."
        # Merge into cumulative results
        jq -s '.[0] + .[1]' verification-results.json "$verif_parsed" > verification-results-tmp.json
        mv verification-results-tmp.json verification-results.json
      else
        echo "    ::warning::Could not parse verification output for ${file_path}. Treating all as STILL_PRESENT."
        # Generate STILL_PRESENT for all issues on this file
        jq --arg path "$file_path" '
          [(.open_issues_on_touched + .fixed_issues_on_touched)[] |
            select(.path == $path) |
            {id: .id, status: "STILL_PRESENT", new_line: .line, explanation: "Verification agent output could not be parsed"}
          ]
        ' review-context.json > "$verif_parsed"
        jq -s '.[0] + .[1]' verification-results.json "$verif_parsed" > verification-results-tmp.json
        mv verification-results-tmp.json verification-results.json
      fi
    else
      echo "    ::warning::Verification agent failed/timed out for ${file_path}. Treating all as STILL_PRESENT."
      jq --arg path "$file_path" '
        [(.open_issues_on_touched + .fixed_issues_on_touched)[] |
          select(.path == $path) |
          {id: .id, status: "STILL_PRESENT", new_line: .line, explanation: "Verification agent timed out or failed"}
        ]
      ' review-context.json > "$verif_parsed"
      jq -s '.[0] + .[1]' verification-results.json "$verif_parsed" > verification-results-tmp.json
      mv verification-results-tmp.json verification-results.json
    fi

    rm -f "verification-prompt.txt" "$verif_raw" "$verif_parsed"
  done <<< "$files_json"
}

# ---------------------------------------------------------------------------
# Scoped pipeline: detect new violations on new/unreviewed files
# ---------------------------------------------------------------------------
run_scoped_pipeline() {
  local files_list
  files_list=$(jq -r '.files_for_new_detection | join(", ")' review-context.json)
  local files_json
  files_json=$(jq -c '.files_for_new_detection' review-context.json)

  echo "  Files for new detection: ${files_list}"

  # Write the base pipeline prompt
  write_base_pipeline_prompt

  # Prepend scoped context
  cat > scoped-header.txt <<SCOPED_HEADER
================================================================================
SCOPED REVIEW CONTEXT (READ THIS FIRST)
================================================================================
This review is SCOPED to a specific set of files. Do NOT run git diff.
Use ONLY the files listed below.

FILES TO REVIEW:
${files_json}

INSTRUCTIONS FOR SCOPED MODE:
- In Stage 1, do NOT run git diff commands (Step 1.1 and Step 1.2).
- Instead, use the FILES TO REVIEW list above as your changed files.
- All files in this list are new or newly changed — none are "new files" in
  the git sense unless they don't exist on origin/main.
- To check if a file is new, run: git diff --diff-filter=A --name-only origin/main...HEAD
  and see if the file appears in the output.
- Classify files using Step 1.5's path rules as normal.
- Proceed with Stages 2 and 3 as normal.

================================================================================

SCOPED_HEADER

  cat scoped-header.txt pipeline-prompt.txt > pipeline-prompt-scoped.txt
  rm -f scoped-header.txt

  echo "  Starting scoped pipeline..."
  if timeout 540 claude --print --model haiku --output-format json < pipeline-prompt-scoped.txt > cli-output-scoped-raw.json 2>/dev/null; then
    echo "  Scoped pipeline completed."
    log_usage_stats cli-output-scoped-raw.json

    if extract_pipeline_json cli-output-scoped-raw.json pipeline-output-scoped.json; then
      local scoped_verdict
      scoped_verdict=$(jq -r '.verdict' pipeline-output-scoped.json)
      echo "  Scoped pipeline verdict: ${scoped_verdict}"

      if [[ "$scoped_verdict" == "fail" ]]; then
        # Extract inline comments as new violations
        jq '.inline_comments // []' pipeline-output-scoped.json > new-violations.json
        echo "  New violations found: $(jq 'length' new-violations.json)"
      else
        echo '[]' > new-violations.json
        echo "  No new violations found."
      fi
    else
      echo "  ::warning::Could not parse scoped pipeline output. No new violations recorded."
      echo '[]' > new-violations.json
    fi
  else
    echo "  ::warning::Scoped pipeline failed/timed out. No new violations recorded."
    echo '[]' > new-violations.json
  fi

  rm -f pipeline-prompt-scoped.txt cli-output-scoped-raw.json pipeline-output-scoped.json
}

# ---------------------------------------------------------------------------
# Create state file from full pipeline output (round 1 or force-push reset)
# ---------------------------------------------------------------------------
create_state_file_from_pipeline() {
  mkdir -p .github/pr

  local ROUND=1
  local FORCE_PUSH=false

  # Check if we have a review context with an existing round
  if [[ -f review-context.json ]]; then
    ROUND=$(jq -r '.round // 1' review-context.json)
    FORCE_PUSH=$(jq -r '.force_push_detected // false' review-context.json)
  fi

  local VERDICT
  VERDICT=$(jq -r '.verdict' pipeline-output.json)

  if [[ "$VERDICT" == "skip" ]]; then
    echo "Verdict is skip — creating minimal state file."
    jq -n \
      --argjson pr_number "$PR_NUMBER" \
      --arg head_branch "${HEAD_REF}" \
      --arg base_branch "${BASE_REF}" \
      --argjson round "$ROUND" \
      --arg sha "$(git rev-parse HEAD)" \
      '{
        pr_number: $pr_number,
        base_branch: $base_branch,
        head_branch: $head_branch,
        created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        last_updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        next_issue_id: 1,
        reviews: [{
          round: $round,
          commit_sha: $sha,
          timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
          type: "full",
          files_checked: [],
          newly_found_ids: [],
          newly_fixed_ids: [],
          regressed_ids: []
        }],
        issues: {}
      }' > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
    echo "State file created (skip): ${STATE_FILE}"
    return
  fi

  # Extract inline comments (violations) from pipeline output
  local VIOLATIONS
  VIOLATIONS=$(jq '.inline_comments // []' pipeline-output.json)
  local VIOLATION_COUNT
  VIOLATION_COUNT=$(echo "$VIOLATIONS" | jq 'length')

  echo "Creating state file with ${VIOLATION_COUNT} issues..."

  # Determine starting issue ID
  local START_ID=1
  if [[ "$FORCE_PUSH" == "true" ]] && [[ -f "$STATE_FILE" ]]; then
    START_ID=$(jq '.next_issue_id // 1' "$STATE_FILE")
    echo "Force push: continuing from issue ID ${START_ID}"
  fi

  # Build issues map and found IDs from violations
  local ISSUES='{}'
  local FOUND_IDS='[]'
  local NEXT_ID=$START_ID

  for i in $(seq 0 $((VIOLATION_COUNT - 1))); do
    local ISSUE_ID="issue-${NEXT_ID}"
    local v
    v=$(echo "$VIOLATIONS" | jq -c ".[$i]")

    local v_path v_line v_body v_skill v_rule v_description v_suggestion v_severity v_scope
    v_path=$(echo "$v" | jq -r '.path // "unknown"')
    v_line=$(echo "$v" | jq -r '.line // 1')
    v_body=$(echo "$v" | jq -r '.body // ""')

    # Parse skill and rule from body format: **skill > rule**
    v_skill=$(echo "$v_body" | head -1 | sed -n 's/^\*\*\([^>]*\)>.*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    v_rule=$(echo "$v_body" | head -1 | sed -n 's/^\*\*[^>]*>[[:space:]]*\([^*]*\)\*\*.*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Extract description (second paragraph) and suggestion
    v_description=$(echo "$v_body" | awk '/^$/{p++} p==1{print}' | head -3 | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    v_suggestion=$(echo "$v_body" | sed -n 's/^\*\*Suggestion:\*\*[[:space:]]*//p' | head -1)

    # Defaults
    [[ -z "$v_skill" ]] && v_skill="unknown"
    [[ -z "$v_rule" ]] && v_rule="unknown"
    [[ -z "$v_description" ]] && v_description="See inline comment for details"
    [[ -z "$v_suggestion" ]] && v_suggestion="See inline comment for details"

    # Determine scope from path
    v_scope="frontend"
    if echo "$v_path" | grep -qE '^pages/api/|^lib/|^services/|^prisma/|\.prisma$|\.sql$'; then
      v_scope="backend"
    fi

    # Determine severity from body content
    v_severity="Critical"
    if echo "$v_body" | grep -qi "recommended"; then
      v_severity="Recommended"
    fi

    ISSUES=$(echo "$ISSUES" | jq \
      --arg id "$ISSUE_ID" \
      --arg skill "$v_skill" \
      --arg rule "$v_rule" \
      --arg scope "$v_scope" \
      --arg path "$v_path" \
      --argjson line "$v_line" \
      --arg description "$v_description" \
      --arg suggestion "$v_suggestion" \
      --arg severity "$v_severity" \
      --argjson found_in "$ROUND" \
      --arg body "$v_body" \
      '. + {($id): {
        skill: $skill,
        rule: $rule,
        scope: $scope,
        path: $path,
        line: $line,
        description: $description,
        suggestion: $suggestion,
        severity: $severity,
        status: "open",
        found_in_round: $found_in,
        resolved_in_round: null,
        inline_comment_body: $body
      }}')

    FOUND_IDS=$(echo "$FOUND_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')
    NEXT_ID=$((NEXT_ID + 1))
  done

  # Get files checked from pipeline stats
  local FILES_CHECKED
  FILES_CHECKED=$(jq '[.stats.files_checked // 0] | if .[0] == 0 then [] else [] end' pipeline-output.json)
  # Try to get from the inline comments paths
  FILES_CHECKED=$(echo "$VIOLATIONS" | jq '[.[].path] | unique')

  # Preserve existing reviews if force push
  local EXISTING_REVIEWS='[]'
  if [[ "$FORCE_PUSH" == "true" ]] && [[ -f "$STATE_FILE" ]]; then
    EXISTING_REVIEWS=$(jq '.reviews // []' "$STATE_FILE")
  fi

  # Build the state file
  jq -n \
    --argjson pr_number "$PR_NUMBER" \
    --arg head_branch "${HEAD_REF}" \
    --arg base_branch "${BASE_REF}" \
    --argjson next_issue_id "$NEXT_ID" \
    --argjson existing_reviews "$EXISTING_REVIEWS" \
    --argjson round "$ROUND" \
    --arg sha "$(git rev-parse HEAD)" \
    --argjson files_checked "$FILES_CHECKED" \
    --argjson found_ids "$FOUND_IDS" \
    --argjson issues "$ISSUES" \
    '{
      pr_number: $pr_number,
      base_branch: $base_branch,
      head_branch: $head_branch,
      created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      last_updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      next_issue_id: $next_issue_id,
      reviews: ($existing_reviews + [{
        round: $round,
        commit_sha: $sha,
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        type: "full",
        files_checked: $files_checked,
        newly_found_ids: $found_ids,
        newly_fixed_ids: [],
        regressed_ids: []
      }]),
      issues: $issues
    }' > "${STATE_FILE}.tmp"

  mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "State file created: ${STATE_FILE} (${VIOLATION_COUNT} issues, next_id=${NEXT_ID})"
}

# ---------------------------------------------------------------------------
# Update state file from incremental review results
# ---------------------------------------------------------------------------
update_state_file_incremental() {
  local ROUND
  ROUND=$(jq -r '.round' review-context.json)

  local CURRENT_SHA
  CURRENT_SHA=$(git rev-parse HEAD)

  # Read existing state
  local STATE
  STATE=$(cat "$STATE_FILE")

  local NEXT_ID
  NEXT_ID=$(echo "$STATE" | jq '.next_issue_id')

  # Collect IDs for the round summary
  local NEWLY_FIXED_IDS='[]'
  local NEWLY_FOUND_IDS='[]'
  local REGRESSED_IDS='[]'

  # -----------------------------------------------------------------------
  # Apply verification results to issue statuses
  # -----------------------------------------------------------------------
  local VERIF_COUNT
  VERIF_COUNT=$(jq 'length' verification-results.json)

  echo "Applying ${VERIF_COUNT} verification results..."

  for i in $(seq 0 $((VERIF_COUNT - 1))); do
    local result
    result=$(jq -c ".[$i]" verification-results.json)

    local r_id r_status r_new_line
    r_id=$(echo "$result" | jq -r '.id')
    r_status=$(echo "$result" | jq -r '.status')
    r_new_line=$(echo "$result" | jq -r '.new_line // "null"')

    # Get current issue status from state
    local current_status
    current_status=$(echo "$STATE" | jq -r --arg id "$r_id" '.issues[$id].status // "unknown"')

    if [[ "$current_status" == "unknown" ]]; then
      echo "  Warning: issue ${r_id} not found in state. Skipping."
      continue
    fi

    if [[ "$r_status" == "FIXED" ]] && [[ "$current_status" == "open" ]]; then
      # Issue was open, now fixed
      echo "  ${r_id}: FIXED (was open)"
      STATE=$(echo "$STATE" | jq \
        --arg id "$r_id" \
        --argjson round "$ROUND" \
        '.issues[$id].status = "fixed" | .issues[$id].resolved_in_round = $round')
      NEWLY_FIXED_IDS=$(echo "$NEWLY_FIXED_IDS" | jq --arg id "$r_id" '. + [$id]')

    elif [[ "$r_status" == "STILL_PRESENT" ]] && [[ "$current_status" == "fixed" ]]; then
      # Previously fixed issue regressed
      echo "  ${r_id}: REGRESSED (was fixed, now open again)"
      STATE=$(echo "$STATE" | jq \
        --arg id "$r_id" \
        '.issues[$id].status = "open" | .issues[$id].resolved_in_round = null')
      REGRESSED_IDS=$(echo "$REGRESSED_IDS" | jq --arg id "$r_id" '. + [$id]')

    elif [[ "$r_status" == "STILL_PRESENT" ]] && [[ "$current_status" == "open" ]]; then
      # Issue still present — update line number if changed
      if [[ "$r_new_line" != "null" ]]; then
        STATE=$(echo "$STATE" | jq \
          --arg id "$r_id" \
          --argjson line "$r_new_line" \
          '.issues[$id].line = $line')
      fi
      echo "  ${r_id}: STILL_PRESENT"

    elif [[ "$r_status" == "FIXED" ]] && [[ "$current_status" == "fixed" ]]; then
      # Already fixed, still fixed — no change needed
      echo "  ${r_id}: still fixed (no regression)"
    fi
  done

  # -----------------------------------------------------------------------
  # Add new violations from Part B
  # -----------------------------------------------------------------------
  local NEW_VIOLATION_COUNT
  NEW_VIOLATION_COUNT=$(jq 'length' new-violations.json)

  echo "Adding ${NEW_VIOLATION_COUNT} new violations..."

  for i in $(seq 0 $((NEW_VIOLATION_COUNT - 1))); do
    local ISSUE_ID="issue-${NEXT_ID}"
    local v
    v=$(jq -c ".[$i]" new-violations.json)

    local v_path v_line v_body v_skill v_rule v_description v_suggestion v_severity v_scope
    v_path=$(echo "$v" | jq -r '.path // "unknown"')
    v_line=$(echo "$v" | jq -r '.line // 1')
    v_body=$(echo "$v" | jq -r '.body // ""')

    v_skill=$(echo "$v_body" | head -1 | sed -n 's/^\*\*\([^>]*\)>.*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    v_rule=$(echo "$v_body" | head -1 | sed -n 's/^\*\*[^>]*>[[:space:]]*\([^*]*\)\*\*.*/\1/p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    v_description=$(echo "$v_body" | awk '/^$/{p++} p==1{print}' | head -3 | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    v_suggestion=$(echo "$v_body" | sed -n 's/^\*\*Suggestion:\*\*[[:space:]]*//p' | head -1)

    [[ -z "$v_skill" ]] && v_skill="unknown"
    [[ -z "$v_rule" ]] && v_rule="unknown"
    [[ -z "$v_description" ]] && v_description="See inline comment for details"
    [[ -z "$v_suggestion" ]] && v_suggestion="See inline comment for details"

    v_scope="frontend"
    if echo "$v_path" | grep -qE '^pages/api/|^lib/|^services/|^prisma/|\.prisma$|\.sql$'; then
      v_scope="backend"
    fi

    v_severity="Critical"
    if echo "$v_body" | grep -qi "recommended"; then
      v_severity="Recommended"
    fi

    STATE=$(echo "$STATE" | jq \
      --arg id "$ISSUE_ID" \
      --arg skill "$v_skill" \
      --arg rule "$v_rule" \
      --arg scope "$v_scope" \
      --arg path "$v_path" \
      --argjson line "$v_line" \
      --arg description "$v_description" \
      --arg suggestion "$v_suggestion" \
      --arg severity "$v_severity" \
      --argjson found_in "$ROUND" \
      --arg body "$v_body" \
      '.issues[$id] = {
        skill: $skill,
        rule: $rule,
        scope: $scope,
        path: $path,
        line: $line,
        description: $description,
        suggestion: $suggestion,
        severity: $severity,
        status: "open",
        found_in_round: $found_in,
        resolved_in_round: null,
        inline_comment_body: $body
      }')

    NEWLY_FOUND_IDS=$(echo "$NEWLY_FOUND_IDS" | jq --arg id "$ISSUE_ID" '. + [$id]')
    NEXT_ID=$((NEXT_ID + 1))
    echo "  Added ${ISSUE_ID}: ${v_skill} > ${v_rule} — ${v_path}:${v_line}"
  done

  # -----------------------------------------------------------------------
  # Collect files checked in this round
  # -----------------------------------------------------------------------
  local FILES_CHECKED
  FILES_CHECKED=$(jq -s '.[0] + .[1] | unique' \
    <(jq '.files_for_verification' review-context.json) \
    <(jq '.files_for_new_detection' review-context.json))

  # -----------------------------------------------------------------------
  # Append new round and update counters
  # -----------------------------------------------------------------------
  STATE=$(echo "$STATE" | jq \
    --argjson round "$ROUND" \
    --arg sha "$CURRENT_SHA" \
    --argjson files_checked "$FILES_CHECKED" \
    --argjson newly_fixed "$NEWLY_FIXED_IDS" \
    --argjson newly_found "$NEWLY_FOUND_IDS" \
    --argjson regressed "$REGRESSED_IDS" \
    --argjson next_id "$NEXT_ID" \
    '
    .reviews += [{
      round: $round,
      commit_sha: $sha,
      timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      type: "incremental",
      files_checked: $files_checked,
      newly_fixed_ids: $newly_fixed,
      newly_found_ids: $newly_found,
      regressed_ids: $regressed
    }]
    | .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    | .next_issue_id = $next_id
    ')

  # Write updated state
  echo "$STATE" | jq '.' > "${STATE_FILE}.tmp"
  mv "${STATE_FILE}.tmp" "$STATE_FILE"

  local OPEN_COUNT
  OPEN_COUNT=$(echo "$STATE" | jq '[.issues | to_entries[] | select(.value.status == "open")] | length')
  local FIXED_COUNT
  FIXED_COUNT=$(echo "$STATE" | jq '[.issues | to_entries[] | select(.value.status == "fixed")] | length')

  echo ""
  echo "State file updated: ${STATE_FILE}"
  echo "  Round: ${ROUND}"
  echo "  Newly fixed: $(echo "$NEWLY_FIXED_IDS" | jq 'length')"
  echo "  Newly found: $(echo "$NEWLY_FOUND_IDS" | jq 'length')"
  echo "  Regressions: $(echo "$REGRESSED_IDS" | jq 'length')"
  echo "  Total open: ${OPEN_COUNT}"
  echo "  Total fixed: ${FIXED_COUNT}"

  # -----------------------------------------------------------------------
  # Build pipeline-output.json for post-review.sh
  # -----------------------------------------------------------------------
  local VERDICT="pass"
  if (( OPEN_COUNT > 0 )); then
    VERDICT="fail"
  fi

  # Build inline comments for all open issues
  local INLINE_COMMENTS
  INLINE_COMMENTS=$(echo "$STATE" | jq '[
    .issues | to_entries[] |
    select(.value.status == "open") |
    {
      path: .value.path,
      line: .value.line,
      side: "RIGHT",
      body: .value.inline_comment_body
    }
  ]')

  jq -n \
    --arg verdict "$VERDICT" \
    --arg summary "placeholder" \
    --argjson inline_comments "$INLINE_COMMENTS" \
    '{
      verdict: $verdict,
      summary: $summary,
      inline_comments: $inline_comments
    }' > pipeline-output.json

  echo "Pipeline output written. Verdict: ${VERDICT}"
}

# ---------------------------------------------------------------------------
# Write the base 3-stage pipeline prompt (unchanged from original)
# ---------------------------------------------------------------------------
write_base_pipeline_prompt() {
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
}

# ===========================================================================
# MAIN EXECUTION
# ===========================================================================

REVIEW_MODE="${REVIEW_MODE:-full}"

echo "Review mode: ${REVIEW_MODE}"

if [[ "$REVIEW_MODE" == "incremental" ]]; then
  run_incremental_review
else
  run_full_review
fi
