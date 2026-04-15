#!/usr/bin/env bash
# cleanup-prior-reviews.sh
# Dismiss prior REQUEST_CHANGES reviews and minimize old inline comments
# from previous runs of the PR Code Review Validator.
#
# Required env vars: GH_TOKEN, PR_NUMBER, REPO

set -uo pipefail

MARKER="<!-- pr-code-review-validator -->"
BOT_LOGIN="github-actions[bot]"

# ---------------------------------------------------------------------------
# Retry helper — exponential backoff (3 attempts: 1s, 2s, 4s)
# ---------------------------------------------------------------------------
retry() {
  local max_attempts=3
  local delay=1
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if (( attempt >= max_attempts )); then
      echo "::warning::Command failed after ${max_attempts} attempts: $*"
      return 1
    fi
    echo "  Retry ${attempt}/${max_attempts} in ${delay}s..."
    sleep "$delay"
    delay=$(( delay * 2 ))
    attempt=$(( attempt + 1 ))
  done
}

# ---------------------------------------------------------------------------
# 1. Dismiss prior REQUEST_CHANGES reviews
# ---------------------------------------------------------------------------
echo "Cleaning up prior reviews..."

REVIEWS=$(retry gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews" --paginate 2>/dev/null) || {
  echo "::warning::Could not fetch reviews — skipping cleanup"
  exit 0
}

echo "$REVIEWS" | jq -c '.[]' 2>/dev/null | while IFS= read -r review; do
  author=$(echo "$review" | jq -r '.user.login // empty')
  state=$(echo "$review" | jq -r '.state // empty')
  body=$(echo "$review" | jq -r '.body // empty')
  review_id=$(echo "$review" | jq -r '.id // empty')

  if [[ "$author" == "$BOT_LOGIN" ]] && [[ "$body" == *"$MARKER"* ]] && [[ "$state" == "CHANGES_REQUESTED" ]]; then
    echo "  Dismissing review #${review_id}..."
    retry gh api "repos/${REPO}/pulls/${PR_NUMBER}/reviews/${review_id}/dismissals" \
      --method PUT \
      --field message="Superseded by new review run" \
      2>/dev/null || echo "::warning::Failed to dismiss review #${review_id}"
  fi
done

# ---------------------------------------------------------------------------
# 2. Minimize prior inline comments
# ---------------------------------------------------------------------------
echo "Cleaning up prior inline comments..."

COMMENTS=$(retry gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments" --paginate 2>/dev/null) || {
  echo "::warning::Could not fetch comments — skipping comment cleanup"
  exit 0
}

echo "$COMMENTS" | jq -c '.[]' 2>/dev/null | while IFS= read -r comment; do
  author=$(echo "$comment" | jq -r '.user.login // empty')
  body=$(echo "$comment" | jq -r '.body // empty')
  node_id=$(echo "$comment" | jq -r '.node_id // empty')

  if [[ "$author" == "$BOT_LOGIN" ]] && [[ "$body" == *"$MARKER"* ]] && [[ -n "$node_id" ]]; then
    echo "  Minimizing comment ${node_id}..."
    retry gh api graphql \
      --field query="mutation { minimizeComment(input: { subjectId: \"${node_id}\", classifier: OUTDATED }) { minimizedComment { isMinimized } } }" \
      2>/dev/null || echo "::warning::Failed to minimize comment ${node_id}"
  fi
done

echo "Cleanup complete."
