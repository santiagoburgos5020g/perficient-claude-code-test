---
name: Branch-from-Main Restriction
description: When on main, only offer hotfix/ and support/ as branch options. Block feature/, bugfix/, and release/ from main — they must branch from develop.
type: feedback
---

**Only `hotfix/` and `support/` branches may be created from `main`.** When the user is on `main` and you present branch type options, you MUST:

1. **Only show `hotfix` and `support`** as valid choices — do NOT list `feature`, `bugfix`, or `release`.
2. If the user explicitly requests `feature`, `bugfix`, or `release` while on `main`, **block it immediately** and explain:
   - `feature/` and `release/` must be created from `develop`.
   - `bugfix/` must be created from `develop` or a `release/*` branch.
   - Only `hotfix/` and `support/` can branch from `main`.
3. Offer to switch to `develop` first if the user needs a `feature`, `bugfix`, or `release` branch.

**Why:** The agent was presenting all five branch types (including `feature`) when on `main`, which violates the Git Flow Branch-from-Main Restriction defined in SKILL.md (line 36) and Hard Rule #11 (line 281). This led to confusion and incorrect workflow options.

**How to apply:** In Step 3a (Ask for Branch Type), before presenting options, check the current branch. If on `main`, filter the list to only `hotfix` and `support`. If on `develop`, show `feature`, `bugfix`, and `release`. Never present an option that would violate the branch-from-main restriction.
