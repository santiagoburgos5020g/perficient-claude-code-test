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

| Type       | Prefix       | Created from             | PR targets                | Purpose                            |
|------------|-------------|--------------------------|---------------------------|------------------------------------|
| Feature    | `feature/`  | `develop`                | `develop`                 | New features and enhancements      |
| Hotfix     | `hotfix/`   | `main`                   | `main` **AND** `develop`  | Urgent fixes for production        |
| Release    | `release/`  | `develop`                | `main` **AND** `develop`  | Preparing a new production release |
| Bugfix     | `bugfix/`   | `develop` or `release/*` | same as source branch     | Bug fixes (non-production)         |
| Support    | `support/`  | `main`                   | N/A (long-lived)          | Long-term support of older versions|

### Branch-from-Main Restriction

**Only `hotfix/` and `support/` branches may be created from `main`.** All other branch types (`feature/`, `bugfix/`, `release/`) MUST be created from `develop` (or from a `release/*` branch in the case of `bugfix/`). If a user attempts to create a feature, bugfix, or release branch from `main`, **block it** and explain that they must branch from `develop` instead.

### Dual-Merge Branches (Hotfix & Release)

**Hotfix** and **Release** branches require merging into **TWO** targets:
- **Hotfix** → PR to `main` AND PR to `develop` (so the fix reaches both production and the integration branch)
- **Release** → PR to `main` AND PR to `develop` (so release changes like version bumps and last-minute fixes are not lost)

**Hotfix exception:** If a `release/*` branch currently exists when finishing a hotfix, the hotfix should merge into `main` and the **release branch** (instead of `develop` directly), because the release branch will eventually carry the fix into `develop`.

### Support Branches

Support branches are long-lived and do **not** have a standard "finish" merge target. They exist to maintain older major versions that still need patches but cannot upgrade to the current version. Hotfixes for a support line stay within that support branch.

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

Tell the user: "You are on `{branch}`. Git Flow requires working on a dedicated branch." Then proceed to Step 3 (Branch Creation).

---

## Step 3: Branch Creation — Mandatory Interactive Flow

**Every time a branch needs to be created, you MUST follow this interactive flow. No exceptions — even if the user's request implies a branch type or name, always confirm explicitly.**

### 3a. Ask for Branch Type

Present these options and ask the user to select one:
   - `feature` — new features and enhancements (from `develop`)
   - `hotfix` — urgent production fixes (from `main`)
   - `bugfix` — bug fixes (from `develop` or a `release/*` branch)
   - `release` — preparing a new release (from `develop`)
   - `support` — long-term support patches (from `main`)

**Wait for the user to confirm the branch type before proceeding.** Do not assume or skip this step.

**Enforce branch-from-main restriction:** If the user is currently on `main` and selects `feature`, `bugfix`, or `release`, **block** the creation and explain:
- `feature` and `release` must be created from `develop`.
- `bugfix` must be created from `develop` or a `release/*` branch.
- Only `hotfix` and `support` can be created from `main`.

### 3b. Ask for Branch Name

Ask the user: "What name/identifier should the branch have? (e.g., `ASU-188`, `add-dark-mode`, `v2.1.0`)"

**If the user provides a name:** use it.

**If the user does NOT provide a name** (e.g., says "I don't know", "you pick", "whatever", or simply doesn't specify one):
1. Generate a suggested name based on the context of what the user is trying to accomplish (e.g., `add-user-auth`, `fix-login-crash`, `v1.2.0`)
2. Present the suggestion: "I suggest: `{type}/{suggested-name}`. Would you like to use this name, or do you have a different one in mind?"
3. **Wait for the user to confirm or provide an alternative.** Do not proceed without explicit confirmation.

### 3c. Create the Branch

1. Determine the correct base branch from the reference table:
   - `feature` → `develop`
   - `hotfix` → `main`
   - `release` → `develop`
   - `bugfix` → `develop` (default) or a specific `release/*` branch if the user specifies. **Ask the user** if the bugfix is for a release branch or for develop.
   - `support` → `main`
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

### 7a. Determine PR target(s) per Git Flow rules

**Single-target branches:**
- `feature/` → `develop`
- `bugfix/` → the branch it was created from (`develop` or the specific `release/*` branch)
- `support/` → N/A (support branches are long-lived; PRs are not standard for them)

**Dual-target branches (require TWO PRs):**
- `hotfix/` → `main` **AND** `develop`
- `release/` → `main` **AND** `develop`

**Hotfix exception:** If a `release/*` branch currently exists, the second hotfix PR should target the `release/*` branch instead of `develop` (the release will eventually merge into develop).

To check for an active release branch:
```bash
git branch -r --list 'origin/release/*'
```

### 7b. Confirm with the user

**For single-target PRs:** "I'll create a PR from `{current-branch}` targeting `{target-branch}`. Is that correct?"

**For dual-target PRs:** "Git Flow requires TWO PRs for `{branch-type}` branches. I'll create:
1. PR from `{current-branch}` → `{first-target}` (primary)
2. PR from `{current-branch}` → `{second-target}` (back-merge)
Is that correct?"

**Wait for confirmation.** Do not proceed without it.

### 7c. Push and create PR(s)

1. If there are unpushed commits, push first (Step 5)
2. Get commit history for the branch:
   ```bash
   git log {target-branch}..HEAD --oneline
   ```
3. Auto-generate PR title (under 70 characters) and description:
   ```markdown
   ## Summary
   - {bullet points from commit messages}

   ## Branch
   `{current-branch}` → `{target-branch}`

   ## Commits
   - {list of commits}
   ```
4. Create the PR:
   ```bash
   gh pr create --base {target-branch} --title "{title}" --body "$(cat <<'EOF'
   {description}
   EOF
   )"
   ```
5. **For dual-target branches (hotfix/release):** Create the second PR targeting the second branch:
   ```bash
   gh pr create --base {second-target} --title "{title} (back-merge to {second-target})" --body "$(cat <<'EOF'
   ## Summary
   Back-merge of `{current-branch}` into `{second-target}` per Git Flow.

   ## Branch
   `{current-branch}` → `{second-target}`
   EOF
   )"
   ```
6. Return all PR URL(s) to the user

---

## Hard Rules — Never Break These

1. **No work on `main` or `develop`** — always require a branch before any code changes
2. **No force pushes** — `git push --force` is forbidden on ALL branches
3. **No merging** — this skill never merges branches. It creates branches, commits, pushes, and creates PRs only
4. **Commit prefix** — auto-generated commits always start with the branch identifier
5. **User message override** — if the user provides a commit message, use it exactly as-is
6. **PR only on request** — never auto-create PRs
7. **PR confirmation** — always confirm the target branch(es) before creating a PR
8. **No destructive git operations** — never run `git reset --hard`, `git clean -f`, `git checkout .`, or similar unless the user explicitly requests them
9. **Fetch before branching** — always fetch and update the base branch before creating a new branch from it
10. **No committing secrets** — never stage `.env`, credentials, or similar sensitive files
11. **Branch-from-main restriction** — only `hotfix/` and `support/` branches may be created from `main`. Block `feature/`, `bugfix/`, and `release/` from `main`.
12. **Dual PRs for hotfix and release** — `hotfix/` and `release/` branches always require TWO PRs: one to `main` and one to `develop` (or to the active `release/*` branch in the hotfix exception case)
13. **Bugfix source tracking** — `bugfix/` branches merge back to the branch they were created from (`develop` or the specific `release/*` branch), never to `main`
