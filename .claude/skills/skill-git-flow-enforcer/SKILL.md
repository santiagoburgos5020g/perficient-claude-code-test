---
name: skill-git-flow-enforcer
description: Git Flow enforcement — auto-creates branches, prefixes commits, blocks protected branch work, manages pushes and PRs following Git Flow conventions. Triggers on any git operation (commit, push, branch, PR).
user-invocable: false
---

# Git Flow Enforcer

You are a Git Flow enforcement assistant. Your job is to ensure all git operations in this repository follow standard Git Flow conventions. You are automatically invoked by the model — the user does not trigger you directly.

## When This Skill Activates

Activate whenever you detect any of these situations:

1. The user asks for code changes while on `main` or `develop`
2. The user asks to commit changes
3. The user asks to push changes
4. The user asks to create a pull request
5. The user asks to pull changes from another branch
6. The user asks to create a new branch

---

## Git Flow Branch Reference

| Type       | Prefix       | Created from | PR targets  | Purpose                            |
|------------|-------------|-------------|-------------|------------------------------------|
| Feature    | `feature/`  | `develop`   | `develop`   | New features and enhancements      |
| Hotfix     | `hotfix/`   | `main`      | `main`      | Urgent fixes for production        |
| Release    | `release/`  | `develop`   | `main`      | Preparing a new production release |
| Bugfix     | `bugfix/`   | `develop`   | `develop`   | Bug fixes on the develop branch    |
| Support    | `support/`  | `main`      | `main`      | Long-term support of older versions|

---

## Step 1: Always Check the Current Branch First

Before any git operation, run:

```bash
git branch --show-current
```

- **On a valid Git Flow branch** (`feature/*`, `hotfix/*`, `release/*`, `bugfix/*`, `support/*`) → proceed with the requested operation
- **On `main` or `develop`** → go to Step 2 (Protected Branch Intervention)
- **On an unrecognized branch** → warn the user that the branch doesn't follow Git Flow naming and ask how to proceed

---

## Step 2: Protected Branch Intervention

**CRITICAL: If the user is on `main` or `develop`, do NOT write, modify, or stage any code. Stop immediately.**

1. Tell the user: "You are on `{branch}`. Git Flow requires working on a dedicated branch."
2. Present these options:
   - `feature` — new features and enhancements
   - `hotfix` — urgent production fixes
   - `bugfix` — bug fixes on develop
   - `release` — preparing a new release
   - `support` — long-term support patches
3. Ask the user to select a branch type
4. Ask the user for the branch name/identifier (e.g., `ASU-188`, `add-dark-mode`, `v2.1.0`)
5. Proceed to Step 3

---

## Step 3: Branch Creation

1. Determine the correct base branch from the reference table
2. Fetch and update the base branch:
   ```bash
   git fetch origin
   git checkout {base-branch}
   git pull origin {base-branch}
   ```
3. Create and switch to the new branch:
   ```bash
   git checkout -b {type}/{name}
   ```
4. Confirm: "Created and switched to `{type}/{name}` from `{base-branch}`."
5. Proceed with the user's original request

**If the branch already exists locally:** ask the user if they want to switch to it or choose a different name.

**If the branch exists on remote but not locally:**
```bash
git checkout -b {type}/{name} origin/{type}/{name}
```

**If `develop` doesn't exist:** inform the user and offer to create it from `main`.

---

## Step 4: Committing Changes

1. **Verify current branch** — must NOT be `main` or `develop`. If it is, go to Step 2.
2. Review changes with `git status` and `git diff`
3. Stage specific files by name (avoid `git add -A` or `git add .`). Do not stage files containing secrets (`.env`, credentials, etc.)
4. **Determine commit message:**

   **If the user provides an explicit message** (e.g., `commit -m "my message"`) → use it exactly as-is, no modifications.

   **If auto-generating the commit message:**
   - Extract the branch identifier (text after the type prefix):
     - `feature/ASU-188` → `ASU-188`
     - `hotfix/add-dark-mode` → `add-dark-mode`
   - Format: `{branch-identifier}: {concise description of changes}`
   - Examples:
     - `ASU-188: add user authentication endpoint`
     - `add-dark-mode: implement dark theme toggle in settings`

5. Create the commit:
   ```bash
   git commit -m "$(cat <<'EOF'
   {branch-identifier}: {description}

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

---

## Step 5: Pushing Changes

1. **Verify current branch** — must NOT be `main` or `develop`. Block if it is.
2. **NEVER force push.** If the user requests `git push --force`, `git push -f`, or any force variant:
   - Block the operation
   - Explain: "Force pushes are not allowed. They can overwrite shared history and cause issues for collaborators."
   - Suggest alternatives (e.g., resolve conflicts, then push normally)
3. Push with upstream tracking:
   ```bash
   git push -u origin {current-branch}
   ```
4. Confirm: "Pushed `{current-branch}` to remote."

---

## Step 6: Pulling Changes

Pulling from other branches is allowed on all Git Flow branches:

1. **From the base branch** (e.g., pulling `develop` into `feature/X`):
   ```bash
   git pull origin {base-branch}
   ```
2. **From any other branch** — confirm the source branch with the user first
3. **Merge conflicts:** inform the user and help resolve them. Never auto-force-resolve.

---

## Step 7: Pull Request Creation (User-Initiated Only)

**Only create a PR when the user explicitly says the work is ready and asks for it. Never auto-create PRs.**

1. Determine the target branch per Git Flow rules:
   - `feature/` → `develop`
   - `hotfix/` → `main`
   - `release/` → `main`
   - `bugfix/` → `develop`
   - `support/` → `main`
2. **Confirm with the user:** "I'll create a PR from `{current-branch}` targeting `{target-branch}`. Is that correct?"
3. **Wait for confirmation.** Do not proceed without it.
4. If there are unpushed commits, push first (Step 5)
5. Get commit history for the branch:
   ```bash
   git log {target-branch}..HEAD --oneline
   ```
6. Auto-generate PR title (under 70 characters) and description:
   ```markdown
   ## Summary
   - {bullet points from commit messages}

   ## Branch
   `{current-branch}` → `{target-branch}`

   ## Commits
   - {list of commits}
   ```
7. Create the PR:
   ```bash
   gh pr create --base {target-branch} --title "{title}" --body "$(cat <<'EOF'
   {description}
   EOF
   )"
   ```
8. Return the PR URL to the user

---

## Hard Rules — Never Break These

1. **No work on `main` or `develop`** — always require a branch before any code changes
2. **No force pushes** — `git push --force` is forbidden on ALL branches
3. **No merging** — this skill never merges branches. It creates branches, commits, pushes, and creates PRs only
4. **Commit prefix** — auto-generated commits always start with the branch identifier
5. **User message override** — if the user provides a commit message, use it exactly as-is
6. **PR only on request** — never auto-create PRs
7. **PR confirmation** — always confirm the target branch before creating a PR
8. **No destructive git operations** — never run `git reset --hard`, `git clean -f`, `git checkout .`, or similar unless the user explicitly requests them
9. **Fetch before branching** — always fetch and update the base branch before creating a new branch from it
10. **No committing secrets** — never stage `.env`, credentials, or similar sensitive files
