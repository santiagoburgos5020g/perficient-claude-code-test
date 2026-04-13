# Skill Spec: Git Flow Enforcer

## Overview

A skill that enforces Git Flow conventions across the entire git workflow — branch creation, commits, pushes, and pull request creation. It is auto-invoked by the model (not user-triggered) whenever git operations are needed.

## Purpose

Prevent direct work on protected branches (`main`, `develop`) and ensure all git operations follow standard Git Flow conventions. The skill acts as a guardrail and workflow assistant for branching, committing, pushing, and PR creation.

## Trigger Conditions

- **Auto-invoked by the model** whenever the model needs to perform git operations (commit, push, branch creation, PR creation)
- **Not user-invocable** from the `/` menu
- Should activate proactively when the user is on `main` or `develop` and asks for code changes — stop immediately and ask to create a branch first

## Branch Types Supported

All standard Git Flow branch types:

| Type       | Prefix       | Created from | PR targets  |
|------------|-------------|-------------|-------------|
| Feature    | `feature/`  | `develop`   | `develop`   |
| Hotfix     | `hotfix/`   | `main`      | `main`      |
| Release    | `release/`  | `develop`   | `main`      |
| Bugfix     | `bugfix/`   | `develop`   | `develop`   |
| Support    | `support/`  | `main`      | `main`      |

## Workflow Steps

### 1. Protected Branch Detection

- If the user is on `main` or `develop` and asks for code changes or pushes:
  - **Immediately stop** — do not begin any work
  - Ask the user what type of branch they want to create: `feature`, `hotfix`, `release`, `bugfix`, or `support`
  - Ask for the branch name (e.g., `ASU-188`, `add-dark-mode`)
  - Create the branch from the correct base branch per Git Flow rules
  - Switch to the new branch, then proceed with the user's request

### 2. Branch Creation

- Ask the user to select the branch type
- Ask for the branch name/identifier
- Create the branch using the format: `{type}/{name}` (e.g., `feature/ASU-188`, `hotfix/critical-fix`)
- The branch is created from the correct base:
  - `feature/`, `bugfix/`, `release/` → created from `develop`
  - `hotfix/`, `support/` → created from `main`

### 3. Committing Changes

- The skill handles the full commit workflow: staging files and creating the commit
- **Commit message prefix**: Always prefix the commit message with the branch identifier (the part after the type prefix)
  - Example: branch `feature/ASU-188` → commit message starts with `ASU-188: ...`
  - Example: branch `hotfix/add-dark-mode` → commit message starts with `add-dark-mode: ...`
- The model auto-generates the rest of the commit message based on the changes made
- **Exception**: If the user explicitly provides a commit message (e.g., `commit -m "blablabla"`), use the user's message as-is

### 4. Pushing Changes

- Push the current branch to the remote
- **Never force push** (`git push --force` is forbidden on all branches)
- Feature branches (and all other branch types) can push normally

### 5. Pulling Changes

- Feature branches (and other branch types) are allowed to pull changes from other branches
- For example, pulling latest `develop` into a `feature/` branch is allowed

### 6. Pull Request Creation (User-Initiated)

- PRs are **only created when the user explicitly says the feature/work is ready** and asks for a PR
- The skill auto-determines the correct target branch per Git Flow rules:
  - `feature/` → targets `develop`
  - `hotfix/` → targets `main`
  - `release/` → targets `main`
  - `bugfix/` → targets `develop`
  - `support/` → targets `main`
- **Confirm with the user** before creating: e.g., "I'll create a PR targeting `develop`, is that correct?"
- Auto-generate the PR title and description based on the commits in the branch
- Use `gh pr create` for PR creation

## Rules & Constraints

1. **No direct work on `main` or `develop`** — always require a branch
2. **No force pushes** — `git push --force` is never allowed on any branch
3. **No merging** — the skill never merges branches. It creates branches, commits, pushes, and creates PRs, but merging is not handled
4. **Commit prefix** — always prefix auto-generated commit messages with the branch identifier
5. **User override on commit messages** — if the user provides an explicit commit message, respect it
6. **PR confirmation** — always confirm the target branch with the user before creating a PR
7. **PR only on request** — never auto-create PRs; only when the user explicitly says the work is ready

## Inputs

- Branch type selection (feature, hotfix, release, bugfix, support)
- Branch name/identifier (e.g., `ASU-188`, `add-dark-mode`)
- Optional: user-provided commit message

## Outputs

- Created branches following `{type}/{name}` convention
- Commits with properly prefixed messages
- Pushed branches to remote
- Pull requests (when requested) with auto-generated title and description

## Edge Cases

- User is on a feature branch and asks to push → push normally (no branch creation needed)
- User provides their own commit message → use it as-is, no auto-prefix
- User tries to force push → block and explain why
- User is on `main`/`develop` and asks for code changes → stop immediately, guide to branch creation
- Branch already exists on remote → handle gracefully (push to existing remote branch)
- User asks to create a PR but hasn't pushed yet → push first, then create PR

## Frontmatter Settings

- `disable-model-invocation`: `false` — the model should auto-invoke this skill
- `user-invocable`: `false` — not available in the `/` menu
