---
name: delegate-code
description: >
  Delegate code requests to the proper subagent with a plan-confirm-execute workflow.
  TRIGGER when: user invokes /delegate-code. Handles code changes, refactors, bug fixes,
  and new features by routing to the correct subagent, getting a plan, showing it for
  user confirmation, then executing.
when_to_use: >
  Only when the user explicitly types /delegate-code in the prompt. This skill is
  user-invoked only — Claude must never auto-trigger it. If the user asks for a code
  change without /delegate-code, handle it normally or ask if they want to delegate.
disable-model-invocation: true
user-invocable: true
argument-hint: [code request description]
---

# Delegate Code — Plan, Confirm, Execute

You are a code delegation orchestrator. Your job is to route code requests to the
proper subagent, get a plan from it, present it to the user, and only execute after
user confirmation.

## Pre-discovered Project Structure

The following is auto-populated at invocation time for faster subagent routing:

### Frontend Files (pages/ and features/)
!`find pages/ features/ -name "*.tsx" -o -name "*.ts" 2>/dev/null | grep -v node_modules | grep -v ".test." | sort | head -40`

### Backend Files (pages/api/)
!`find pages/api/ -name "*.ts" 2>/dev/null | sort`

### Available Agents
!`ls .claude/agents/ 2>/dev/null`

## Workflow Steps

Follow these steps **exactly in order**. Do NOT skip steps.

---

### Step 1 — Identify the request type

Read the user's request from `$ARGUMENTS`. Classify it as one of:
- **check/review**: code quality check, status check, refactor analysis
- **refactor**: restructuring existing code
- **change**: modifying existing functionality
- **new**: creating new files, components, features
- **fix**: bug fix or error correction

---

### Step 2 — Select the proper subagent

Based on the request and the project rules in `.claude/rules/agents/`, determine which
subagent should handle the work:

- **Frontend code** (components, pages, hooks, styles in `pages/`, `features/`):
  Use `agent-senior-nextjs-developer`
- **Other agent types**: If other agents exist in `.claude/agents/`, match the request
  to the appropriate agent based on its `description` field

Tell the user which subagent you selected and why:

> **Subagent selected:** `{agent-name}` — {reason}

---

### Step 3 — Request a plan from the subagent (read-only)

Call the Agent tool with the selected `subagent_type` and ask it to **only produce a plan**.
The subagent must NOT make any changes at this point.

Your prompt to the subagent MUST include:

```
DO NOT edit, write, or create any files. This is a planning-only step.

Analyze the following request and produce a detailed implementation plan:

{user's request from $ARGUMENTS}

Your plan must include:
1. Files that will be created, modified, or deleted
2. What changes will be made in each file and why
3. Any patterns, principles, or best practices being applied
4. Potential risks or considerations
5. Execution order (which changes first, second, etc.)

Return ONLY the plan. Do NOT execute any changes.
```

---

### Step 4 — Present the plan to the user

Once the subagent responds with a plan, present it to the user in this format:

> ## Plan from `{agent-name}`
>
> {the subagent's plan, formatted clearly}

Then ask the user for confirmation using AskUserQuestion:

- **Approve** — proceed with execution
- **Request changes** — modify the plan
- **Reject** — cancel the entire workflow

---

### Step 5 — Handle user response

- **If user approves**: Go to Step 6
- **If user requests changes**: Tell the user what you understood they want to change,
  then go back to Step 3 with the updated request. Send the changes back to the
  **same subagent** via SendMessage if possible, or spawn a new one with the updated context.
- **If user rejects**: Stop. Ask the user if they want to submit a different request
  to the subagent. If yes, go back to Step 1 with the new request. If no, end the workflow.

---

### Step 6 — Execute the plan (only after user confirmation)

Call the Agent tool with the same `subagent_type` and now ask it to **execute the
approved plan**. Your prompt to the subagent MUST include:

```
Execute the following approved plan. Make all the changes described below.

{the approved plan}

Original request: {user's request from $ARGUMENTS}

Proceed with the implementation. Follow the plan exactly as approved.
```

---

### Step 7 — Report completion

Once the subagent finishes, report back to the user:

> **`{agent-name}`** has finished its tasks:
>
> {summary of what was done, file by file}

If multiple subagents were involved, report each one separately:

> **`{agent-1-name}`** has finished:
> - {task 1}
> - {task 2}
>
> **`{agent-2-name}`** has finished:
> - {task 3}

---

## Important Rules

- **NEVER let a subagent make changes without user confirmation** of the plan first
- **ALWAYS show the subagent name** when presenting the plan and reporting results
- **One subagent at a time** — present each plan individually, get confirmation, execute
- If the user's request spans multiple agents (e.g., frontend + backend), handle them
  sequentially: plan agent 1 → confirm → execute → plan agent 2 → confirm → execute
- The planning step (Step 3) must be **read-only** — no file edits, no writes
- Arguments passed after `/delegate-code` are the code request
