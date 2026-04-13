---
name: claude-examples-generator
description: Generate practical, copy-paste examples of Claude Code capabilities by topic. Auto-adapts to project context and handles versioning. TRIGGER when: user asks for Claude Code examples, configuration help, or invokes directly
disable-model-invocation: true
allowed-tools: Read, Write, Bash(mkdir *), Glob, Grep
argument-hint: [topic-name]
---

# Claude Examples Generator

Generate practical, copy-paste examples of Claude Code capabilities organized by topic. Creates versioned examples in `/examples/{topic}/` with intelligent project context awareness and capability mapping.

## Workflow Overview

1. **Topic Acquisition** — Interactive prompt or argument parsing
2. **Context Analysis** — Detect project tech stack and existing Claude config
3. **Capability Mapping** — Intelligently select relevant Claude Code features
4. **Version Management** — Auto-increment versions in topic subdirectories
5. **Template Generation** — Create detailed, copy-pasteable examples
6. **Integration Guidance** — Show how examples work with existing config

---

## Step 1: Topic Acquisition

### With Argument
If invoked as `/claude-examples-generator "dependency management"`:
- Extract and validate topic from argument
- Proceed directly to context analysis

### Interactive Mode
If invoked without arguments:
- Ask: **"What topic would you like Claude Code examples for?"**
- Provide suggestions: `"Examples: 'dependency management', 'testing workflows', 'git automation', 'code style enforcement'"`
- Wait for user response
- **Always translate topic to English** before processing if user provides input in another language

## Step 2: Topic Validation & Normalization

### Input Processing
- **Always translate topic to English** before processing if user provides input in another language
- Remove special characters, normalize whitespace
- Convert to lowercase with hyphens for slug (e.g., "Testing & QA" → "testing-qa")
- Limit to 50 characters max
- Reject empty, too short (<3 chars), or nonsensical input
- **All file and folder names must be in English**

### Topic Classification
- **Translation first:** Translate non-English topics to English automatically
- **Direct mapping:** Known topics with predefined capability sets
- **Fuzzy matching:** Similar topics (e.g., "deps" → "dependency management")  
- **Clarification needed:** Ask follow-up questions for vague topics
- **Unsupported:** Explain if topic isn't relevant to Claude Code

## Step 3: Project Context Analysis

### Detect Current Project
Use `Read` and `Glob` to analyze:
- `package.json` for tech stack (React, Vue, Node.js, etc.)
- Existing `.claude/` structure and configurations
- Testing frameworks (Jest, Vitest, Cypress)
- Build tools (Vite, Webpack, Next.js)
- Linting/formatting tools (ESLint, Prettier)

### Adapt Examples Based on Context
- **React projects** → Include component testing examples
- **Node.js APIs** → Include API testing and validation examples  
- **Existing rules** → Reference or build upon existing configurations
- **Detected tools** → Use specific tool commands in hooks examples

## Step 4: Intelligent Capability Mapping

### Base Capability Mappings
Map topics to relevant Claude Code features:

| Topic | Capabilities |
|-------|-------------|
| **Dependency Management** | Rules (package manager enforcement) + Memory (preferences) + Hooks (install validation) |
| **Testing Workflows** | Rules (TDD/testing standards) + Memory (testing preferences) + Skills (test automation) + Hooks (pre-commit testing) |
| **Code Style** | Rules (style enforcement) + Memory (style preferences) + Hooks (formatting on save) |
| **Git Workflows** | Rules (commit standards) + Memory (git preferences) + Hooks (pre-commit, pre-push) + Skills (git automation) |
| **Security** | Rules (security practices) + Memory (security settings) + Hooks (security scanning) + Skills (security validation) |
| **Performance** | Memory (performance preferences) + Hooks (performance monitoring) + Skills (performance testing) |
| **Development Setup** | Rules (environment standards) + Memory (setup preferences) + Hooks (startup validation) |

### Dynamic Selection Rules
- **Only include relevant capabilities** — Don't force all types for every topic
- **Check existing config** — Avoid duplicates, reference existing configurations
- **Project context aware** — Adapt based on detected tech stack
- **Show interdependencies** — Explain when capabilities work together

## Step 5: Directory Structure & Version Management

### Version Discovery
Use `Glob` to check existing structure:
```bash
examples/{topic-slug}/v*.md
```

### Atomic Directory Creation
1. Check if `/examples/{topic-slug}/` exists
2. Scan for existing versions: `v1.md`, `v2.md`, etc.
3. Determine next version number (max + 1)
4. Create directory atomically if needed using `Bash(mkdir -p)`

### Handle Edge Cases
- **Gaps in numbering:** Skip corrupted files, continue sequence
- **Permission issues:** Clear error messages with solutions
- **Concurrent access:** Handle multiple users gracefully

## Step 6: Template-Based Example Generation

### Standard Template Structure
Create examples following this format:

```markdown
# {Topic Name} - v{X}
*Generated on {date} for {detected-tech-stack}*

{project_context_note if relevant}

## Rules (.claude/rules/)

### {specific-rule-name}.md
**File:** `.claude/rules/{specific-rule-name}.md`
**When to use:** {context-specific explanation}
**Dependencies:** {list any required existing config}

**Content:**
```{exact copyable content}
```

**Result:** {what Claude will do with this rule}
**Verify:** {how to test the rule is working}

---

## Memory (.claude/memory/)

### {memory-name}.md  
**File:** `.claude/memory/{memory-name}.md`
**When to use:** {explanation}
**References:** {link to related rules if any}

**Content:**
```markdown
---
name: {memory-name}
description: {description}
type: {user|feedback|project|reference}
---

{memory content}
```

**Result:** {what Claude will remember}
**Verify:** {how to confirm memory is loaded}

---

## Skills (.claude/skills/) 
{Only if relevant to topic}

## Hooks (settings.json)
{Only if relevant to topic, show integration with existing hooks}

## Keybindings (~/.claude/keybindings.json)
{Only if relevant - shortcuts for topic-specific actions}
```

### Content Quality Standards
- **All content must be generated in English** (descriptions, explanations, comments)
- **All file and directory names must be in English** 
- All file paths must be exact and correct for current OS
- All code blocks must be syntactically valid
- All commands must work in the detected environment  
- Include verification steps for each example
- Show integration points between different capabilities

## Step 7: Cross-Reference Integration

### Check Existing Claude Config
Use `Read` and `Glob` to scan `.claude/` directory:
- Reference related existing rules
- Mention complementary memory entries
- Cross-reference existing skills that work with the topic
- Show integration with current setup

### Avoid Conflicts
- **Rule conflicts:** Warn user and suggest resolution strategies
- **Memory overlap:** Show merge strategies rather than overwrites
- **Hook conflicts:** Provide guidance on hook order and compatibility

## Step 8: Output Validation & User Notification

### Validate Generated Content
Before saving, verify:
- All file paths are valid for current OS
- All code syntax is correct (YAML frontmatter, markdown, bash commands)
- All referenced tools exist in detected environment
- Cross-references point to valid locations

### User Notification Format
```
✅ Created examples/{topic-slug}/v{X}.md

📊 Included capabilities: Rules (2), Memory (1), Hooks (3)
📁 Previous versions: v1.md, v2.md available for reference  
🔧 Tailored for: {detected-tech-stack}
⚡ Integration: {mentions any existing config integration}

💡 Next steps:
1. Review examples in examples/{topic-slug}/v{X}.md
2. Copy desired sections to your .claude/ directory
3. Restart Claude Code to load new configuration
```

**Note:** All content, file names, and directory names are generated in English for consistency and best practices.

---

## Advanced Features

### Smart Suggestions
When topic is unclear, provide contextual suggestions:
- **Vague input:** "automation" → Ask for specific type
- **Typos:** "testin" → "Did you mean 'testing'?"
- **Context-aware:** In React project, suggest "component testing", "build automation"

### Error Handling & Recovery
- **Generation fails midway:** Allow resume from last successful step
- **Permission issues:** Provide clear error messages with actionable solutions
- **Invalid input:** Guide user to valid topic formats

### Integration with Existing Config
- **Existing rules:** Reference and build upon current configuration
- **Memory conflicts:** Show merge strategies
- **Hook integration:** Demonstrate how to combine with existing hooks

---

## Edge Cases

### Topic Handling
- **Multi-concept topics:** "testing and deployment" → Split intelligently or provide comprehensive examples
- **Technology-specific:** "React testing" → Focus on React-specific examples with general principles
- **Unknown topics:** Suggest alternatives or explain limitations

### Project Context
- **No package.json:** Provide generic examples with customization notes
- **Multiple frameworks:** Ask for clarification or provide examples for both
- **Legacy projects:** Include upgrade path examples

### Version Management
- **Corrupted files:** Skip and continue numbering sequence
- **Manual versions:** Work around custom naming schemes
- **Empty directory:** Start with v1.md

---

## Template Examples

### Rule Template - Package Manager Enforcement
```markdown
Always use pnpm, never npm or yarn.

When installing dependencies, always use `pnpm install` or `pnpm add`.
Never suggest npm, yarn, or other package managers.

This project uses pnpm for faster installs and better disk efficiency.
```

### Memory Template - User Preferences
```markdown
---
name: dependency-management-preferences
description: User preferences for dependency management workflows
type: user
---

User prefers pnpm for all package management operations.
Always suggest pnpm commands when working with dependencies.
Project uses pnpm workspaces for monorepo management.
```

### Hook Template - Pre-commit Validation
```json
{
  "pre-commit": "pnpm run type-check && pnpm run lint && pnpm run test:quick"
}
```

---

## Important Notes

- **Only include relevant capabilities** — Don't force unnecessary features for simple topics
- **Project context matters** — Always adapt examples to detected tech stack
- **Version history is valuable** — Never overwrite existing versions, always increment
- **Copy-paste ready** — All examples must work immediately without modification
- **Integration first** — Show how new config works with existing Claude setup
- **Clear verification** — Include steps to test that examples work correctly

## Usage Examples

### Basic Usage
```
/claude-examples-generator
→ "What topic would you like Claude Code examples for?"
→ "dependency management"
→ Creates examples/dependency-management/v1.md
```

### Direct Topic
```
/claude-examples-generator "testing workflows"
→ Analyzes project (React + Jest detected)
→ Creates examples/testing-workflows/v1.md with React-specific examples
```

### Existing Topic
```
/claude-examples-generator "git automation"
→ Detects examples/git-automation/v1.md and v2.md exist
→ Creates examples/git-automation/v3.md
→ References previous versions for comparison
```