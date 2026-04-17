#!/usr/bin/env bash
# detect-review-mode.sh
# Determines whether this PR review should be FULL or INCREMENTAL.
# On incremental mode, extracts prior findings into prior-findings.json
# so the pipeline can carry forward untouched violations and only
# re-validate changed files.
#
# Required env vars: GH_TOKEN, PR_NUMBER, REPO, EVENT_ACTION, BEFORE_SHA, AFTER_SHA
# Outputs: review_mode (full|incremental) via $GITHUB_OUTPUT

set -uo pipefail

MARKER="<!-- pr-code-review-validator -->"
BOT_LOGIN="github-actions[bot]"

# ---------------------------------------------------------------------------
# Helper: output review_mode and write minimal prior-findings.json for full mode
# ---------------------------------------------------------------------------
set_full_mode() {
  local reason="${1:-unspecified}"
  echo "Review mode: FULL (reason: ${reason})"
  echo "review_mode=full" >> "$GITHUB_OUTPUT"
  jq -n '{"review_mode":"full"}' > prior-findings.json
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
# 4. Fetch the most recent bot review with our marker
# ---------------------------------------------------------------------------
echo "Fetching prior bot reviews..."
REVIEWS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews" --paginate 2>/dev/null) || {
  set_full_mode "could not fetch reviews"
  exit 0
}

# Find the most recent CHANGES_REQUESTED or DISMISSED review from the bot with
# our marker. DISMISSED reviews were previously CHANGES_REQUESTED but got
# dismissed by cleanup — they still contain valid violation data and resolved
# history needed for incremental mode.
# Sort by submitted_at descending and take the first.
PRIOR_REVIEW=$(echo "$REVIEWS" | jq -c --arg bot "$BOT_LOGIN" --arg marker "$MARKER" '
  [ .[] | select(
    .user.login == $bot and
    (.body | contains($marker)) and
    (.state == "CHANGES_REQUESTED" or .state == "DISMISSED")
  )] | sort_by(.submitted_at) | reverse | .[0] // empty
')

if [[ -z "$PRIOR_REVIEW" ]]; then
  set_full_mode "no prior CHANGES_REQUESTED bot review found"
  exit 0
fi

PRIOR_REVIEW_ID=$(echo "$PRIOR_REVIEW" | jq -r '.id')
PRIOR_BODY=$(echo "$PRIOR_REVIEW" | jq -r '.body // empty')

echo "Found prior review #${PRIOR_REVIEW_ID}"

# ---------------------------------------------------------------------------
# 5. Check if prior review had violations (VIOLATIONS FOUND in body)
# ---------------------------------------------------------------------------
if [[ "$PRIOR_BODY" != *"VIOLATIONS FOUND"* ]]; then
  set_full_mode "prior review did not contain violations (was pass/skip)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Fetch inline comments for that review
# ---------------------------------------------------------------------------
echo "Fetching inline comments for review #${PRIOR_REVIEW_ID}..."
REVIEW_COMMENTS=$(gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews/${PRIOR_REVIEW_ID}/comments" --paginate 2>/dev/null) || {
  set_full_mode "could not fetch review comments"
  exit 0
}

# Parse each comment: extract path, line, side, body, skill, rule
PRIOR_VIOLATIONS=$(echo "$REVIEW_COMMENTS" | jq -c --arg marker "$MARKER" '[
  .[] | select(.body | contains($marker)) |
  {
    path: .path,
    line: (.original_line // .line // 1),
    side: "RIGHT",
    body: .body,
    skill: (try (.body | capture("^\\*\\*(?<s>[^>]+)>") | .s | ltrimstr(" ") | rtrimstr(" ")) catch "unknown"),
    rule: (try (.body | capture("^\\*\\*[^>]+>\\s*(?<r>[^*]+)\\*\\*") | .r | ltrimstr(" ") | rtrimstr(" ")) catch "unknown")
  }
]')

PRIOR_COUNT=$(echo "$PRIOR_VIOLATIONS" | jq 'length')
echo "Found ${PRIOR_COUNT} prior inline violations"

if [[ "$PRIOR_COUNT" -eq 0 ]]; then
  set_full_mode "prior review had no parseable inline comments"
  exit 0
fi

# ---------------------------------------------------------------------------
# 6b. Extract resolved history from prior review body (if present)
# ---------------------------------------------------------------------------
PREVIOUSLY_RESOLVED=$(echo "$PRIOR_BODY" | grep -oP '(?<=<!-- resolved-history: ).*(?= -->)' | head -1)
if [[ -z "$PREVIOUSLY_RESOLVED" ]] || ! echo "$PREVIOUSLY_RESOLVED" | jq empty 2>/dev/null; then
  PREVIOUSLY_RESOLVED="[]"
fi
PREVIOUSLY_RESOLVED_COUNT=$(echo "$PREVIOUSLY_RESOLVED" | jq 'length')
echo "Previously resolved violations: ${PREVIOUSLY_RESOLVED_COUNT}"

# ---------------------------------------------------------------------------
# 7. Compute incremental diff (files changed in the new push only)
# ---------------------------------------------------------------------------
echo "Computing incremental diff (${BEFORE_SHA}..${AFTER_SHA})..."
INCREMENTAL_FILES=$(git diff --name-only "${BEFORE_SHA}..${AFTER_SHA}" 2>/dev/null || true)

# Filter to code files only (same patterns as run-review-pipeline.sh)
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
# 8. Cross-reference: which prior violations were touched vs untouched
# ---------------------------------------------------------------------------

# Get unique paths from prior violations
PRIOR_VIOLATION_PATHS=$(echo "$PRIOR_VIOLATIONS" | jq '[.[].path] | unique')

# Compute intersections
# touched_violation_files = prior violation paths that appear in incremental diff
TOUCHED_VIOLATION_FILES=$(jq -n \
  --argjson prior "$PRIOR_VIOLATION_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$prior[] | select(. as $p | $incr | index($p) != null)]')

# untouched_violation_files = prior violation paths NOT in incremental diff
# Also exclude files that were deleted (no longer exist in the repo)
UNTOUCHED_VIOLATION_FILES=$(jq -n \
  --argjson prior "$PRIOR_VIOLATION_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$prior[] | select(. as $p | $incr | index($p) == null)]')

# Filter out deleted files from untouched list
UNTOUCHED_EXISTING='[]'
for file in $(echo "$UNTOUCHED_VIOLATION_FILES" | jq -r '.[]'); do
  if [[ -f "$file" ]]; then
    UNTOUCHED_EXISTING=$(echo "$UNTOUCHED_EXISTING" | jq --arg f "$file" '. + [$f]')
  else
    echo "  Skipping deleted file: ${file}"
  fi
done
UNTOUCHED_VIOLATION_FILES="$UNTOUCHED_EXISTING"

# new_paths = incremental files that had NO prior violations
NEW_PATHS=$(jq -n \
  --argjson prior "$PRIOR_VIOLATION_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$incr[] | select(. as $p | $prior | index($p) == null)]')

# carried_forward_violations = violations on untouched files (include verbatim)
CARRIED_FORWARD=$(echo "$PRIOR_VIOLATIONS" | jq -c --argjson untouched "$UNTOUCHED_VIOLATION_FILES" '
  [.[] | select(.path as $p | $untouched | index($p) != null)]
')

# touched_file_violations = prior violations on files that WERE touched (for diffing in re-validation)
TOUCHED_FILE_VIOLATIONS=$(echo "$PRIOR_VIOLATIONS" | jq -c --argjson touched "$TOUCHED_VIOLATION_FILES" '
  [.[] | select(.path as $p | $touched | index($p) != null)]
')

# files_to_validate = touched violation files + new paths
FILES_TO_VALIDATE=$(jq -n \
  --argjson touched "$TOUCHED_VIOLATION_FILES" \
  --argjson new_paths "$NEW_PATHS" \
  '$touched + $new_paths | unique')

# ---------------------------------------------------------------------------
# 9. Log summary
# ---------------------------------------------------------------------------
CARRIED_COUNT=$(echo "$CARRIED_FORWARD" | jq 'length')
TOUCHED_COUNT=$(echo "$TOUCHED_VIOLATION_FILES" | jq 'length')
NEW_COUNT=$(echo "$NEW_PATHS" | jq 'length')
VALIDATE_COUNT=$(echo "$FILES_TO_VALIDATE" | jq 'length')

echo ""
echo "=============================="
echo "  Incremental Review Summary"
echo "=============================="
echo "  Prior violations:       ${PRIOR_COUNT}"
echo "  Carried forward:        ${CARRIED_COUNT}"
echo "  Files re-validating:    ${TOUCHED_COUNT}"
echo "  New files to validate:  ${NEW_COUNT}"
echo "  Total to validate:      ${VALIDATE_COUNT}"
echo "=============================="
echo ""

# ---------------------------------------------------------------------------
# 10. Write prior-findings.json and output review_mode
# ---------------------------------------------------------------------------
jq -n \
  --arg review_mode "incremental" \
  --argjson prior_review_id "$PRIOR_REVIEW_ID" \
  --arg prior_verdict "fail" \
  --argjson prior_violations "$PRIOR_VIOLATIONS" \
  --argjson incremental_files "$INCREMENTAL_ARRAY" \
  --argjson touched_violation_files "$TOUCHED_VIOLATION_FILES" \
  --argjson untouched_violation_files "$UNTOUCHED_VIOLATION_FILES" \
  --argjson new_paths "$NEW_PATHS" \
  --argjson carried_forward_violations "$CARRIED_FORWARD" \
  --argjson touched_file_violations "$TOUCHED_FILE_VIOLATIONS" \
  --argjson previously_resolved "$PREVIOUSLY_RESOLVED" \
  --argjson files_to_validate "$FILES_TO_VALIDATE" \
  '{
    review_mode: $review_mode,
    prior_review_id: $prior_review_id,
    prior_verdict: $prior_verdict,
    prior_violations: $prior_violations,
    incremental_files: $incremental_files,
    touched_violation_files: $touched_violation_files,
    untouched_violation_files: $untouched_violation_files,
    new_paths: $new_paths,
    carried_forward_violations: $carried_forward_violations,
    touched_file_violations: $touched_file_violations,
    previously_resolved: $previously_resolved,
    files_to_validate: $files_to_validate
  }' > prior-findings.json

echo "review_mode=incremental" >> "$GITHUB_OUTPUT"
echo "Review mode: INCREMENTAL"
