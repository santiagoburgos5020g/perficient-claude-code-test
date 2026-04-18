#!/usr/bin/env bash
# detect-review-mode.sh
# Determines whether this PR review should be FULL or INCREMENTAL.
# On incremental mode, reads the violations artifact from the prior run
# and computes two tracks: verification (Track 1) and full validation (Track 2).
#
# Required env vars: GH_TOKEN, PR_NUMBER, REPO, EVENT_ACTION, BEFORE_SHA, AFTER_SHA
# Optional env vars: FULL_REVIEW_LABEL, ARTIFACT_PATH
# Outputs: review_mode (full|incremental) via $GITHUB_OUTPUT

set -uo pipefail

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
# 1. Check for full-review label override
# ---------------------------------------------------------------------------
if [[ "${FULL_REVIEW_LABEL:-false}" == "true" ]]; then
  set_full_mode "full-review label detected"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Check event action — only synchronize can be incremental
# ---------------------------------------------------------------------------
if [[ "$EVENT_ACTION" != "synchronize" ]]; then
  set_full_mode "event action is ${EVENT_ACTION}, not synchronize"
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
# 4. Check ancestry — force push / rebase detection
# ---------------------------------------------------------------------------
if ! git merge-base --is-ancestor "$BEFORE_SHA" "$AFTER_SHA" 2>/dev/null; then
  set_full_mode "BEFORE_SHA is not ancestor of AFTER_SHA (force push or rebase)"
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. Check for prior violations artifact
# ---------------------------------------------------------------------------
ARTIFACT_FILE="${ARTIFACT_PATH:-.review-artifacts/violations.json}"

if [[ ! -f "$ARTIFACT_FILE" ]]; then
  set_full_mode "no prior violations artifact found"
  exit 0
fi

if ! jq empty "$ARTIFACT_FILE" 2>/dev/null; then
  set_full_mode "prior artifact is not valid JSON"
  exit 0
fi

PRIOR_VIOLATIONS=$(jq -c '.active_violations // []' "$ARTIFACT_FILE")
PRIOR_COUNT=$(echo "$PRIOR_VIOLATIONS" | jq 'length')
PRIOR_PUSH_COUNT=$(jq -r '.push_count // 0' "$ARTIFACT_FILE")

echo "Found prior artifact: ${PRIOR_COUNT} active violations, push #${PRIOR_PUSH_COUNT}"

if [[ "$PRIOR_COUNT" -eq 0 ]]; then
  set_full_mode "prior artifact has zero active violations"
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Compute incremental diff (files changed in the new push only)
# ---------------------------------------------------------------------------
echo "Computing incremental diff (${BEFORE_SHA}..${AFTER_SHA})..."
INCREMENTAL_FILES=$(git diff --name-only "${BEFORE_SHA}..${AFTER_SHA}" 2>/dev/null || true)

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
# 7. Compute two tracks
# ---------------------------------------------------------------------------
PRIOR_VIOLATION_PATHS=$(echo "$PRIOR_VIOLATIONS" | jq '[.[].path] | unique')

# Track 1: files with prior violations AND touched in this push
TRACK1_FILES=$(jq -n \
  --argjson prior "$PRIOR_VIOLATION_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$prior[] | select(. as $p | $incr | index($p) != null)]')

# Track 1 violations: the specific violations on those files
TRACK1_VIOLATIONS=$(echo "$PRIOR_VIOLATIONS" | jq -c --argjson track1 "$TRACK1_FILES" '
  [.[] | select(.path as $p | $track1 | index($p) != null)]')

# Track 2: files in this push with NO prior violations
TRACK2_FILES=$(jq -n \
  --argjson prior "$PRIOR_VIOLATION_PATHS" \
  --argjson incr "$INCREMENTAL_ARRAY" \
  '[$incr[] | select(. as $p | $prior | index($p) == null)]')

# Untouched violations: violations on files NOT in this push
UNTOUCHED_VIOLATIONS=$(echo "$PRIOR_VIOLATIONS" | jq -c --argjson incr "$INCREMENTAL_ARRAY" '
  [.[] | select(.path as $p | $incr | index($p) == null)]')

# Filter out deleted files from untouched violations
UNTOUCHED_EXISTING='[]'
for file in $(echo "$UNTOUCHED_VIOLATIONS" | jq -r '.[].path' | sort -u); do
  if [[ -f "$file" ]]; then
    FILE_VIOLATIONS=$(echo "$UNTOUCHED_VIOLATIONS" | jq -c --arg f "$file" '[.[] | select(.path == $f)]')
    UNTOUCHED_EXISTING=$(echo "$UNTOUCHED_EXISTING" | jq -c --argjson fv "$FILE_VIOLATIONS" '. + $fv')
  else
    echo "  Skipping deleted file: ${file}"
  fi
done
UNTOUCHED_VIOLATIONS="$UNTOUCHED_EXISTING"

# Also auto-resolve Track 1 violations on deleted files
TRACK1_EXISTING='[]'
for file in $(echo "$TRACK1_FILES" | jq -r '.[]'); do
  if [[ -f "$file" ]]; then
    FILE_VIOLATIONS=$(echo "$TRACK1_VIOLATIONS" | jq -c --arg f "$file" '[.[] | select(.path == $f)]')
    TRACK1_EXISTING=$(echo "$TRACK1_EXISTING" | jq -c --argjson fv "$FILE_VIOLATIONS" '. + $fv')
  else
    echo "  Auto-resolving violations on deleted file: ${file}"
  fi
done
TRACK1_VIOLATIONS="$TRACK1_EXISTING"
TRACK1_FILES=$(echo "$TRACK1_VIOLATIONS" | jq '[.[].path] | unique')

# ---------------------------------------------------------------------------
# 8. Log summary
# ---------------------------------------------------------------------------
TRACK1_COUNT=$(echo "$TRACK1_FILES" | jq 'length')
TRACK1_VIOLATION_COUNT=$(echo "$TRACK1_VIOLATIONS" | jq 'length')
TRACK2_COUNT=$(echo "$TRACK2_FILES" | jq 'length')
UNTOUCHED_COUNT=$(echo "$UNTOUCHED_VIOLATIONS" | jq 'length')

echo ""
echo "=============================="
echo "  Incremental Review Summary"
echo "=============================="
echo "  Prior violations:          ${PRIOR_COUNT}"
echo "  Track 1 (verify):          ${TRACK1_COUNT} files, ${TRACK1_VIOLATION_COUNT} violations"
echo "  Track 2 (full validate):   ${TRACK2_COUNT} files"
echo "  Untouched (carry forward): ${UNTOUCHED_COUNT} violations"
echo "=============================="
echo ""

# ---------------------------------------------------------------------------
# 9. Write prior-findings.json and output review_mode
# ---------------------------------------------------------------------------
PUSH_COUNT=$((PRIOR_PUSH_COUNT + 1))

jq -n \
  --arg review_mode "incremental" \
  --argjson push_count "$PUSH_COUNT" \
  --argjson track1_files "$TRACK1_FILES" \
  --argjson track1_violations "$TRACK1_VIOLATIONS" \
  --argjson track2_files "$TRACK2_FILES" \
  --argjson untouched_violations "$UNTOUCHED_VIOLATIONS" \
  '{
    review_mode: $review_mode,
    push_count: $push_count,
    track1_files: $track1_files,
    track1_violations: $track1_violations,
    track2_files: $track2_files,
    untouched_violations: $untouched_violations
  }' > prior-findings.json

echo "review_mode=incremental" >> "$GITHUB_OUTPUT"
echo "Review mode: INCREMENTAL"
