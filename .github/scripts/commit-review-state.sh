#!/usr/bin/env bash
# commit-review-state.sh
# Auto-commits the JSON state file to the PR branch after review.
#
# Required env vars: PR_NUMBER, PR_BRANCH

set -uo pipefail

STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No state file to commit. Skipping."
  exit 0
fi

# Validate JSON before committing
if ! jq empty "$STATE_FILE" 2>/dev/null; then
  echo "::warning::State file is invalid JSON. Skipping commit."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

git add "$STATE_FILE"

if git diff --cached --quiet; then
  echo "No changes to review state file. Skipping commit."
  exit 0
fi

git commit -m "chore(review): update pr-${PR_NUMBER} review state [skip ci]"

echo "Pushing review state to ${PR_BRANCH}..."
git push origin HEAD:"refs/heads/${PR_BRANCH}"

echo "Review state committed and pushed."
