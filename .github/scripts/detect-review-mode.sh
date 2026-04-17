#!/usr/bin/env bash
# detect-review-mode.sh
# Determines whether this PR review should be FULL or INCREMENTAL.
# Reads persistent state from .github/pr/pr-{number}.json instead of
# parsing GitHub review comments. Outputs review-context.json for the
# pipeline to consume.
#
# Required env vars: GH_TOKEN, PR_NUMBER, REPO, EVENT_ACTION, BEFORE_SHA, AFTER_SHA
# Outputs: review_mode (full|incremental) via $GITHUB_OUTPUT

set -uo pipefail

MARKER="<!-- pr-code-review-validator -->"
STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"

# ---------------------------------------------------------------------------
# Helper: output review_mode=full and write minimal review-context.json
# ---------------------------------------------------------------------------
set_full_mode() {
  local reason="${1:-unspecified}"
  echo "Review mode: FULL (reason: ${reason})"
  echo "review_mode=full" >> "$GITHUB_OUTPUT"
  jq -n --arg reason "$reason" '{"review_mode":"full","reason":$reason}' > review-context.json
}

# ---------------------------------------------------------------------------
# 1. Check event action — only synchronize can be incremental
# ---------------------------------------------------------------------------
if [[ "$EVENT_ACTION" != "synchronize" ]]; then
  set_full_mode "event action is ${EVENT_ACTION}, not synchronize"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Validate BEFORE_SHA is not all zeros (new ref / first push)
# ---------------------------------------------------------------------------
if [[ "$BEFORE_SHA" =~ ^0+$ ]]; then
  set_full_mode "BEFORE_SHA is all zeros (new ref)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Check ancestry — force push / rebase detection
# ---------------------------------------------------------------------------
if ! git merge-base --is-ancestor "$BEFORE_SHA" "$AFTER_SHA" 2>/dev/null; then
  set_full_mode "BEFORE_SHA is not ancestor of AFTER_SHA (force push or rebase)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. Read state file
# ---------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]]; then
  set_full_mode "no state file found"
  exit 0
fi

if ! jq empty "$STATE_FILE" 2>/dev/null; then
  set_full_mode "state file is malformed JSON"
  exit 0
fi

echo "Reading state from ${STATE_FILE}..."

# ---------------------------------------------------------------------------
# 5. Extract open and fixed issues from state
# ---------------------------------------------------------------------------
OPEN_ISSUES=$(jq -c '[.issues | to_entries[] | select(.value.status == "open") | .value + {id: .key}]' "$STATE_FILE")
FIXED_ISSUES=$(jq -c '[.issues | to_entries[] | select(.value.status == "fixed") | .value + {id: .key}]' "$STATE_FILE")
LAST_COMMIT=$(jq -r '.reviews[-1].commit_sha // empty' "$STATE_FILE")
ROUND=$(jq '.reviews | length' "$STATE_FILE")

OPEN_COUNT=$(echo "$OPEN_ISSUES" | jq 'length')
FIXED_COUNT=$(echo "$FIXED_ISSUES" | jq 'length')

echo "State: round ${ROUND}, ${OPEN_COUNT} open issues, ${FIXED_COUNT} fixed issues"
echo "Last reviewed commit: ${LAST_COMMIT:-unknown}"

# ---------------------------------------------------------------------------
# 6. Compute incremental diff from last reviewed commit
# ---------------------------------------------------------------------------
DIFF_BASE="${LAST_COMMIT:-$BEFORE_SHA}"

echo "Computing incremental diff (${DIFF_BASE}..HEAD)..."
INCREMENTAL_FILES=$(git diff --name-only "${DIFF_BASE}..HEAD" 2>/dev/null || true)

# Filter to code files only
INCREMENTAL_CODE_FILES=$(echo "$INCREMENTAL_FILES" | grep -E '\.(ts|tsx|js|jsx|prisma|sql)$' || true)

# Exclude non-code directories
INCREMENTAL_CODE_FILES=$(echo "$INCREMENTAL_CODE_FILES" | grep -vE '^(node_modules/|\.next/|\.git/|dist/|build/|coverage/|\.claude/|\.github/|\.husky/|spec/|examples/|templates-example/|chrome-dev-tools/|public/|scripts/)' || true)

# Exclude config files
INCREMENTAL_CODE_FILES=$(echo "$INCREMENTAL_CODE_FILES" | grep -vE '(package\.json|package-lock\.json|tsconfig\.json|jest\.config|jest\.setup|\.eslintrc|next\.config|tailwind\.config|prettier\.config|postcss\.config)' || true)

# Convert to JSON array
INCREMENTAL_ARRAY=$(echo "$INCREMENTAL_CODE_FILES" | grep -v '^$' | jq -R -s 'split("\n") | map(select(length > 0))')

INCREMENTAL_COUNT=$(echo "$INCREMENTAL_ARRAY" | jq 'length')
echo "Incremental code files: ${INCREMENTAL_COUNT}"

# ---------------------------------------------------------------------------
# 7. Cross-reference issues with changed files
# ---------------------------------------------------------------------------

# Get unique paths from all issues (open + fixed)
ALL_ISSUE_PATHS=$(jq -c '[.issues | to_entries[] | .value.path] | unique' "$STATE_FILE")

# Open issues on touched files (need verification)
OPEN_ON_TOUCHED=$(echo "$OPEN_ISSUES" | jq -c --argjson incr "$INCREMENTAL_ARRAY" '
  [.[] | select(.path as $p | $incr | index($p) != null)]
')

# Fixed issues on touched files (need regression check)
FIXED_ON_TOUCHED=$(echo "$FIXED_ISSUES" | jq -c --argjson incr "$INCREMENTAL_ARRAY" '
  [.[] | select(.path as $p | $incr | index($p) != null)]
')

# Detect deleted files in the diff
DELETED_FILES='[]'
for file in $(echo "$INCREMENTAL_ARRAY" | jq -r '.[]'); do
  if [[ ! -f "$file" ]]; then
    DELETED_FILES=$(echo "$DELETED_FILES" | jq --arg f "$file" '. + [$f]')
  fi
done

# New files: in incremental diff but not referenced by any issue
NEW_FILES=$(jq -n \
  --argjson all_paths "$ALL_ISSUE_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$incr[] | select(. as $p | $all_paths | index($p) == null)]')

# Touched files: files in diff that ARE referenced by issues
TOUCHED_FILES=$(jq -n \
  --argjson all_paths "$ALL_ISSUE_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$incr[] | select(. as $p | $all_paths | index($p) != null)]')

# Files to validate in Part B = new files only (touched files go through verification)
FILES_TO_VALIDATE_B=$(echo "$NEW_FILES" | jq -c '.')

# ---------------------------------------------------------------------------
# 8. Log summary
# ---------------------------------------------------------------------------
OPEN_ON_TOUCHED_COUNT=$(echo "$OPEN_ON_TOUCHED" | jq 'length')
FIXED_ON_TOUCHED_COUNT=$(echo "$FIXED_ON_TOUCHED" | jq 'length')
DELETED_COUNT=$(echo "$DELETED_FILES" | jq 'length')
NEW_COUNT=$(echo "$NEW_FILES" | jq 'length')
TOUCHED_COUNT=$(echo "$TOUCHED_FILES" | jq 'length')

echo ""
echo "=============================="
echo "  Incremental Review Summary"
echo "=============================="
echo "  Open issues total:              ${OPEN_COUNT}"
echo "  Open issues on touched files:   ${OPEN_ON_TOUCHED_COUNT}"
echo "  Fixed issues on touched files:  ${FIXED_ON_TOUCHED_COUNT}"
echo "  Deleted files:                  ${DELETED_COUNT}"
echo "  Touched files (with issues):    ${TOUCHED_COUNT}"
echo "  New files to validate:          ${NEW_COUNT}"
echo "=============================="
echo ""

# ---------------------------------------------------------------------------
# 9. Write review-context.json and output review_mode
# ---------------------------------------------------------------------------
jq -n \
  --arg review_mode "incremental" \
  --argjson round "$((ROUND + 1))" \
  --arg state_file "$STATE_FILE" \
  --arg last_reviewed_commit "$DIFF_BASE" \
  --argjson open_issues_to_verify "$OPEN_ON_TOUCHED" \
  --argjson fixed_issues_to_check_regression "$FIXED_ON_TOUCHED" \
  --argjson deleted_files "$DELETED_FILES" \
  --argjson new_files_to_validate "$FILES_TO_VALIDATE_B" \
  --argjson touched_files "$TOUCHED_FILES" \
  --argjson all_incremental_files "$INCREMENTAL_ARRAY" \
  '{
    review_mode: $review_mode,
    round: $round,
    state_file: $state_file,
    last_reviewed_commit: $last_reviewed_commit,
    open_issues_to_verify: $open_issues_to_verify,
    fixed_issues_to_check_regression: $fixed_issues_to_check_regression,
    deleted_files: $deleted_files,
    new_files_to_validate: $new_files_to_validate,
    touched_files: $touched_files,
    all_incremental_files: $all_incremental_files
  }' > review-context.json

echo "review_mode=incremental" >> "$GITHUB_OUTPUT"
echo "Review mode: INCREMENTAL"
