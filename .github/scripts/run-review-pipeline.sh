#!/usr/bin/env bash
# run-review-pipeline.sh
# Invokes the Claude Code CLI with the full 3-stage multi-agent pipeline prompt.
# Haiku orchestrates -> Sonnet validates -> Opus synthesizes.
#
# Supports two modes:
#   REVIEW_MODE=full        — validate all changed files vs origin/main (default)
#   REVIEW_MODE=incremental — two-track review:
#     Track 1: verify prior violations on touched files (Sonnet direct)
#     Track 2: full validation of new/unviolated files (Haiku pipeline)
#
# Required env vars: ANTHROPIC_BEDROCK_BASE_URL, ANTHROPIC_CUSTOM_HEADERS,
#   CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_SKIP_BEDROCK_AUTH, GH_TOKEN,
#   PR_NUMBER, REPO
# Optional env vars: REVIEW_MODE, ARTIFACT_PATH

set -euo pipefail

# ---------------------------------------------------------------------------
# Helper: extract pipeline JSON from Claude CLI output
# Tries 4 strategies to handle different output formats.
# Usage: extract_cli_json <input_file> <output_file>
# ---------------------------------------------------------------------------
extract_cli_json() {
  local INPUT="$1"
  local OUTPUT="$2"

  if [ ! -f "$INPUT" ]; then
    echo "::error::CLI did not produce output file: ${INPUT}"
    return 1
  fi

  echo "Raw CLI output (first 500 chars):"
  head -c 500 "$INPUT"
  echo ""

  # Log token usage if envelope present
  if jq -e '.type' "$INPUT" >/dev/null 2>&1; then
    local DURATION_MS DURATION_API_MS NUM_TURNS INPUT_TOKENS OUTPUT_TOKENS TOTAL_TOKENS CACHE_READ CACHE_CREATION
    DURATION_MS=$(jq -r '.duration_ms // "N/A"' "$INPUT")
    DURATION_API_MS=$(jq -r '.duration_api_ms // "N/A"' "$INPUT")
    NUM_TURNS=$(jq -r '.num_turns // "N/A"' "$INPUT")
    INPUT_TOKENS=$(jq -r '.usage.input_tokens // .input_tokens // "N/A"' "$INPUT")
    OUTPUT_TOKENS=$(jq -r '.usage.output_tokens // .output_tokens // "N/A"' "$INPUT")
    TOTAL_TOKENS=$(jq -r '.usage.total_tokens // .total_tokens // "N/A"' "$INPUT")
    CACHE_READ=$(jq -r '.usage.cache_read_input_tokens // .cache_read_input_tokens // "N/A"' "$INPUT")
    CACHE_CREATION=$(jq -r '.usage.cache_creation_input_tokens // .cache_creation_input_tokens // "N/A"' "$INPUT")

    echo ""
    echo "=============================="
    echo "  CLI Usage Stats (${INPUT})"
    echo "=============================="
    echo "  Duration (total):  ${DURATION_MS} ms"
    echo "  Duration (API):    ${DURATION_API_MS} ms"
    echo "  Turns:             ${NUM_TURNS}"
    echo "  Input tokens:      ${INPUT_TOKENS}"
    echo "  Output tokens:     ${OUTPUT_TOKENS}"
    echo "  Total tokens:      ${TOTAL_TOKENS}"
    echo "  Cache read:        ${CACHE_READ}"
    echo "  Cache creation:    ${CACHE_CREATION}"
    echo "=============================="
    echo ""
  fi

  # Strategy 1: Direct — the file itself is the target JSON
  if jq -e '.verdict // .verified' "$INPUT" >/dev/null 2>&1; then
    echo "Output is direct JSON"
    cp "$INPUT" "$OUTPUT"
    return 0
  fi

  # Strategy 2: CLI envelope — extract .result field
  local RESULT_TEXT
  RESULT_TEXT=$(jq -r '.result // empty' "$INPUT" 2>/dev/null)
  if [ -n "$RESULT_TEXT" ]; then
    echo "Extracting from CLI envelope .result field..."
    if echo "$RESULT_TEXT" | jq -e '.verdict // .verified' >/dev/null 2>&1; then
      echo "$RESULT_TEXT" | jq '.' > "$OUTPUT"
      return 0
    fi
  fi

  # Strategy 3: Content blocks array
  local CONTENT_TEXT
  CONTENT_TEXT=$(jq -r '
    if (.result | type) == "array" then
      [.result[] | .text // empty] | join("")
    elif (.content | type) == "array" then
      [.content[] | .text // empty] | join("")
    else
      empty
    end
  ' "$INPUT" 2>/dev/null)
  if [ -n "$CONTENT_TEXT" ] && echo "$CONTENT_TEXT" | jq -e '.verdict // .verified' >/dev/null 2>&1; then
    echo "Extracting from content blocks..."
    echo "$CONTENT_TEXT" | jq '.' > "$OUTPUT"
    return 0
  fi

  # Strategy 4: Embedded JSON in text
  echo "Attempting to extract embedded JSON from output..."
  local RAW_TEXT EMBEDDED_JSON
  RAW_TEXT=$(jq -r '.result // .' "$INPUT" 2>/dev/null || cat "$INPUT")
  EMBEDDED_JSON=$(echo "$RAW_TEXT" | sed -n '/^{/,/^}/p' | head -200)
  if [ -n "$EMBEDDED_JSON" ] && echo "$EMBEDDED_JSON" | jq -e '.verdict // .verified' >/dev/null 2>&1; then
    echo "$EMBEDDED_JSON" | jq '.' > "$OUTPUT"
    return 0
  fi

  echo "::error::Could not extract JSON from CLI output: ${INPUT}"
  cat "$INPUT"
  return 1
}

# ---------------------------------------------------------------------------
# Helper: build violations_artifact from inline_comments
# Usage: build_artifact <push_count> <active_violations_json>
# Writes to ARTIFACT_PATH
# ---------------------------------------------------------------------------
build_artifact() {
  local PUSH_COUNT="$1"
  local VIOLATIONS_JSON="$2"
  local ARTIFACT_FILE="${ARTIFACT_PATH:-.review-artifacts/violations.json}"

  mkdir -p "$(dirname "$ARTIFACT_FILE")"

  jq -n \
    --argjson pr "${PR_NUMBER}" \
    --arg sha "$(git rev-parse HEAD)" \
    --argjson push_count "$PUSH_COUNT" \
    --argjson violations "$VIOLATIONS_JSON" \
    '{
      pr_number: ($pr | tonumber),
      last_push_sha: $sha,
      push_count: $push_count,
      active_violations: $violations
    }' > "$ARTIFACT_FILE"

  echo "Artifact written: $(echo "$VIOLATIONS_JSON" | jq 'length') active violations"
}

# ---------------------------------------------------------------------------
# Helper: extract description and suggestion from inline comment body
# Usage: echo "$BODY" | extract_description
#        echo "$BODY" | extract_suggestion
# ---------------------------------------------------------------------------
extract_violation_fields() {
  local INLINE_COMMENTS="$1"
  local PUSH_COUNT="$2"

  echo "$INLINE_COMMENTS" | jq -c --argjson push "$PUSH_COUNT" '[.[] | {
    path: .path,
    line: .line,
    skill: (try (.body | capture("^\\*\\*(?<s>[^>]+)>") | .s | ltrimstr(" ") | rtrimstr(" ")) catch "unknown"),
    rule: (try (.body | capture("^\\*\\*[^>]+>\\s*(?<r>[^*]+)\\*\\*") | .r | ltrimstr(" ") | rtrimstr(" ")) catch "unknown"),
    description: ([.body | split("\n\n")[] | select(
      (startswith("**") | not) and
      (contains("<!-- pr-code-review-validator -->") | not)
    )] | first // "see inline comment"),
    suggestion: (try (.body | capture("\\*\\*Suggestion:\\*\\*\\s*(?<s>[\\s\\S]*?)\\n\\n<!--") | .s) catch "see inline comment"),
    found_in_push: $push,
    body: .body
  }]'
}

# ---------------------------------------------------------------------------
# Helper: write the base 3-stage pipeline prompt to pipeline-prompt.txt
# ---------------------------------------------------------------------------
write_base_pipeline_prompt() {
cat > pipeline-prompt.txt <<'PIPELINE_PROMPT'
You are the PR Code Review Validator orchestrator. You will execute a 3-stage
pipeline to review code changes in this pull request against the project's
skill rules. You MUST output ONLY a single JSON object as your final response.
No markdown, no explanation, no preamble — just the JSON.

================================================================================
STAGE 1: CLASSIFICATION (you execute this directly)
================================================================================

Step 1.1: Get changed files.
Run this command via the Bash tool:
  git diff --name-only origin/main...HEAD

Step 1.2: Get newly added files.
Run this command via the Bash tool:
  git diff --diff-filter=A --name-only origin/main...HEAD

Step 1.3: Filter non-code files.
Remove any file matching these patterns:
- package.json, package-lock.json, yarn.lock, pnpm-lock.yaml
- .gitignore, .env, .env.*
- .eslintrc*, tsconfig.json, next.config.js, next.config.mjs
- tailwind.config.*, prettier.config.*, postcss.config.*
- jest.config.*, jest.setup.*
- *.png, *.jpg, *.jpeg, *.gif, *.svg, *.ico, *.webp
- *.woff, *.woff2, *.ttf, *.eot
- *.md, *.mdx, *.txt
- *.json (EXCEPT files inside pages/api/)
- *.css, *.scss (EXCEPT Tailwind utility files)
- Any file inside: node_modules/, .next/, .git/, dist/, build/, coverage/,
  .claude/, .github/, .husky/, spec/, examples/, templates-example/,
  chrome-dev-tools/, public/, scripts/

Keep only files with extensions: .ts, .tsx, .js, .jsx, .prisma, .sql

Step 1.4: If ZERO code files remain after filtering, output this exact JSON and STOP:
{
  "verdict": "skip",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW SKIPPED — no code files changed\n\nOnly non-code files were modified in this PR. No skill-based review needed.\nStatus: **PASSED**\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "stats": {
    "files_checked": 0,
    "files_changed": 0,
    "files_related": 0,
    "skills_applied": [],
    "violations_found": 0,
    "false_positives_filtered": 0
  }
}

Step 1.5: Classify each remaining code file.

FRONTEND paths (apply nextjs-react-best-practices):
- pages/ (EXCLUDING pages/api/)
- components/
- containers/
- hooks/
- styles/
- features/**/components/
- features/**/hooks/

BACKEND paths (apply backend-best-practices):
- pages/api/
- lib/
- services/
- prisma/
- Any .prisma or .sql file regardless of location
- Root-level .ts/.tsx files (e.g., middleware.ts)

AMBIGUOUS paths (classify by who imports them):
- types/ or features/**/types/
- utils/ or features/**/utils/
For these, use grep to check what imports them:
  grep -rl "from.*['\"]\.\./types/<filename>" --include="*.ts" --include="*.tsx" .
  grep -rl "from.*['\"]\.\./utils/<filename>" --include="*.ts" --include="*.tsx" .
- If only frontend paths import it -> frontend
- If only backend paths import it -> backend
- If both import it -> classify as BOTH (both skills apply)
- If no importers found -> classify based on file contents (React imports = frontend, otherwise backend)

TEST FILES (*.test.ts, *.test.tsx, *.spec.ts, *.spec.tsx, files in __tests__/):
  Inherit classification from the source file they test. For example:
  - features/products/components/Card.test.tsx -> frontend (tests Card.tsx in components/)
  - pages/api/products.test.ts -> backend (tests the API route)

Step 1.6: Trace related files (ONE level deep only).
For each changed code file, find files that import it and files it imports:
  a. Read the file to extract its import paths
  b. Run: grep -rl "from.*['\"].*<module-name>['\"]" --include="*.ts" --include="*.tsx" .
  c. Add discovered files to scope with their own classification
  d. Do NOT trace further — one level only

Step 1.7: Build the classification result:
  - frontend_files: array of file paths classified as frontend
  - backend_files: array of file paths classified as backend
  - new_files: array of newly added file paths
  - has_frontend: boolean
  - has_backend: boolean
  - total_changed: count of changed code files
  - total_related: count of related files discovered

================================================================================
STAGE 2: VALIDATION (spawn Sonnet sub-agents via the Agent tool)
================================================================================

Based on the classification from Stage 1, spawn validation agents.

IF has_frontend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt (replace <FRONTEND_FILES> and <NEW_FRONTEND_FILES>
with the actual file lists from Stage 1):

---BEGIN FRONTEND AGENT PROMPT---
You are the Frontend Validation Agent. Validate the listed files against
the project's frontend skill rules.

FILES TO VALIDATE:
<FRONTEND_FILES>

NEW FILES (additionally check folder placement, naming, internal structure):
<NEW_FRONTEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 13 frontend categories:
   - Cat 1: Container-Presentational Component Pattern
   - Cat 2: Folder Structure
   - Cat 3: Naming Conventions
   - Cat 4: Component File Internal Structure
   - Cat 5: TypeScript Strictness
   - Cat 6: React 18 Hooks Best Practices
   - Cat 7: useSWR Best Practices
   - Cat 8: Error Handling
   - Cat 9: Testing Patterns
   - Cat 10: Tailwind CSS Conventions
   - Cat 11: Pages Router Data Fetching Strategy
   - Cat 12: Performance Optimization
   - Cat 13: Accessibility (a11y)

4. Also evaluate SOLID principles in frontend context (SRP, OCP, LSP, ISP, DIP
   as they map to frontend categories 3.11-3.23 in the SOLID skill).

5. Also evaluate design patterns in frontend context — only flag patterns that
   are genuinely misused or clearly needed but missing. Never flag absence of
   a pattern in simple code.

6. For NEW FILES, additionally check:
   - Cat 2: Is the file in the correct directory?
   - Cat 3: Does the filename follow conventions?
   - Cat 4: Does the internal structure follow the expected order?
   If a file is in the wrong directory, explain where it should be placed.

7. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "nextjs-react-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Cat 5: TypeScript Strictness" | "SRP" | "Strategy" | etc.,
  "scope": "frontend",
  "path": "relative/path/to/file.tsx",
  "line": 15,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
Do NOT include Informational-severity findings.
Do NOT flag patterns in trivially simple code.
---END FRONTEND AGENT PROMPT---

IF has_backend is true, use the Agent tool to spawn a sub-agent with model
"sonnet" and the following prompt (replace <BACKEND_FILES> and <NEW_BACKEND_FILES>
with the actual file lists from Stage 1):

---BEGIN BACKEND AGENT PROMPT---
You are the Backend Validation Agent. Validate the listed files against
the project's backend skill rules.

FILES TO VALIDATE:
<BACKEND_FILES>

NEW FILES (additionally check folder placement and naming):
<NEW_BACKEND_FILES>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh, never assume content):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file listed in FILES TO VALIDATE using the Read tool.

3. Evaluate each file against ALL 10 core backend rules:
   - Rule 1: Standard API Response Envelope
   - Rule 2: RESTful API Design
   - Rule 3: Pagination Standard
   - Rule 4: Input Validation with Zod
   - Rule 5: Centralized Error Handling
   - Rule 6: Security
   - Rule 7: Database Optimization (Prisma)
   - Rule 8: Testing API Routes
   - Rule 9: Naming Conventions
   - Rule 10: Environment Variables & Configuration

4. Also evaluate SOLID principles in backend context:
   Priority order: SRP > ISP > DIP > OCP > LSP

5. Also evaluate design patterns in backend context — only flag patterns that
   are genuinely misused or clearly needed but missing. Never flag absence of
   a pattern in simple code.

6. For NEW FILES, additionally check:
   - Is the file in the correct directory per project conventions?
   - Rule 9: Does the filename follow naming conventions?

7. Output ONLY a JSON array of violations. Each violation object:
{
  "skill": "backend-best-practices" | "solid-principles-reference" | "design-patterns-reference",
  "rule": "Rule 6: Security" | "SRP" | "Factory Method" | etc.,
  "scope": "backend",
  "path": "relative/path/to/file.ts",
  "line": 22,
  "description": "Clear description of what violates the rule and why",
  "suggestion": "Specific, actionable fix suggestion",
  "severity": "Critical" | "Recommended"
}

If zero violations found, output: []
Do NOT include Informational-severity findings.
Do NOT flag patterns in trivially simple code.
---END BACKEND AGENT PROMPT---

IMPORTANT: If has_frontend AND has_backend are BOTH true, spawn BOTH agents
in parallel (in the same message with two Agent tool calls).

After ALL sub-agents complete, combine their output arrays into a single
array called all_violations.

IF all_violations is empty (zero violations from all agents), build and output
the following JSON as your FINAL output and STOP:
{
  "verdict": "pass",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — PASSED (clean)\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <TOTAL_CHANGED + TOTAL_RELATED> (<TOTAL_CHANGED> changed, <TOTAL_RELATED> related) |\n| Skills applied | <COMMA_SEPARATED_SKILLS_LIST> |\n| Violations found | 0 |\n| Status | **PASSED** |\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "stats": {
    "files_checked": <TOTAL>,
    "files_changed": <TOTAL_CHANGED>,
    "files_related": <TOTAL_RELATED>,
    "skills_applied": [<SKILLS_ARRAY>],
    "violations_found": 0,
    "false_positives_filtered": 0
  }
}

Replace all <PLACEHOLDERS> with actual computed values. The skills_applied
array should list which skills were actually evaluated (e.g.,
["nextjs-react-best-practices", "design-patterns (frontend-scoped)", "SOLID (frontend-scoped)"]).

================================================================================
STAGE 3: REVIEW SYNTHESIS (spawn Opus sub-agent — ONLY if violations found)
================================================================================

IF all_violations is NOT empty, use the Agent tool to spawn a sub-agent with
model "opus" and the following prompt (replace <ALL_VIOLATIONS_JSON> with the
actual JSON array):

---BEGIN SYNTHESIS AGENT PROMPT---
You are the Review Synthesis Agent. You receive potential violations found by
validation agents. Your job is to filter false positives, add architectural
context, resolve conflicting rules, and produce the final curated review.

POTENTIAL VIOLATIONS:
<ALL_VIOLATIONS_JSON>

INSTRUCTIONS:
1. Read these skill files using the Read tool (ALWAYS read fresh):
   - .claude/skills/backend-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/SKILL.md
   - .claude/skills/nextjs-react-best-practices/reference.md
   - .claude/skills/solid-principles-reference/SKILL.md
   - .claude/skills/design-patterns-reference/SKILL.md
   - .claude/skills/design-patterns-reference/reference.md

2. Read EVERY file referenced in the violations list using the Read tool.
   Read the FULL file, not just the flagged line — you need complete context.

3. For EACH potential violation, determine:
   a. TRUE VIOLATION — the code genuinely violates the rule when full context
      is considered. The rule clearly applies and the code is wrong.
   b. FALSE POSITIVE — the code appears to violate the rule in isolation but
      is actually correct when broader context is considered. Examples:
      - A "missing Zod validation" finding when upstream middleware already validates
      - A "missing error handling" when the framework handles it
      - A pattern absence in code too simple to warrant the pattern

4. For TRUE violations, write an inline comment body in this exact format:
   **<skill-name> > <rule>**

   <Explanation of WHY the code violates the rule — not just THAT it does.
   Include the architectural context and what impact the violation has.>

   **Suggestion:** <Specific, actionable fix with enough detail to implement>

   <!-- pr-code-review-validator -->

5. For FALSE positives, record:
   - The original skill/rule/path/line
   - A clear explanation of why it is NOT a violation in context

6. Resolve conflicting rules:
   - If two skills disagree (e.g., splitting a class for SRP would break the
     API response envelope pattern), make the judgment call
   - Explain the trade-off in the inline comment
   - Prefer: Security > Data Integrity > Correctness > Maintainability

7. Output ONLY a JSON object with this exact structure:
{
  "confirmed_violations": [
    {
      "skill": "backend-best-practices",
      "rule": "Rule 6: Security",
      "scope": "backend",
      "path": "pages/api/products.ts",
      "line": 15,
      "body": "**backend-best-practices > Rule 6: Security**\n\n<full explanation>\n\n**Suggestion:** <fix>\n\n<!-- pr-code-review-validator -->"
    }
  ],
  "false_positives": [
    {
      "skill": "backend-best-practices",
      "rule": "Rule 4: Zod Validation",
      "path": "pages/api/products.ts",
      "line": 10,
      "reason": "Input is validated by upstream middleware in lib/middleware.ts:25"
    }
  ]
}
---END SYNTHESIS AGENT PROMPT---

After the Opus agent returns, use its output to build the FINAL JSON.

Count: confirmed_count = length of confirmed_violations
Count: filtered_count = length of false_positives

IF confirmed_count == 0 (all were false positives), output:
{
  "verdict": "pass",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — PASSED (after review)\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <N> (<CHANGED> changed, <RELATED> related) |\n| Skills applied | <LIST> |\n| Initial findings | <TOTAL_INITIAL> |\n| False positives filtered | <FILTERED_COUNT> |\n| Violations confirmed | 0 |\n| Status | **PASSED** |\n\n### Filtered findings (informational)\n<For each false positive: - ~<rule> — `<path>:<line>`~ — <reason>>\n\n---\n*This review was generated by the PR Code Review Validator.*",
  "inline_comments": [],
  "stats": {
    "files_checked": <N>,
    "files_changed": <CHANGED>,
    "files_related": <RELATED>,
    "skills_applied": [<SKILLS>],
    "violations_found": 0,
    "false_positives_filtered": <FILTERED_COUNT>
  }
}

IF confirmed_count > 0, output:
{
  "verdict": "fail",
  "summary": "<!-- pr-code-review-validator -->\n## REVIEW COMPLETE — VIOLATIONS FOUND\n\n| Metric | Value |\n|--------|-------|\n| Files checked | <N> (<CHANGED> changed, <RELATED> related) |\n| Skills applied | <LIST> |\n| Violations found | <CONFIRMED_COUNT> |\n| False positives filtered | <FILTERED_COUNT> |\n| Status | **BLOCKED** |\n\n<For each skill that has violations, create a ### heading with the skill name, then list violations as:\n- [ ] **<rule>** — `<path>:<line>` — <short description>\n>\n\n---\n*This review was generated by the PR Code Review Validator. All violations must be resolved before merging.*",
  "inline_comments": [
    <For each confirmed violation:
    {
      "path": "<path>",
      "line": <line>,
      "side": "RIGHT",
      "body": "<the body field from confirmed_violations>"
    }
    >
  ],
  "stats": {
    "files_checked": <N>,
    "files_changed": <CHANGED>,
    "files_related": <RELATED>,
    "skills_applied": [<SKILLS>],
    "violations_found": <CONFIRMED_COUNT>,
    "false_positives_filtered": <FILTERED_COUNT>
  }
}

================================================================================
CRITICAL OUTPUT REQUIREMENTS
================================================================================
- Your FINAL output must be ONLY the JSON object. No markdown wrapping, no
  explanation text, no code fences. Just raw JSON.
- The JSON must be parseable by jq.
- "verdict" must be exactly one of: "pass", "fail", "skip"
- Every inline_comments[].body MUST contain <!-- pr-code-review-validator -->
- The "summary" field MUST start with <!-- pr-code-review-validator -->
- Replace ALL <PLACEHOLDERS> with actual computed values
- If any stage encounters an error reading skill files, log a warning and
  continue with remaining skills. If ALL skill files are unreadable, output
  a fail verdict with an error explanation in the summary.

Now execute Stage 1. Begin by running: git diff --name-only origin/main...HEAD
PIPELINE_PROMPT
}

# ---------------------------------------------------------------------------
# 1. Large PR detection — warn if >50 code files
# ---------------------------------------------------------------------------
CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
CODE_FILE_COUNT=$(echo "$CHANGED_FILES" | grep -cE '\.(ts|tsx|js|jsx|prisma|sql)$' || true)

if (( CODE_FILE_COUNT > 50 )); then
  echo "::warning::Large PR detected: ${CODE_FILE_COUNT} code files changed"
  gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
    --method POST \
    --field body="<!-- pr-code-review-validator -->
> **Warning:** This PR changes **${CODE_FILE_COUNT}** code files, which is unusually large. The review will still run but may take longer than usual. Consider splitting this PR into smaller, focused changes." \
    2>/dev/null || echo "::warning::Failed to post large PR warning"
fi

# ---------------------------------------------------------------------------
# 2. Incremental mode handling
# ---------------------------------------------------------------------------
if [[ "${REVIEW_MODE:-full}" == "incremental" ]] && [[ -f prior-findings.json ]]; then
  TRACK1_COUNT=$(jq '.track1_files | length' prior-findings.json)
  TRACK2_COUNT=$(jq '.track2_files | length' prior-findings.json)
  UNTOUCHED_COUNT=$(jq '.untouched_violations | length' prior-findings.json)
  PUSH_COUNT=$(jq '.push_count' prior-findings.json)

  echo "Review mode: INCREMENTAL (Track1: ${TRACK1_COUNT} files, Track2: ${TRACK2_COUNT} files, Untouched: ${UNTOUCHED_COUNT} violations)"

  # -------------------------------------------------------------------------
  # 2a. Short-circuit: no files to validate in this push
  # -------------------------------------------------------------------------
  if [[ "$TRACK1_COUNT" -eq 0 ]] && [[ "$TRACK2_COUNT" -eq 0 ]]; then
    if [[ "$UNTOUCHED_COUNT" -gt 0 ]]; then
      echo "Short-circuit: no code files in this push, untouched violations remain."

      UNTOUCHED_VIOLATIONS=$(jq -c '.untouched_violations' prior-findings.json)
      INLINE_COMMENTS=$(echo "$UNTOUCHED_VIOLATIONS" | jq '[.[] | {path: .path, line: .line, side: "RIGHT", body: .body}]')
      CHECKLIST=$(echo "$UNTOUCHED_VIOLATIONS" | jq -r '.[] | "- [ ] **\(.skill) > \(.rule)** — `\(.path):\(.line)` — \(.description // "see inline comment")"')

      SUMMARY="<!-- pr-code-review-validator -->
## INCREMENTAL REVIEW

| Metric | Value |
|--------|-------|
| Review type | Incremental (push #${PUSH_COUNT}) |
| Total active violations | ${UNTOUCHED_COUNT} |
| Status | **BLOCKED** |

### Current issues
${CHECKLIST}

---
*This review was generated by the PR Code Review Validator (incremental mode).*"

      jq -n \
        --arg verdict "fail" \
        --arg summary "$SUMMARY" \
        --argjson inline_comments "$INLINE_COMMENTS" \
        --argjson untouched_count "$UNTOUCHED_COUNT" \
        --argjson untouched "$UNTOUCHED_VIOLATIONS" \
        --argjson push_count "$PUSH_COUNT" \
        '{
          verdict: $verdict,
          summary: $summary,
          inline_comments: $inline_comments,
          stats: {
            files_checked: 0,
            violations_found: $untouched_count,
            track1_verified: 0,
            track1_resolved: 0,
            track1_still_present: 0,
            track2_new: 0,
            untouched: $untouched_count
          },
          violations_artifact: {
            pr_number: ($untouched[0].path // "" | . as $dummy | env.PR_NUMBER | tonumber),
            last_push_sha: "",
            push_count: $push_count,
            active_violations: $untouched
          }
        }' > pipeline-output.json

      # Patch in the SHA (jq can't run git)
      CURRENT_SHA=$(git rev-parse HEAD)
      jq --arg sha "$CURRENT_SHA" --argjson pr "${PR_NUMBER}" \
        '.violations_artifact.pr_number = ($pr | tonumber) | .violations_artifact.last_push_sha = $sha' \
        pipeline-output.json > pipeline-output-tmp.json
      mv pipeline-output-tmp.json pipeline-output.json

      echo "Pipeline complete (short-circuit). Verdict: fail"
      exit 0
    else
      echo "Short-circuit: no code files and no untouched violations. Pass."
      jq -n \
        --argjson pr "${PR_NUMBER}" \
        --arg sha "$(git rev-parse HEAD)" \
        --argjson push_count "$PUSH_COUNT" \
        '{
          verdict: "pass",
          summary: "<!-- pr-code-review-validator -->\n## INCREMENTAL REVIEW — PASSED\n\nNo active violations remain.\nStatus: **PASSED**\n\n---\n*This review was generated by the PR Code Review Validator (incremental mode).*",
          inline_comments: [],
          stats: { files_checked: 0, violations_found: 0 },
          violations_artifact: {
            pr_number: ($pr | tonumber),
            last_push_sha: $sha,
            push_count: $push_count,
            active_violations: []
          }
        }' > pipeline-output.json
      echo "Pipeline complete (short-circuit). Verdict: pass"
      exit 0
    fi
  fi

  # -------------------------------------------------------------------------
  # 2b. Track 1: Verification of prior violations on touched files
  # -------------------------------------------------------------------------
  TRACK1_RESULT='{"verified":[]}'

  if [[ "$TRACK1_COUNT" -gt 0 ]]; then
    echo ""
    echo "=========================================="
    echo "  Track 1: Verification (${TRACK1_COUNT} files)"
    echo "=========================================="

    TRACK1_VIOLATIONS=$(jq -c '.track1_violations' prior-findings.json)

    # Build indexed violations for the prompt (add id field)
    TRACK1_INDEXED=$(echo "$TRACK1_VIOLATIONS" | jq -c '[to_entries[] | .value + {id: .key}]')

    # Build compact violations list for prompt (only fields the agent needs)
    TRACK1_FOR_PROMPT=$(echo "$TRACK1_INDEXED" | jq -c '[.[] | {
      id: .id,
      path: .path,
      line: .line,
      skill: .skill,
      rule: .rule,
      description: .description,
      suggestion: .suggestion
    }]')

    cat > verification-prompt.txt <<VERIFICATION_PROMPT
You are the Violation Verification Agent. You receive a list of previously-found
code violations and the current version of each file. Your job is to determine
whether each violation is STILL PRESENT or has been RESOLVED.

You are NOT performing a full code review. You are ONLY checking whether the
specific violations listed below still exist in the current code.

VIOLATIONS TO VERIFY:
${TRACK1_FOR_PROMPT}

INSTRUCTIONS:
1. For each violation, read the file at the specified path using the Read tool.
   Read the ENTIRE file, not just the flagged line.

2. For each violation, determine:
   a. STILL_PRESENT — The underlying issue described in "description" is still
      present in the code. The exact line number may have shifted, but the same
      kind of problem exists. Use the "suggestion" field as a guide for what
      the fix would look like — if the suggestion has NOT been applied (or an
      equivalent fix), the violation is still present.
   b. RESOLVED — The code has been changed such that the issue described in
      "description" no longer applies. The suggestion (or an equivalent fix)
      has been implemented.

3. When checking, focus on the SUBSTANCE of the violation, not the exact line
   number. If the code at line 6 moved to line 8 but the same problem exists,
   it is STILL_PRESENT (update the line number). If the entire function was
   refactored and the problem no longer applies, it is RESOLVED.

4. Do NOT look for NEW violations. Do NOT apply skill rules broadly. ONLY
   check the specific violations listed above.

5. Output ONLY a JSON object with this exact structure:
{
  "verified": [
    {
      "id": 0,
      "status": "still_present",
      "path": "pages/api/todos/index.ts",
      "line": 8,
      "reason": "The process.env.API_URL is still accessed with non-null assertion on line 8"
    },
    {
      "id": 1,
      "status": "resolved",
      "reason": "A runtime guard was added at line 5: if (!process.env.API_URL) throw..."
    }
  ]
}

For STILL_PRESENT violations:
- Include the updated "line" number (even if unchanged)
- Include the "path" field
- Include a "reason" explaining what you found

For RESOLVED violations:
- Include a brief "reason" explaining what changed
- Do NOT include "line" or "path" fields

Output ONLY the JSON. No markdown, no explanation, no code fences.
VERIFICATION_PROMPT

    echo "Running Track 1 verification..."
    timeout 180 claude --print --model sonnet --output-format json \
      < verification-prompt.txt > track1-raw.json 2>&1 || true

    if [[ -f track1-raw.json ]] && extract_cli_json track1-raw.json track1-output.json; then
      TRACK1_RESULT=$(cat track1-output.json)
      echo "Track 1 complete."
    else
      echo "::warning::Track 1 verification failed. Treating all prior violations as still present."
      # Build a fallback: mark all as still_present
      TRACK1_RESULT=$(echo "$TRACK1_INDEXED" | jq '{verified: [.[] | {id: .id, status: "still_present", path: .path, line: .line, reason: "verification failed — assumed still present"}]}')
    fi

    rm -f verification-prompt.txt track1-raw.json track1-output.json
  fi

  # -------------------------------------------------------------------------
  # 2c. Track 2: Full validation of new/unviolated files
  # -------------------------------------------------------------------------
  TRACK2_PIPELINE_RESULT='{"verdict":"pass","inline_comments":[],"stats":{"files_checked":0,"violations_found":0,"false_positives_filtered":0}}'

  if [[ "$TRACK2_COUNT" -gt 0 ]]; then
    echo ""
    echo "=========================================="
    echo "  Track 2: Full Validation (${TRACK2_COUNT} files)"
    echo "=========================================="

    TRACK2_FILES_LIST=$(jq -r '.track2_files | join(", ")' prior-findings.json)

    # Build a scoped pipeline prompt: prepend a header that restricts Stage 1
    cat > track2-header.txt <<TRACK2_HEADER
================================================================================
SCOPED REVIEW CONTEXT (READ THIS FIRST)
================================================================================
This is a SCOPED review. You are validating ONLY the following files:
${TRACK2_FILES_LIST}

INSTRUCTIONS:
- In Stage 1, do NOT run git diff. Use ONLY the files listed above.
  Classify those files using the same path rules as the full prompt below.
- For Step 1.2 (new files), treat ALL the files above as potentially new.
  Run: git diff --diff-filter=A --name-only origin/main...HEAD
  and intersect with the list above.
- Continue with Stage 2 and Stage 3 as normal, but ONLY for these files.

Now proceed with the pipeline below, applying the scope restriction above.

================================================================================

TRACK2_HEADER

    # Write the base pipeline prompt
    write_base_pipeline_prompt
    cat track2-header.txt pipeline-prompt.txt > pipeline-prompt-scoped.txt
    rm -f track2-header.txt

    echo "Running Track 2 full validation..."
    timeout 540 claude --print --model haiku --output-format json \
      < pipeline-prompt-scoped.txt > track2-raw.json 2>&1 || true

    if [[ -f track2-raw.json ]] && extract_cli_json track2-raw.json track2-output.json; then
      TRACK2_PIPELINE_RESULT=$(cat track2-output.json)
      echo "Track 2 complete."
    else
      echo "::warning::Track 2 validation failed. No new violations recorded."
    fi

    rm -f pipeline-prompt-scoped.txt track2-raw.json track2-output.json
  fi

  # -------------------------------------------------------------------------
  # 2d. Merge all tracks into final output
  # -------------------------------------------------------------------------
  echo ""
  echo "=========================================="
  echo "  Merging tracks"
  echo "=========================================="

  UNTOUCHED_VIOLATIONS=$(jq -c '.untouched_violations' prior-findings.json)
  TRACK1_VIOLATIONS=$(jq -c '.track1_violations' prior-findings.json)

  # Process Track 1: separate still_present from resolved
  TRACK1_STILL_IDS=$(echo "$TRACK1_RESULT" | jq -c '[.verified[] | select(.status == "still_present")]')
  TRACK1_RESOLVED_COUNT=$(echo "$TRACK1_RESULT" | jq '[.verified[] | select(.status == "resolved")] | length')
  TRACK1_STILL_COUNT=$(echo "$TRACK1_STILL_IDS" | jq 'length')

  echo "  Track 1: ${TRACK1_STILL_COUNT} still present, ${TRACK1_RESOLVED_COUNT} resolved"

  # Map still_present back to full violation objects with updated line numbers
  TRACK1_ACTIVE=$(jq -n \
    --argjson originals "$TRACK1_VIOLATIONS" \
    --argjson verified "$TRACK1_STILL_IDS" \
    '[
      $verified[] |
      . as $v |
      $originals[($v.id)] |
      . + {line: ($v.line // .line), path: ($v.path // .path)}
    ]')

  # Process Track 2: extract new violations from pipeline result
  TRACK2_INLINE=$(echo "$TRACK2_PIPELINE_RESULT" | jq -c '.inline_comments // []')
  TRACK2_VIOLATION_COUNT=$(echo "$TRACK2_INLINE" | jq 'length')
  echo "  Track 2: ${TRACK2_VIOLATION_COUNT} new violations"

  # Convert Track 2 inline comments to violation objects
  TRACK2_VIOLATIONS=$(extract_violation_fields "$TRACK2_INLINE" "$PUSH_COUNT")

  echo "  Untouched: ${UNTOUCHED_COUNT} carried forward"

  # Merge all active violations
  ALL_ACTIVE=$(jq -n \
    --argjson untouched "$UNTOUCHED_VIOLATIONS" \
    --argjson track1 "$TRACK1_ACTIVE" \
    --argjson track2 "$TRACK2_VIOLATIONS" \
    '$untouched + $track1 + $track2')

  TOTAL_ACTIVE=$(echo "$ALL_ACTIVE" | jq 'length')
  echo "  Total active: ${TOTAL_ACTIVE}"

  # Determine verdict
  if [[ "$TOTAL_ACTIVE" -eq 0 ]]; then
    VERDICT="pass"
  else
    VERDICT="fail"
  fi

  # Build inline_comments for GitHub
  INLINE_COMMENTS=$(echo "$ALL_ACTIVE" | jq '[.[] | {path: .path, line: .line, side: "RIGHT", body: .body}]')

  # Build summary
  if [[ "$VERDICT" == "pass" ]]; then
    SUMMARY="<!-- pr-code-review-validator -->
## INCREMENTAL REVIEW — PASSED

| Metric | Value |
|--------|-------|
| Review type | Incremental (push #${PUSH_COUNT}) |
| Violations verified | ${TRACK1_STILL_COUNT} still present, ${TRACK1_RESOLVED_COUNT} resolved |
| New violations | ${TRACK2_VIOLATION_COUNT} |
| Untouched | ${UNTOUCHED_COUNT} |
| Total active | 0 |
| Status | **PASSED** |

All violations have been resolved.

---
*This review was generated by the PR Code Review Validator (incremental mode).*"
  else
    CHECKLIST=$(echo "$ALL_ACTIVE" | jq -r '.[] | "- [ ] **\(.skill) > \(.rule)** — `\(.path):\(.line)` — \(.description // "see inline comment")"')
    SUMMARY="<!-- pr-code-review-validator -->
## REVIEW COMPLETE — VIOLATIONS FOUND

| Metric | Value |
|--------|-------|
| Review type | Incremental (push #${PUSH_COUNT}) |
| Violations verified | ${TRACK1_STILL_COUNT} still present, ${TRACK1_RESOLVED_COUNT} resolved |
| New violations | ${TRACK2_VIOLATION_COUNT} |
| Untouched | ${UNTOUCHED_COUNT} |
| Total active | ${TOTAL_ACTIVE} |
| Status | **BLOCKED** |

### Current issues
${CHECKLIST}

---
*This review was generated by the PR Code Review Validator. All violations must be resolved before merging.*"
  fi

  # Build final pipeline-output.json
  jq -n \
    --arg verdict "$VERDICT" \
    --arg summary "$SUMMARY" \
    --argjson inline_comments "$INLINE_COMMENTS" \
    --argjson total "$TOTAL_ACTIVE" \
    --argjson track1_still "$TRACK1_STILL_COUNT" \
    --argjson track1_resolved "$TRACK1_RESOLVED_COUNT" \
    --argjson track2_new "$TRACK2_VIOLATION_COUNT" \
    --argjson untouched "$UNTOUCHED_COUNT" \
    --argjson all_active "$ALL_ACTIVE" \
    --argjson push_count "$PUSH_COUNT" \
    --argjson pr "${PR_NUMBER}" \
    --arg sha "$(git rev-parse HEAD)" \
    '{
      verdict: $verdict,
      summary: $summary,
      inline_comments: $inline_comments,
      stats: {
        violations_found: $total,
        track1_verified: ($track1_still + $track1_resolved),
        track1_resolved: $track1_resolved,
        track1_still_present: $track1_still,
        track2_new: $track2_new,
        untouched: $untouched
      },
      violations_artifact: {
        pr_number: ($pr | tonumber),
        last_push_sha: $sha,
        push_count: $push_count,
        active_violations: $all_active
      }
    }' > pipeline-output.json

  echo ""
  echo "Pipeline complete (incremental). Verdict: ${VERDICT}"
  exit 0
fi

# ===========================================================================
# FULL REVIEW MODE
# ===========================================================================
echo "Review mode: FULL"
echo "Starting review pipeline..."

# ---------------------------------------------------------------------------
# 3. Build and run the full pipeline prompt
# ---------------------------------------------------------------------------
write_base_pipeline_prompt

timeout 540 claude --print --model haiku --output-format json < pipeline-prompt.txt > pipeline-raw.json

extract_cli_json pipeline-raw.json pipeline-output.json
rm -f pipeline-raw.json

# Final validation
if ! jq empty pipeline-output.json 2>/dev/null; then
  echo "::error::Extracted output is not valid JSON"
  cat pipeline-output.json
  exit 1
fi

VERDICT=$(jq -r '.verdict' pipeline-output.json)
echo "Pipeline complete. Verdict: ${VERDICT}"

if [[ "$VERDICT" != "pass" && "$VERDICT" != "fail" && "$VERDICT" != "skip" ]]; then
  echo "::error::Invalid verdict: ${VERDICT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Build violations artifact from full review output
# ---------------------------------------------------------------------------
INLINE_COMMENTS=$(jq -c '.inline_comments // []' pipeline-output.json)
INLINE_COUNT=$(echo "$INLINE_COMMENTS" | jq 'length')

if [[ "$INLINE_COUNT" -gt 0 ]]; then
  ARTIFACT_VIOLATIONS=$(extract_violation_fields "$INLINE_COMMENTS" 1)
else
  ARTIFACT_VIOLATIONS='[]'
fi

# Inject violations_artifact into pipeline-output.json
jq --argjson artifact "$(jq -n \
  --argjson pr "${PR_NUMBER}" \
  --arg sha "$(git rev-parse HEAD)" \
  --argjson violations "$ARTIFACT_VIOLATIONS" \
  '{
    pr_number: ($pr | tonumber),
    last_push_sha: $sha,
    push_count: 1,
    active_violations: $violations
  }')" '.violations_artifact = $artifact' pipeline-output.json > pipeline-output-tmp.json
mv pipeline-output-tmp.json pipeline-output.json

echo "Artifact prepared: ${INLINE_COUNT} violations"
