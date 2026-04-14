---
name: Protected branches in this repo
description: main and develop are protected — no direct commits or pushes allowed per Git Flow
type: project
---

Protected branches: `main`, `develop`.

**Why:** Git Flow requires all work to happen on dedicated branches (feature/*, hotfix/*, bugfix/*, release/*, support/*) and merge via pull requests.

**How to apply:** Block `git add`, `git commit`, and `git push` when on `main` or `develop`. Direct force pushes are always forbidden. Merges must go through PRs.
