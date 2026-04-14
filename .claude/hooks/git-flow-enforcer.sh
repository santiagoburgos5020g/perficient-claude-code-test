#!/bin/bash
# git-flow-enforcer.sh — PreToolUse hook for Git Flow enforcement
# Reads hook input JSON from stdin, validates git commands against Git Flow rules.
# Uses Node.js for JSON parsing (jq not available on this system).

# If AGENT_GIT_FLOW_ENABLED is not "true", skip all enforcement
if [ "$AGENT_GIT_FLOW_ENABLED" != "true" ]; then
  exit 0
fi

INPUT=$(cat)

# Extract the command from the hook input JSON using node
COMMAND=$(echo "$INPUT" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try { process.stdout.write(JSON.parse(d).tool_input.command || ''); }
    catch(e) { process.stdout.write(''); }
  });
")

# If no command, allow
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Extract the git subcommand (first word after 'git')
GIT_CMD=$(echo "$COMMAND" | sed -n 's/^[[:space:]]*git[[:space:]]\+\([a-z-]*\).*/\1/p')

# If not a git command, allow
if [ -z "$GIT_CMD" ]; then
  exit 0
fi

# --- Read-only commands: always allow ---
case "$GIT_CMD" in
  status|diff|log|fetch|stash|show|blame|remote|tag|reflog|shortlog|describe)
    exit 0
    ;;
  branch)
    # Allow listing branches, block creation/deletion flags
    if echo "$COMMAND" | grep -qE '\s+(-b|-d|-D|-m|-M|--delete|--move|--copy)\b'; then
      : # fall through to validation
    else
      exit 0
    fi
    ;;
  pull)
    exit 0
    ;;
esac

# --- Get current branch ---
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

# --- Force push: ALWAYS block ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(\s-f\b|\s--force\b|--force-with-lease\b)'; then
  echo "BLOCKED: Force push is forbidden by Git Flow rules. Force pushes can overwrite shared history and cause issues for collaborators. Push normally or resolve conflicts first." >&2
  exit 2
fi

# --- Merge: ALWAYS block ---
if [ "$GIT_CMD" = "merge" ]; then
  echo "BLOCKED: Direct git merge is not allowed under Git Flow. Use pull requests to merge branches. Create a PR with 'gh pr create' targeting the correct branch per Git Flow rules." >&2
  exit 2
fi

# --- Protected branch checks (main, master, develop) ---
case "$CURRENT_BRANCH" in
  main|master|develop)
    case "$GIT_CMD" in
      commit)
        echo "BLOCKED: You are on '$CURRENT_BRANCH'. Git Flow requires committing on a dedicated branch." >&2
        echo "Create a branch first: feature/*, hotfix/*, bugfix/*, release/*, or support/*." >&2
        echo "Example: git checkout -b feature/my-feature develop" >&2
        exit 2
        ;;
      push)
        echo "BLOCKED: Direct push to '$CURRENT_BRANCH' is not allowed under Git Flow. Work should be done on dedicated branches and merged via pull request." >&2
        exit 2
        ;;
      add)
        echo "BLOCKED: You are on '$CURRENT_BRANCH'. Git Flow requires working on a dedicated branch before staging files. Create a feature/hotfix/bugfix/release/support branch first." >&2
        exit 2
        ;;
    esac
    ;;
esac

# --- Branch creation: validate naming conventions ---
NEW_BRANCH=""
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+-b\s+'; then
  NEW_BRANCH=$(echo "$COMMAND" | sed -n 's/.*git\s*checkout\s*-b\s*\([^ ]*\).*/\1/p')
elif echo "$COMMAND" | grep -qE 'git\s+switch\s+-c\s+'; then
  NEW_BRANCH=$(echo "$COMMAND" | sed -n 's/.*git\s*switch\s*-c\s*\([^ ]*\).*/\1/p')
elif echo "$COMMAND" | grep -qE 'git\s+branch\s+-b\s+\|git\s+branch\s+[^-]'; then
  NEW_BRANCH=$(echo "$COMMAND" | sed -n 's/.*git\s*branch\s*\([^ -][^ ]*\).*/\1/p')
fi

if [ -n "$NEW_BRANCH" ] && [ "$NEW_BRANCH" != "develop" ]; then
  if ! echo "$NEW_BRANCH" | grep -qE '^(feature|hotfix|release|bugfix|support)/'; then
    # Use structured JSON output to escalate to user
    cat <<ENDJSON
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Branch name '$NEW_BRANCH' does not follow Git Flow naming conventions. Expected prefixes: feature/*, hotfix/*, release/*, bugfix/*, support/*. Please confirm or choose a valid name."}}
ENDJSON
    exit 0
  fi
fi

# --- All other operations: allow ---
exit 0
