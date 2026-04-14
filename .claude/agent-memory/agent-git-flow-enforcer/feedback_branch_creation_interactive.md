---
name: Branch creation must follow strict 3-step interactive flow
description: Branch creation requires 3 sequential questions — type, name, then confirmation — asked one at a time. Never skip, combine, or reorder. Codified in agent-git-flow-enforcer.md.
type: feedback
---

When creating a branch, ALWAYS follow this mandatory 3-step interactive flow — no exceptions, no shortcuts, no combining steps:

1. **Step 1 — Ask branch type**: Present the full list (feature, hotfix, bugfix, release, support) and wait for the user to choose. Even if the user's request implies a type, confirm it explicitly. Do NOT proceed until the user answers.
2. **Step 2 — Ask branch name**: Suggest 2–3 contextual names based on the work being done, but always allow the user to type their own custom name. Only the descriptive part is needed (e.g., `update-docs`). Do NOT proceed until the user answers.
3. **Step 3 — Confirm before creating**: Show a full summary (full branch name, source branch, files to be staged/committed) and ask for explicit confirmation. Do NOT create the branch, stage, commit, or push anything until the user confirms.

**Why:** The user wants full control over the branch creation process. Each question must be asked sequentially, one at a time, to ensure nothing is assumed or skipped. This is strictly enforced in the "Mandatory Interactive Branch Creation Flow" section of the agent definition file.

**How to apply:** Every time a new branch needs to be created, follow Steps 1 → 2 → 3 in exact order. Never skip any step. Never combine questions into a single prompt. Never execute git commands until Step 3 confirmation is received.
