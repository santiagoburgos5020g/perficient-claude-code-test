# Skill Spec: Git Flow Enforcer (Opus 4.6 Reviewed)

## Overview

A skill that enforces Git Flow conventions across the entire git workflow — branch creation, commits, pushes, pull requests, and pulling changes. It is auto-invoked by the model whenever git operations are relevant and acts as a persistent guardrail to ensure the repository always follows standard Git Flow.

## Purpose

Prevent direct work on protected branches (`main`, `develop`) and ensure all git operations follow standard Git Flow conventions. The skill acts as both a proactive blocker (stopping forbidden operations before they happen) and a workflow assistant (guiding the user through correct Git Flow procedures for branching, committing, pushing, pulling, and PR creation).

## Trigger Conditions

- **Auto-invoked by the model** — the model must load this skill whenever it detects any of the following situations:
  1. The user asks for code changes, modifications, or new features while on `main` or `develop`
  2. The user asks to commit changes
  3. The user asks to push changes
  4. The user asks to create a pull request
  5. The user asks to pull changes from another branch
  6. The user asks to create a new branch
- **Not user-invocable** — this skill does not appear in the `/` menu
- **Proactive activation** — if the user is on `main` or `develop` and requests any code work, the skill must immediately intervene before any code changes are made

## Branch Types Supported

All standard Git Flow branch types:

| Type       | Prefix       | Created from | PR targets  | Purpose                              |
|------------|-------------|-------------|-------------|--------------------------------------|
| Feature    | `feature/`  | `develop`   | `develop`   | New features and enhancements        |
| Hotfix     | `hotfix/`   | `main`      | `main`      | Urgent fixes for production          |
| Release    | `release/`  | `develop`   | `main`      | Preparing a new production release   |
| Bugfix     | `bugfix/`   | `develop`   | `develop`   | Bug fixes on the develop branch      |
| Support    | `support/`  | `main`      | `main`      | Long-term support of older versions  |

## Workflow Steps

### Step 1: Current Branch Assessment

Before any git operation, always check the current branch:

```bash
git branch --show-current
```

- If on a valid Git Flow branch (`feature/*`, `hotfix/*`, `release/*`, `bugfix/*`, `support/*`) → proceed with the requested operation
- If on `main` or `develop` → activate protected branch intervention (Step 2)
- If on any other unrecognized branch → warn the user that the branch doesn't follow Git Flow naming and ask how they'd like to proceed

### Step 2: Protected Branch Intervention

When the user is on `main` or `develop` and requests code changes or git operations:

1. **Immediately stop** — do not write, modify, or stage any code
2. Inform the user: "You are on `{branch}`. Git Flow requires working on a dedicated branch."
3. Present the branch type options:
   - `feature` — for new features and enhancements
   - `hotfix` — for urgent production fixes
   - `bugfix` — for bug fixes on develop
   - `release` — for preparing a new release
   - `support` — for long-term support patches
4. Ask the user to select a branch type
5. Ask the user for the branch name/identifier (e.g., `ASU-188`, `add-dark-mode`, `v2.1.0`)
6. Proceed to Step 3 (Branch Creation)

### Step 3: Branch Creation

1. Determine the correct base branch from the table above
2. Ensure the base branch is up to date:
   ```bash
   git fetch origin
   git checkout {base-branch}
   git pull origin {base-branch}
   ```
3. Create and switch to the new branch:
   ```bash
   git checkout -b {type}/{name}
   ```
4. Confirm to the user: "Created and switched to `{type}/{name}` from `{base-branch}`."
5. Now proceed with the user's original request (code changes, etc.)

**If the branch already exists locally:**
- Ask the user if they want to switch to the existing branch or create a new one with a different name

**If the branch exists on remote but not locally:**
- Check out the remote branch:
  ```bash
  git checkout -b {type}/{name} origin/{type}/{name}
  ```

### Step 4: Committing Changes

When the user asks to commit or when the model needs to commit after making changes:

1. **Check current branch** — must NOT be `main` or `develop`. If it is, go to Step 2.
2. Stage the relevant files:
   - Prefer staging specific files by name rather than `git add -A` or `git add .`
   - Review what will be staged with `git status` and `git diff`
   - Do not stage files that likely contain secrets (`.env`, credentials, etc.)
3. **Determine commit message:**
   - **If the user provides an explicit commit message** (e.g., says `commit -m "my message"`) → use the user's message exactly as provided
   - **If the model is auto-generating the commit message:**
     a. Extract the branch identifier: the part after the type prefix (e.g., `feature/ASU-188` → `ASU-188`, `hotfix/add-dark-mode` → `add-dark-mode`)
     b. Prefix the commit message with this identifier followed by a colon and space
     c. Auto-generate a concise description of the changes
     d. Format: `{branch-identifier}: {description of changes}`
     e. Examples:
        - `ASU-188: add user authentication endpoint`
        - `add-dark-mode: implement dark theme toggle in settings`
4. Create the commit using a HEREDOC for proper formatting:
   ```bash
   git commit -m "$(cat <<'EOF'
   {branch-identifier}: {description}

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

### Step 5: Pushing Changes

When the user asks to push or when it's time to push after committing:

1. **Check current branch** — must NOT be `main` or `develop`. If it is, block the operation.
2. **Never force push** — if the user requests `git push --force`, `git push -f`, or any force push variant:
   - Block the operation
   - Explain: "Force pushes are not allowed under Git Flow conventions. They can overwrite shared history and cause issues for collaborators."
   - Suggest alternatives if applicable (e.g., `git push` after resolving conflicts)
3. Push with upstream tracking:
   ```bash
   git push -u origin {current-branch}
   ```
4. Confirm to the user: "Pushed `{current-branch}` to remote."

### Step 6: Pulling Changes

Feature branches and all other branch types are allowed to pull changes from other branches:

1. **Pulling from the base branch** (most common — e.g., pulling latest `develop` into `feature/X`):
   ```bash
   git pull origin {base-branch}
   ```
2. **Pulling from any other branch** — allowed, just confirm the source branch with the user
3. Handle merge conflicts: if conflicts arise, inform the user and help resolve them — but do NOT auto-merge or force-resolve

### Step 7: Pull Request Creation (User-Initiated Only)

PRs are **only created when the user explicitly says the feature/work is ready** and asks for a PR. Never auto-create PRs.

1. **Determine the target branch** per Git Flow rules:
   - `feature/` → `develop`
   - `hotfix/` → `main`
   - `release/` → `main`
   - `bugfix/` → `develop`
   - `support/` → `main`
2. **Confirm with the user**: "I'll create a PR from `{current-branch}` targeting `{target-branch}`. Is that correct?"
3. **Wait for user confirmation** before proceeding
4. **Ensure all changes are pushed** — if there are unpushed commits, push first (Step 5)
5. **Auto-generate PR title and description:**
   - Get commits in the branch:
     ```bash
     git log {target-branch}..HEAD --oneline
     ```
   - **Title**: Concise summary based on the branch name and commit messages (under 70 characters)
   - **Description**: Use this format:
     ```markdown
     ## Summary
     - {bullet points derived from commit messages}

     ## Branch
     `{current-branch}` → `{target-branch}`

     ## Commits
     - {list of commits}
     ```
6. **Create the PR** using `gh pr create`:
   ```bash
   gh pr create --title "{title}" --body "$(cat <<'EOF'
   {description}
   EOF
   )"
   ```
7. Return the PR URL to the user

## Rules & Constraints

1. **No direct work on `main` or `develop`** — always require a dedicated Git Flow branch before any code changes
2. **No force pushes** — `git push --force` and all variants are forbidden on every branch
3. **No merging** — the skill never merges branches. It creates branches, commits, pushes, and creates PRs, but merging is explicitly out of scope
4. **Commit prefix** — always prefix auto-generated commit messages with the branch identifier (text after the type prefix)
5. **User override on commit messages** — if the user provides an explicit commit message, use it exactly as-is without modification
6. **PR confirmation required** — always confirm the target branch with the user before creating a PR
7. **PR only on explicit request** — never auto-create PRs; only when the user explicitly states the work is ready and asks for a PR
8. **Proactive intervention** — intervene immediately when the user is on a protected branch, before any work begins
9. **No destructive git operations** — never run `git reset --hard`, `git clean -f`, `git checkout .` or similar destructive commands unless the user explicitly requests them
10. **Always fetch before branching** — ensure the base branch is up to date before creating a new branch from it

## Inputs

- Branch type selection (feature, hotfix, release, bugfix, support) — prompted by the skill
- Branch name/identifier (e.g., `ASU-188`, `add-dark-mode`, `v2.1.0`) — prompted by the skill
- Optional: user-provided commit message (overrides auto-generation)
- Optional: user confirmation for PR target branch

## Outputs

- Created branches following `{type}/{name}` convention from the correct base branch
- Commits with properly prefixed messages (auto-generated or user-provided)
- Pushed branches to remote with upstream tracking
- Pull requests (when requested) with auto-generated title and description, targeting the correct branch

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| User is already on a valid feature/hotfix/etc. branch | Proceed normally — no branch creation needed |
| User provides their own commit message | Use it exactly as-is, no auto-prefix |
| User tries to force push | Block, explain why, suggest alternatives |
| User is on `main`/`develop` and asks for code changes | Stop immediately, guide to branch creation before any work |
| Branch already exists locally | Ask if user wants to switch to it or create a new name |
| Branch exists on remote but not locally | Check out the remote tracking branch |
| User asks to create a PR but hasn't pushed yet | Push first, then create the PR |
| No changes to commit | Inform the user there are no staged or unstaged changes |
| User is on an unrecognized branch (not Git Flow) | Warn the user, ask how they'd like to proceed |
| Merge conflicts when pulling | Inform the user and assist with resolution; never auto-force-resolve |
| `develop` branch doesn't exist yet | Inform the user that Git Flow requires a `develop` branch and offer to create it from `main` |
| User asks to commit but is on `main`/`develop` | Redirect to branch creation first — never commit to protected branches |

## Frontmatter Settings

- `name`: `git-flow-enforcer`
- `description`: Git Flow enforcement — auto-creates branches, prefixes commits, blocks protected branch work, manages pushes and PRs following Git Flow conventions
- `disable-model-invocation`: `false` — the model must auto-invoke this skill
- `user-invocable`: `false` — not available in the `/` menu
