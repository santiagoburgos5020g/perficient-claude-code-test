#!/usr/bin/env bash
# detect-review-mode.sh
# Determines whether this PR review should be FULL or INCREMENTAL by reading
# the persisted state file (.github/pr/pr-{number}.json).
#
# On incremental mode, classifies files into verification vs new-detection
# buckets and writes review-context.json for the pipeline.
#
# Required env vars: GH_TOKEN, PR_NUMBER, REPO, EVENT_ACTION, BEFORE_SHA, AFTER_SHA, HEAD_REF, BASE_REF
# Outputs: review_mode (full|incremental) via $GITHUB_OUTPUT

set -uo pipefail

STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"

# ---------------------------------------------------------------------------
# Helper: output full mode and write minimal review-context.json
# ---------------------------------------------------------------------------
set_full_mode() {
  local reason="${1:-unspecified}"
  echo "Review mode: FULL (reason: ${reason})"
  echo "review_mode=full" >> "$GITHUB_OUTPUT"

  jq -n \
    --arg review_mode "full" \
    --arg reason "$reason" \
    --arg state_file "$STATE_FILE" \
    --argjson round 1 \
    '{
      review_mode: $review_mode,
      reason: $reason,
      state_file: $state_file,
      round: $round,
      force_push_detected: false
    }' > review-context.json
}

set_full_mode_with_state() {
  local reason="${1:-unspecified}"
  local next_round
  next_round=$(jq '.reviews | length + 1' "$STATE_FILE" 2>/dev/null || echo 1)

  echo "Review mode: FULL with existing state (reason: ${reason})"
  echo "review_mode=full" >> "$GITHUB_OUTPUT"

  jq -n \
    --arg review_mode "full" \
    --arg reason "$reason" \
    --arg state_file "$STATE_FILE" \
    --argjson round "$next_round" \
    --argjson force_push true \
    '{
      review_mode: $review_mode,
      reason: $reason,
      state_file: $state_file,
      round: $round,
      force_push_detected: $force_push
    }' > review-context.json
}

# ---------------------------------------------------------------------------
# Code file filter (reused from original detect-review-mode.sh)
# ---------------------------------------------------------------------------
filter_code_files() {
  local files="$1"

  # Filter to code extensions only
  files=$(echo "$files" | grep -E '\.(ts|tsx|js|jsx|prisma|sql)$' || true)

  # Exclude non-code directories
  files=$(echo "$files" | grep -vE '^(node_modules/|\.next/|\.git/|dist/|build/|coverage/|\.claude/|\.github/|\.husky/|spec/|examples/|templates-example/|chrome-dev-tools/|public/|scripts/)' || true)

  # Exclude config files
  files=$(echo "$files" | grep -vE '(package\.json|package-lock\.json|tsconfig\.json|jest\.config|jest\.setup|\.eslintrc|next\.config|tailwind\.config|prettier\.config|postcss\.config)' || true)

  echo "$files"
}

# ---------------------------------------------------------------------------
# 1. Check if state file exists and is valid JSON
# ---------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]] || ! jq empty "$STATE_FILE" 2>/dev/null; then
  set_full_mode "no valid state file found"
  exit 0
fi

echo "Found valid state file: ${STATE_FILE}"

# ---------------------------------------------------------------------------
# 2. Check event action — only synchronize (or reopened with state) can be incremental
# ---------------------------------------------------------------------------
if [[ "$EVENT_ACTION" != "synchronize" ]] && [[ "$EVENT_ACTION" != "reopened" ]]; then
  set_full_mode "event action is ${EVENT_ACTION}"
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Validate BEFORE_SHA is not all zeros (new ref / first push)
# ---------------------------------------------------------------------------
if [[ "$BEFORE_SHA" =~ ^0+$ ]]; then
  set_full_mode "BEFORE_SHA is all zeros (new ref)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. Force push / rebase detection
# ---------------------------------------------------------------------------
if ! git merge-base --is-ancestor "$BEFORE_SHA" "$AFTER_SHA" 2>/dev/null; then
  set_full_mode_with_state "force push detected (BEFORE_SHA not ancestor of AFTER_SHA)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. Extract last reviewed SHA from state file
# ---------------------------------------------------------------------------
LAST_REVIEWED_SHA=$(jq -r '.reviews[-1].commit_sha // empty' "$STATE_FILE")

if [[ -z "$LAST_REVIEWED_SHA" ]]; then
  set_full_mode "state file has no review rounds"
  exit 0
fi

# Verify the last reviewed SHA exists in the history
if ! git cat-file -e "$LAST_REVIEWED_SHA" 2>/dev/null; then
  set_full_mode_with_state "last reviewed SHA ${LAST_REVIEWED_SHA} not found in history"
  exit 0
fi

CURRENT_ROUND=$(jq '.reviews | length' "$STATE_FILE")
NEXT_ROUND=$((CURRENT_ROUND + 1))

echo "Last reviewed SHA: ${LAST_REVIEWED_SHA}"
echo "Current round: ${CURRENT_ROUND}, next round: ${NEXT_ROUND}"

# ---------------------------------------------------------------------------
# 6. Compute diff from last reviewed SHA to HEAD
# ---------------------------------------------------------------------------
echo "Computing diff (${LAST_REVIEWED_SHA}..HEAD)..."
ALL_DIFF_FILES=$(git diff --name-only "${LAST_REVIEWED_SHA}..HEAD" 2>/dev/null || true)
CODE_DIFF_FILES=$(filter_code_files "$ALL_DIFF_FILES")

# Convert to JSON array
CODE_DIFF_ARRAY=$(echo "$CODE_DIFF_FILES" | grep -v '^$' | jq -R -s 'split("\n") | map(select(length > 0))')
DIFF_COUNT=$(echo "$CODE_DIFF_ARRAY" | jq 'length')

echo "Code files changed since last review: ${DIFF_COUNT}"

if [[ "$DIFF_COUNT" -eq 0 ]]; then
  echo "No code files changed. Checking if there are open issues to carry forward..."
  OPEN_COUNT=$(jq '[.issues | to_entries[] | select(.value.status == "open")] | length' "$STATE_FILE")
  if [[ "$OPEN_COUNT" -gt 0 ]]; then
    echo "No code changes but ${OPEN_COUNT} open issues remain. Short-circuit incremental."
  else
    echo "No code changes and no open issues."
  fi
fi

# ---------------------------------------------------------------------------
# 7. Get all unique file paths referenced by issues in the state file
# ---------------------------------------------------------------------------
ISSUE_FILE_PATHS=$(jq '[.issues | to_entries[] | .value.path] | unique' "$STATE_FILE")

# ---------------------------------------------------------------------------
# 8. Classify files into buckets
# ---------------------------------------------------------------------------

# Files with open or fixed issues that were touched in this diff
FILES_FOR_VERIFICATION=$(jq -n \
  --argjson issue_paths "$ISSUE_FILE_PATHS" \
  --argjson diff_files "$CODE_DIFF_ARRAY" \
  '[$diff_files[] | select(. as $f | $issue_paths | index($f) != null)]')

# Files in diff that have NO issues in state (completely new to review)
FILES_FOR_NEW_DETECTION=$(jq -n \
  --argjson issue_paths "$ISSUE_FILE_PATHS" \
  --argjson diff_files "$CODE_DIFF_ARRAY" \
  '[$diff_files[] | select(. as $f | $issue_paths | index($f) == null)]')

# Detect deleted files: files referenced by issues that no longer exist on disk
DELETED_FILES='[]'
for file in $(echo "$ISSUE_FILE_PATHS" | jq -r '.[]'); do
  if [[ ! -f "$file" ]]; then
    DELETED_FILES=$(echo "$DELETED_FILES" | jq --arg f "$file" '. + [$f]')
    echo "  Detected deleted file: ${file}"
  fi
done

# Open issues on files NOT in the diff (carry forward as-is)
UNTOUCHED_OPEN_ISSUES=$(jq -c --argjson diff_files "$CODE_DIFF_ARRAY" --argjson deleted "$DELETED_FILES" '
  [.issues | to_entries[] |
    select(.value.status == "open") |
    select(.value.path as $p | ($diff_files | index($p)) == null) |
    select(.value.path as $p | ($deleted | index($p)) == null) |
    {id: .key} + .value
  ]
' "$STATE_FILE")

# Open issues on files that WERE touched (for verification)
OPEN_ISSUES_ON_TOUCHED=$(jq -c --argjson verif_files "$FILES_FOR_VERIFICATION" '
  [.issues | to_entries[] |
    select(.value.status == "open") |
    select(.value.path as $p | ($verif_files | index($p)) != null) |
    {id: .key} + .value
  ]
' "$STATE_FILE")

# Fixed issues on files that were touched (for regression check)
FIXED_ISSUES_ON_TOUCHED=$(jq -c --argjson verif_files "$FILES_FOR_VERIFICATION" '
  [.issues | to_entries[] |
    select(.value.status == "fixed") |
    select(.value.path as $p | ($verif_files | index($p)) != null) |
    {id: .key} + .value
  ]
' "$STATE_FILE")

# Open issues on deleted files (to be auto-fixed)
OPEN_ISSUES_ON_DELETED=$(jq -c --argjson deleted "$DELETED_FILES" '
  [.issues | to_entries[] |
    select(.value.status == "open") |
    select(.value.path as $p | ($deleted | index($p)) != null) |
    {id: .key} + .value
  ]
' "$STATE_FILE")

# ---------------------------------------------------------------------------
# 9. Log summary
# ---------------------------------------------------------------------------
VERIF_COUNT=$(echo "$FILES_FOR_VERIFICATION" | jq 'length')
NEW_DETECT_COUNT=$(echo "$FILES_FOR_NEW_DETECTION" | jq 'length')
DELETED_COUNT=$(echo "$DELETED_FILES" | jq 'length')
UNTOUCHED_OPEN_COUNT=$(echo "$UNTOUCHED_OPEN_ISSUES" | jq 'length')
OPEN_ON_TOUCHED_COUNT=$(echo "$OPEN_ISSUES_ON_TOUCHED" | jq 'length')
FIXED_ON_TOUCHED_COUNT=$(echo "$FIXED_ISSUES_ON_TOUCHED" | jq 'length')
DELETED_ISSUES_COUNT=$(echo "$OPEN_ISSUES_ON_DELETED" | jq 'length')

echo ""
echo "=============================="
echo "  Incremental Review Summary"
echo "=============================="
echo "  Round:                    ${NEXT_ROUND}"
echo "  Code files in diff:       ${DIFF_COUNT}"
echo "  Files for verification:   ${VERIF_COUNT}"
echo "  Files for new detection:  ${NEW_DETECT_COUNT}"
echo "  Deleted files:            ${DELETED_COUNT}"
echo "  Open issues (touched):    ${OPEN_ON_TOUCHED_COUNT}"
echo "  Fixed issues (touched):   ${FIXED_ON_TOUCHED_COUNT}"
echo "  Open issues (untouched):  ${UNTOUCHED_OPEN_COUNT}"
echo "  Issues on deleted files:  ${DELETED_ISSUES_COUNT}"
echo "=============================="
echo ""

# ---------------------------------------------------------------------------
# 10. Write review-context.json and output review_mode
# ---------------------------------------------------------------------------
jq -n \
  --arg review_mode "incremental" \
  --arg state_file "$STATE_FILE" \
  --argjson round "$NEXT_ROUND" \
  --arg last_reviewed_sha "$LAST_REVIEWED_SHA" \
  --argjson files_for_verification "$FILES_FOR_VERIFICATION" \
  --argjson files_for_new_detection "$FILES_FOR_NEW_DETECTION" \
  --argjson deleted_files "$DELETED_FILES" \
  --argjson untouched_open_issues "$UNTOUCHED_OPEN_ISSUES" \
  --argjson open_issues_on_touched "$OPEN_ISSUES_ON_TOUCHED" \
  --argjson fixed_issues_on_touched "$FIXED_ISSUES_ON_TOUCHED" \
  --argjson open_issues_on_deleted "$OPEN_ISSUES_ON_DELETED" \
  --argjson force_push false \
  '{
    review_mode: $review_mode,
    state_file: $state_file,
    round: $round,
    last_reviewed_sha: $last_reviewed_sha,
    files_for_verification: $files_for_verification,
    files_for_new_detection: $files_for_new_detection,
    deleted_files: $deleted_files,
    untouched_open_issues: $untouched_open_issues,
    open_issues_on_touched: $open_issues_on_touched,
    fixed_issues_on_touched: $fixed_issues_on_touched,
    open_issues_on_deleted: $open_issues_on_deleted,
    force_push_detected: $force_push
  }' > review-context.json

echo "review_mode=incremental" >> "$GITHUB_OUTPUT"
echo "Review mode: INCREMENTAL"
