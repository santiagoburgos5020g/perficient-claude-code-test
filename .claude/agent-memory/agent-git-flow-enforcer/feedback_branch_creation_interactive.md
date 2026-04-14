---
name: Branch creation must always be interactive
description: During branch creation, always ask for branch type and name explicitly — never assume. If user has no name, suggest one and confirm.
type: feedback
---

When creating a branch, ALWAYS follow this mandatory interactive flow — no exceptions, no shortcuts:

1. **Always ask the branch type** — present the full list (feature, hotfix, bugfix, release, support) and wait for the user to choose. Even if the user's request implies a type, confirm it explicitly.
2. **Always ask for the branch name** — do not assume or generate silently.
3. **If the user doesn't provide a name** — suggest a contextual name and ask: "Would you like to use this name, or do you have a different one?" Wait for explicit confirmation before proceeding.

**Why:** The user wants full control over branch naming and type selection. Skipping these prompts leads to branches that don't match the user's intent or naming preferences.

**How to apply:** Every time you reach the branch creation phase (Step 3 in SKILL.md), follow substeps 3a, 3b, and 3c in order. Never skip 3a or 3b. Never create a branch without the user explicitly confirming both the type and the name.
