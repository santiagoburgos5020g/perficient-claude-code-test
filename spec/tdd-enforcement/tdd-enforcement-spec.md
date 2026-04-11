# TDD Enforcement Specification for Next.js E-Commerce Project

**Version:** 1.0
**Date:** April 10, 2026
**Status:** Ready for Implementation

---

## 1. Executive Summary

This specification defines the implementation of automated Test-Driven Development (TDD) enforcement for the Next.js e-commerce project. The system uses git pre-commit hooks to ensure all React component files (`.tsx`) within designated directories have co-located test files achieving 100% code coverage before commits are allowed.

---

## 2. Scope

### 2.1 In Scope

Only React component files (`.tsx`) located in the following directories require tests:

| Directory Pattern | Examples |
|---|---|
| `features/**/components/**/*.tsx` | `features/products/components/ProductCard.tsx` |

> **Note:** The project uses a feature-based architecture. Components live under `features/{feature}/components/`, not a root-level `/components` or `/app` directory. The project uses the **Pages Router** (`pages/` directory), not the App Router.

### 2.2 Out of Scope — No Tests Required

| Category | Examples |
|---|---|
| Page files | `pages/index.tsx`, `pages/_app.tsx`, `pages/_document.tsx` |
| API routes | `pages/api/products/index.ts` |
| Hooks | `features/products/hooks/useInfiniteScroll.ts` |
| Type definitions | `features/products/types/product.ts`, `*.d.ts` |
| Utilities | `features/products/utils/formatPrice.ts` |
| Configuration | `next.config.js`, `tailwind.config.ts`, `jest.config.js` |
| Prisma files | `prisma/schema.prisma`, `prisma/seed.ts` |
| Style files | `styles/globals.css` |
| Barrel exports | `index.ts` re-export files |

### 2.3 Rationale

The user explicitly specified that **only components** require enforced TDD. Utilities, hooks, services, API routes, and configuration files are excluded from enforcement.

---

## 3. Technical Stack

### 3.1 Testing Framework

| Tool | Purpose | Version |
|---|---|---|
| **Jest** | Test runner | `^29.0.0` |
| **React Testing Library** (`@testing-library/react`) | Component rendering and querying | `^14.0.0` |
| **@testing-library/jest-dom** | Custom DOM matchers (`toBeInTheDocument`, etc.) | `^6.0.0` |
| **@testing-library/user-event** | Simulating user interactions | `^14.0.0` |
| **jest-environment-jsdom** | Browser-like DOM environment for tests | `^29.0.0` |
| **ts-jest** | TypeScript support in Jest | `^29.0.0` |
| **@types/jest** | TypeScript type definitions for Jest | `^29.0.0` |

### 3.2 Git Hook Management

| Tool | Purpose | Version |
|---|---|---|
| **Husky** | Git hook management | `^9.0.0` |
| **cross-env** | Cross-platform environment variable setting | `^7.0.0` |

### 3.3 Coverage Tool

Jest's built-in coverage via Istanbul. No additional coverage tool needed.

---

## 4. Test File Requirements

### 4.1 Naming Convention

```
Component file:     {ComponentName}.tsx
Test file:          {ComponentName}.test.tsx
Location:           Same directory (co-located)
```

**Example:**
```
features/products/components/ProductCard.tsx
features/products/components/ProductCard.test.tsx
```

### 4.2 Content Requirements

Every test file must contain all of the following:

1. At least one `describe()` block
2. At least one `test()` or `it()` block inside the describe
3. At least one `render()` call from `@testing-library/react`
4. At least one `expect()` assertion
5. Achieve **100% code coverage** of the corresponding component (see Section 5)

A test file that is empty, contains only imports, or has no executable test blocks will be rejected.

### 4.3 Coverage Thresholds (Per File)

All four coverage metrics must reach 100% for each individual component file:

| Metric | Threshold |
|---|---|
| Line Coverage | 100% |
| Branch Coverage | 100% |
| Function Coverage | 100% |
| Statement Coverage | 100% |

Coverage is measured **per file**, not globally. Each component must independently meet the threshold.

---

## 5. Git Hook Implementation

### 5.1 Hook Type

**Pre-commit only.** The hook runs before every commit. If any check fails, the commit is blocked entirely.

### 5.2 Bypass Policy

- `git commit --no-verify` is technically available but **strongly discouraged**.
- Document `--no-verify` as reserved for emergency situations only.
- Consider logging bypass usage (see Section 12.3).

### 5.3 Pre-Commit Hook Workflow

```
1. Get list of staged files (git diff --cached --name-only --diff-filter=d)
2. Filter to only .tsx files matching: features/**/components/**/*.tsx
3. If no matching files → allow commit (exit 0)
4. For each matched component file:
   a. Compute expected test path: replace .tsx with .test.tsx (same directory)
   b. Check if test file exists on disk
      → If missing: record violation (type: "missing")
   c. If test file exists:
      - Run Jest with --coverage for that specific component file
      - Parse coverage output
      - If any metric < 100%: record violation (type: "coverage", include metrics)
5. If any violations → print error report, exit 1 (block commit)
6. If all pass → print success message, exit 0 (allow commit)
```

### 5.4 Scenarios

#### Scenario A: New Component Added
- **Trigger:** New `.tsx` file staged in `features/**/components/`
- **Action:** Check for co-located `.test.tsx` file and verify 100% coverage
- **On Failure:** Block commit, display missing test file or coverage gap

#### Scenario B: Existing Component Modified
- **Trigger:** Modified `.tsx` file staged in `features/**/components/`
- **Action:** Re-run coverage analysis against the updated component
- **On Failure:** Block commit if coverage drops below 100% for the modified component

#### Scenario C: Component Deleted
- **Trigger:** `.tsx` file deleted (detected via `--diff-filter=D`)
- **Action:** No enforcement. Deletion of the corresponding test file is optional.
- **Outcome:** Allow commit regardless

#### Scenario D: Only Test File Modified
- **Trigger:** Only `.test.tsx` file staged (no component file changes)
- **Action:** No enforcement needed
- **Outcome:** Allow commit

#### Scenario E: Non-Component .tsx File Modified
- **Trigger:** `.tsx` file staged outside `features/**/components/` (e.g., `pages/index.tsx`)
- **Action:** No enforcement
- **Outcome:** Allow commit

### 5.5 File Detection Logic

**Staged component file pattern (glob):**
```
features/**/components/**/*.tsx
```

**Exclusion pattern (must not match):**
```
**/*.test.tsx
**/*.spec.tsx
```

**Test file derivation:**
```
features/products/components/ProductCard.tsx
→ features/products/components/ProductCard.test.tsx
```

---

## 6. Jest Configuration

### 6.1 jest.config.js

```javascript
const nextJest = require('next/jest');

const createJestConfig = nextJest({
  dir: './',
});

/** @type {import('jest').Config} */
const customJestConfig = {
  testEnvironment: 'jsdom',
  setupFilesAfterSetup: ['<rootDir>/jest.setup.js'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
  collectCoverageFrom: [
    'features/**/components/**/*.tsx',
    '!features/**/components/**/*.test.tsx',
    '!features/**/components/**/*.spec.tsx',
  ],
  coverageThreshold: {
    global: {
      lines: 100,
      branches: 100,
      functions: 100,
      statements: 100,
    },
  },
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'text-summary', 'lcov', 'json-summary'],
};

module.exports = createJestConfig(customJestConfig);
```

**Key details:**
- Uses `next/jest` for automatic Next.js transforms (handles `next/image`, CSS modules, etc.)
- `moduleNameMapper` resolves the `@/*` path alias from `tsconfig.json`
- Coverage is collected only from component files in `features/**/components/`
- Test files themselves are excluded from coverage collection

### 6.2 jest.setup.js

```javascript
import '@testing-library/jest-dom';
```

This loads custom matchers like `toBeInTheDocument()`, `toHaveTextContent()`, etc.

### 6.3 Next.js Mocking

`next/jest` automatically handles transforms for:
- `next/image` → renders as a plain `<img>` in tests
- CSS/SCSS modules → returns an empty object
- Static file imports → returns the file path string

For components that use `next/router`, add a manual mock as needed in individual test files:

```typescript
jest.mock('next/router', () => ({
  useRouter: () => ({
    push: jest.fn(),
    query: {},
    pathname: '/',
  }),
}));
```

---

## 7. Error Handling & Messaging

### 7.1 Missing Test File

```
------------------------------------------------------------
  TDD ENFORCEMENT FAILED
------------------------------------------------------------

  Missing test file for component:

    Component: features/products/components/ProductCard.tsx
    Expected:  features/products/components/ProductCard.test.tsx

  Commit blocked. Create the test file with 100% coverage.
------------------------------------------------------------
```

### 7.2 Insufficient Coverage

```
------------------------------------------------------------
  TDD ENFORCEMENT FAILED
------------------------------------------------------------

  Insufficient test coverage for:

    Component: features/products/components/ErrorDisplay.tsx

    Coverage Report:
      Lines:      85.5%  (required: 100%)
      Branches:   75.0%  (required: 100%)
      Functions:  90.0%  (required: 100%)
      Statements: 85.5%  (required: 100%)

  Commit blocked. Update tests to achieve 100% coverage.
------------------------------------------------------------
```

### 7.3 Multiple Failures

```
------------------------------------------------------------
  TDD ENFORCEMENT FAILED
------------------------------------------------------------

  Found 3 components with violations:

  1. features/products/components/ProductCard.tsx
     -> Missing test file

  2. features/products/components/ErrorDisplay.tsx
     -> Coverage: Lines 78%, Branches 60%, Functions 90%, Statements 78%

  3. features/products/components/LoadingSpinner.tsx
     -> Missing test file

  Commit blocked. Fix all violations before committing.
------------------------------------------------------------
```

### 7.4 Success

```
  TDD Enforcement Passed - All components have tests with 100% coverage.
```

### 7.5 No Components Staged

```
  TDD Enforcement: No component files staged. Skipping checks.
```

---

## 8. Implementation Architecture

### 8.1 Project Structure (New/Modified Files)

```
project-root/
├── .husky/
│   └── pre-commit                 # Git hook entry point
├── scripts/
│   └── check-tdd.ts               # Main TDD validation script
├── jest.config.js                  # Jest configuration
├── jest.setup.js                   # Jest setup (jest-dom import)
├── package.json                    # Updated with new deps & scripts
└── .gitignore                      # Updated with coverage/ directory
```

### 8.2 Dependencies to Install

```json
{
  "devDependencies": {
    "@testing-library/react": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/user-event": "^14.0.0",
    "jest": "^29.0.0",
    "jest-environment-jsdom": "^29.0.0",
    "@types/jest": "^29.0.0",
    "ts-jest": "^29.0.0",
    "husky": "^9.0.0",
    "cross-env": "^7.0.0"
  }
}
```

### 8.3 Package.json Scripts

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:staged-components": "node scripts/check-tdd.js",
    "prepare": "husky"
  }
}
```

The `prepare` script ensures Husky is installed automatically when any developer runs `npm install`.

### 8.4 Husky Setup

```bash
npx husky init
```

This creates `.husky/pre-commit`. Edit its contents to:

```bash
npx ts-node scripts/check-tdd.ts
```

### 8.5 .gitignore Additions

```
coverage/
```

---

## 9. Validation Script — `scripts/check-tdd.ts`

### 9.1 Pseudocode

```typescript
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

interface Violation {
  type: 'missing' | 'coverage';
  componentPath: string;
  expectedTestPath?: string;
  coverage?: {
    lines: number;
    branches: number;
    functions: number;
    statements: number;
  };
}

function main(): void {
  // 1. Get staged .tsx files (excluding deleted files)
  const stagedFiles = execSync(
    'git diff --cached --name-only --diff-filter=d'
  ).toString().trim().split('\n').filter(Boolean);

  // 2. Filter to component files only
  const componentPattern = /^features\/.*\/components\/.*\.tsx$/;
  const testPattern = /\.(test|spec)\.tsx$/;
  const componentFiles = stagedFiles.filter(
    f => componentPattern.test(f.replace(/\\/g, '/')) && !testPattern.test(f)
  );

  // 3. If no component files staged, exit early
  if (componentFiles.length === 0) {
    console.log('TDD Enforcement: No component files staged. Skipping checks.');
    process.exit(0);
  }

  // 4. Check each component
  const violations: Violation[] = [];

  for (const component of componentFiles) {
    const testFile = component.replace(/\.tsx$/, '.test.tsx');

    // Check test file exists
    if (!fs.existsSync(testFile)) {
      violations.push({
        type: 'missing',
        componentPath: component,
        expectedTestPath: testFile,
      });
      continue;
    }

    // Run Jest with coverage for this specific file
    try {
      execSync(
        `npx jest --coverage --collectCoverageFrom="${component}" ` +
        `--coverageThreshold='${JSON.stringify({
          [`${path.resolve(component)}`]: {
            lines: 100, branches: 100, functions: 100, statements: 100
          }
        })}' ` +
        `"${testFile}" --passWithNoTests=false`,
        { stdio: 'pipe' }
      );
    } catch (error) {
      // Parse coverage from JSON summary if available
      const coverageSummaryPath = path.join('coverage', 'coverage-summary.json');
      let coverageData = { lines: 0, branches: 0, functions: 0, statements: 0 };

      if (fs.existsSync(coverageSummaryPath)) {
        const summary = JSON.parse(fs.readFileSync(coverageSummaryPath, 'utf-8'));
        const fileKey = path.resolve(component);
        if (summary[fileKey]) {
          coverageData = {
            lines: summary[fileKey].lines.pct,
            branches: summary[fileKey].branches.pct,
            functions: summary[fileKey].functions.pct,
            statements: summary[fileKey].statements.pct,
          };
        }
      }

      violations.push({
        type: 'coverage',
        componentPath: component,
        coverage: coverageData,
      });
    }
  }

  // 5. Report results
  if (violations.length > 0) {
    printViolations(violations);
    process.exit(1);
  }

  console.log('TDD Enforcement Passed - All components have tests with 100% coverage.');
  process.exit(0);
}

function printViolations(violations: Violation[]): void {
  console.error('------------------------------------------------------------');
  console.error('  TDD ENFORCEMENT FAILED');
  console.error('------------------------------------------------------------');
  console.error('');

  if (violations.length === 1) {
    const v = violations[0];
    if (v.type === 'missing') {
      console.error(`  Missing test file for component:`);
      console.error(`    Component: ${v.componentPath}`);
      console.error(`    Expected:  ${v.expectedTestPath}`);
    } else {
      console.error(`  Insufficient test coverage for:`);
      console.error(`    Component: ${v.componentPath}`);
      console.error(`    Lines:      ${v.coverage!.lines}%  (required: 100%)`);
      console.error(`    Branches:   ${v.coverage!.branches}%  (required: 100%)`);
      console.error(`    Functions:  ${v.coverage!.functions}%  (required: 100%)`);
      console.error(`    Statements: ${v.coverage!.statements}%  (required: 100%)`);
    }
  } else {
    console.error(`  Found ${violations.length} components with violations:`);
    violations.forEach((v, i) => {
      console.error(`  ${i + 1}. ${v.componentPath}`);
      if (v.type === 'missing') {
        console.error(`     -> Missing test file`);
      } else {
        console.error(
          `     -> Coverage: Lines ${v.coverage!.lines}%, ` +
          `Branches ${v.coverage!.branches}%, ` +
          `Functions ${v.coverage!.functions}%, ` +
          `Statements ${v.coverage!.statements}%`
        );
      }
    });
  }

  console.error('');
  console.error('  Commit blocked. Fix all violations before committing.');
  console.error('------------------------------------------------------------');
}

main();
```

### 9.2 Windows Compatibility Notes

- Use `path.resolve()` for all file path comparisons (normalizes separators).
- Use `path.join()` when constructing paths rather than string concatenation with `/`.
- The `cross-env` package handles environment variable differences between Windows and Unix.
- Git commands (`git diff --cached`) output forward-slash paths even on Windows. Normalize paths before comparing with filesystem paths.
- Test with both `cmd.exe` and Git Bash on Windows to ensure compatibility.

---

## 10. Developer Workflow

### 10.1 TDD Process (Required Order)

```
Step 1: Create the test file first
  → features/products/components/NewComponent.test.tsx

Step 2: Write failing tests (red phase)
  → Define what the component should render and how it should behave
  → Run: npm test -- features/products/components/NewComponent.test.tsx
  → Tests should fail (component doesn't exist yet)

Step 3: Create the component (green phase)
  → features/products/components/NewComponent.tsx
  → Write minimal code to make tests pass
  → Run: npm test -- features/products/components/NewComponent.test.tsx

Step 4: Verify coverage
  → Run: npm run test:coverage -- --collectCoverageFrom="features/products/components/NewComponent.tsx"
  → Ensure all four metrics are at 100%

Step 5: Refactor if needed (refactor phase)
  → Improve code quality while keeping tests green and coverage at 100%

Step 6: Commit
  → git add features/products/components/NewComponent.tsx features/products/components/NewComponent.test.tsx
  → git commit -m "Add NewComponent"
  → Pre-commit hook runs automatically and validates
```

### 10.2 Common Commands

| Command | Purpose |
|---|---|
| `npm test` | Run all tests |
| `npm test -- --watch` | Run tests in watch mode |
| `npm run test:coverage` | Run all tests with coverage report |
| `npm test -- path/to/Component.test.tsx` | Run a specific test file |
| `npm run test:coverage -- --collectCoverageFrom="path/to/Component.tsx"` | Coverage for a specific component |

---

## 11. Existing Codebase Strategy

### 11.1 Decision: Grandfather Existing Components

Existing components are **grandfathered in** — the hook only enforces TDD for components that appear in a commit's staged files. This means:

- Existing components without tests will **not** block unrelated commits.
- Once an existing component is **modified** and staged, it must then have a passing test file with 100% coverage.
- New components must have tests from the start.

### 11.2 Current Components Requiring Tests Upon Modification

| Component | Path |
|---|---|
| `ProductCard` | `features/products/components/ProductCard.tsx` |
| `ProductGrid` | `features/products/components/ProductGrid.tsx` |
| `LoadingSpinner` | `features/products/components/LoadingSpinner.tsx` |
| `ErrorDisplay` | `features/products/components/ErrorDisplay.tsx` |

---

## 12. Rollout Strategy

### 12.1 Phase 1: Setup (Week 1)

- Install all testing and hook dependencies
- Create `jest.config.js` and `jest.setup.js`
- Create `scripts/check-tdd.ts` validation script
- Initialize Husky and configure the pre-commit hook
- Add `coverage/` to `.gitignore`
- Update `package.json` with test scripts and `prepare` hook
- Write unit tests for the `check-tdd.ts` script itself
- Document the TDD workflow in the project README

### 12.2 Phase 2: Warning Mode (Week 2)

- Deploy the hook in **warning mode**: run all checks but `exit 0` regardless of result
- Monitor for false positives (files incorrectly flagged)
- Measure hook execution time; optimize if over 30 seconds
- Gather developer feedback on error messages and workflow

### 12.3 Phase 3: Full Enforcement (Week 3+)

- Switch hook to **blocking mode**: `exit 1` on violations
- Begin requiring tests for any newly created or modified components
- Track metrics (see Section 14)

---

## 13. Performance Considerations

### 13.1 Hook Execution Time Budget

- **Target:** Under 30 seconds for a typical commit (1-3 component files)
- **Warning threshold:** 30-60 seconds (log a warning suggesting the developer run tests in watch mode)
- **Hard timeout:** 120 seconds (abort with a message suggesting manual test run)

### 13.2 Optimization Strategies

- Run Jest only for the specific staged component files, not the entire test suite.
- Use `--bail` flag to fail fast on the first test failure.
- Consider `--maxWorkers=2` to limit CPU usage during the hook.
- Cache Jest transforms between runs (default behavior with `next/jest`).

### 13.3 Large Changeset Handling

If more than 10 component files are staged in a single commit:
- Run coverage checks in parallel batches (e.g., 3 at a time).
- Display a progress indicator: `Checking component 3/12...`

---

## 14. Success Metrics

### 14.1 Quantitative

| Metric | How to Measure |
|---|---|
| Component test coverage | `npm run test:coverage` report |
| Blocked commits per week | Git hook log output (optional tracking) |
| Average hook execution time | Timestamp logging in `check-tdd.ts` |
| % of components with tests | Count of `.test.tsx` files vs `.tsx` files in `features/**/components/` |

### 14.2 Qualitative

| Metric | How to Assess |
|---|---|
| Developer satisfaction | Team feedback / retrospectives |
| Bug reduction | Compare defect rates pre/post enforcement |
| Refactoring confidence | Developer survey |
| Code review efficiency | PR review time trends |

---

## 15. Testing Plan for the Hook System Itself

### 15.1 Unit Tests for `check-tdd.ts`

```
describe('TDD Enforcement Script', () => {
  test('allows commit when no component files are staged');
  test('detects missing test file for a staged component');
  test('detects insufficient coverage for a staged component');
  test('allows commit when all staged components have 100% coverage');
  test('handles deleted component files (no enforcement)');
  test('handles modified components by re-verifying coverage');
  test('reports multiple violations in a single commit');
  test('ignores .tsx files outside features/**/components/');
  test('ignores test files themselves (*.test.tsx)');
  test('handles Windows-style path separators');
  test('handles commit with only test file changes');
  test('handles empty staged file list');
});
```

### 15.2 Integration Tests

| Test Case | Steps | Expected Outcome |
|---|---|---|
| Missing test file | Stage a new component without a test file | Commit blocked |
| Passing component | Stage a component + test with 100% coverage | Commit allowed |
| Coverage gap | Stage a component + test with 80% coverage | Commit blocked |
| Deleted component | Stage deletion of a component | Commit allowed |
| Non-component .tsx | Stage `pages/index.tsx` modification | Commit allowed (no check) |
| Mixed commit | Stage a passing and a failing component | Commit blocked |
| Test-only change | Stage only a `.test.tsx` modification | Commit allowed |

---

## 16. CI/CD Integration (Recommended)

### 16.1 Recommendation

In addition to the pre-commit hook, add a CI pipeline step that runs the full component test suite with coverage. This provides a safety net for:

- Commits made with `--no-verify`
- Coverage regressions caused by dependency updates
- Validation on branches where the hook may not be installed

### 16.2 CI Configuration (Example — GitHub Actions)

```yaml
name: TDD Enforcement
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm ci
      - run: npx prisma generate
      - run: npm run test:coverage
```

This is a supplementary safeguard. The primary enforcement mechanism remains the pre-commit hook.

---

## 17. Maintenance

### 17.1 Ongoing Tasks

| Task | Frequency |
|---|---|
| Update Jest/RTL versions | Per major release |
| Review hook performance | Monthly |
| Update component directory patterns if architecture changes | As needed |
| Verify Windows/macOS/Linux compatibility | Per new developer onboard |
| Update error messages based on developer feedback | As needed |

### 17.2 Adding New Feature Directories

When a new feature is created (e.g., `features/cart/components/`), no configuration change is needed — the glob pattern `features/**/components/**/*.tsx` automatically covers it.

---

## 18. Developer Documentation

### 18.1 README Section to Add

```markdown
## Testing (TDD Enforcement)

This project enforces Test-Driven Development for all React components.

### Rules
- Every `.tsx` file in `features/**/components/` must have a co-located `.test.tsx` file
- Tests must achieve 100% code coverage (lines, branches, functions, statements)
- A pre-commit hook blocks commits that violate these rules

### Quick Start
1. Write your test file first: `ComponentName.test.tsx`
2. Write failing tests for the component's expected behavior
3. Create the component: `ComponentName.tsx`
4. Make tests pass with 100% coverage
5. Commit both files together

### Commands
- `npm test` — Run all tests
- `npm test -- --watch` — Watch mode
- `npm run test:coverage` — Full coverage report
```

---

## 19. Open Decisions Resolved

| Question from Interview | Resolution | Rationale |
|---|---|---|
| Next.js special files (layout, page, etc.) | **Excluded.** The project uses Pages Router; `_app.tsx`, `_document.tsx`, and page files in `pages/` are not subject to TDD enforcement. | Page files are compositional entry points, not reusable components. |
| Server Components vs Client Components | **Not applicable.** Pages Router does not use React Server Components. | Project architecture decision. |
| Existing codebase handling | **Grandfather existing components.** Enforce only when a component is staged in a commit. | Avoids blocking all development while backfilling tests. Encourages incremental adoption. |
| CI/CD integration | **Recommended as supplementary.** Pre-commit hook is primary; CI is a safety net. | Belt-and-suspenders approach without blocking local development speed. |
| Performance / acceptable hook time | **30-second target, 120-second hard timeout.** | Keeps the developer feedback loop tight without being unrealistically fast. |
| `--no-verify` bypass | **Allowed but discouraged.** Documented as emergency-only. | Blocking it entirely risks frustrating developers in legitimate edge cases; trust + documentation is preferable. |

---

## 20. Deliverables Checklist

- [ ] Install Jest, React Testing Library, jest-dom, user-event, jest-environment-jsdom, ts-jest, @types/jest
- [ ] Install Husky v9 and cross-env
- [ ] Create `jest.config.js` with Next.js integration and `@/*` path alias mapping
- [ ] Create `jest.setup.js` importing `@testing-library/jest-dom`
- [ ] Create `scripts/check-tdd.ts` validation script (per Section 9)
- [ ] Initialize Husky (`npx husky init`)
- [ ] Configure `.husky/pre-commit` to run the validation script
- [ ] Add `coverage/` to `.gitignore`
- [ ] Add `prepare`, `test`, `test:watch`, `test:coverage`, `test:staged-components` scripts to `package.json`
- [ ] Write unit tests for `scripts/check-tdd.ts`
- [ ] Write integration tests verifying the hook workflow end-to-end
- [ ] Update `README.md` with TDD workflow documentation
- [ ] Create example test files demonstrating patterns for existing components
- [ ] Verify the complete workflow on Windows (Git Bash and cmd.exe)
- [ ] Test the hook with: new component, modified component, deleted component, non-component file

---

**End of Specification**
