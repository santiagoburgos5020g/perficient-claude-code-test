#!/usr/bin/env bash
# commit-review-state.sh
# Auto-commits the PR review state JSON file to the PR branch.
# This enables persistent, incremental review tracking across pushes.
#
# Required env vars: PR_NUMBER, PR_BRANCH

set -uo pipefail

STATE_FILE=".github/pr/pr-${PR_NUMBER}.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No state file found at ${STATE_FILE} — nothing to commit."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

mkdir -p .github/pr

git add "$STATE_FILE"

if git diff --cached --quiet; then
  echo "No changes to review state file. Skipping commit."
  exit 0
fi

echo "Committing review state file: ${STATE_FILE}"
git commit -m "chore(review): update pr-${PR_NUMBER} review state [skip ci]"

if git push origin "${PR_BRANCH}"; then
  echo "State file committed and pushed successfully."
else
  echo "::warning::Failed to push state file. It will be recreated on the next run."
  exit 0
fi
