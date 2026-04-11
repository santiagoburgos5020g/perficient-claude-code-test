---
name: tdd-enforcement
description: >
  Enforce Test-Driven Development for React components and pages. TRIGGER when: creating or modifying .tsx files in features/**/components/** or pages/**, user asks to create a component or page, user asks to add a feature that involves components or pages, or user asks about TDD workflow. Ensures tests are written BEFORE component/page code, with 100% coverage using Jest + React Testing Library.
argument-hint: [component-or-page-name]
allowed-tools: Read Grep Glob Bash(npx jest:*) Bash(npm test:*) Bash(npm run test:*)
paths: "features/**/components/**/*.tsx,pages/**/*.tsx"
---

# TDD Enforcement for React Components and Pages

You are enforcing strict Test-Driven Development for all React component files (`.tsx`) located in `features/**/components/**/*.tsx` and all page files (`.tsx`) located in `pages/**/*.tsx`.

## Scope

### Files that REQUIRE TDD enforcement

All `.tsx` files matching these glob patterns:

```
features/**/components/**/*.tsx
pages/**/*.tsx
```

Excluding test files themselves (`*.test.tsx`, `*.spec.tsx`) and Next.js special files (`_app.tsx`, `_document.tsx`).

### Files that do NOT require TDD enforcement

- Next.js special files: `pages/_app.tsx`, `pages/_document.tsx`
- API routes: `pages/api/**`
- Hooks: `features/**/hooks/**`
- Types: `features/**/types/**`, `*.d.ts`
- Utilities: `features/**/utils/**`
- Configuration: `next.config.js`, `tailwind.config.ts`, `jest.config.js`
- Prisma files: `prisma/**`
- Style files: `styles/**`
- Barrel exports: `index.ts` re-export files

## Core Rule: Tests FIRST, Code SECOND

When creating or modifying a component or page, you MUST follow this exact order. Never write or modify component/page code before the corresponding test exists and fails.

### Creating a new component

**Step 1 - Create the test file FIRST:**

Create `{ComponentName}.test.tsx` in the same directory where the component will live.

The test file MUST contain:
1. At least one `describe()` block
2. At least one `test()` or `it()` block inside the describe
3. At least one `render()` call from `@testing-library/react`
4. At least one `expect()` assertion
5. Tests that define the component's expected behavior

```typescript
// Example: features/products/components/NewComponent.test.tsx
import { render, screen } from '@testing-library/react';
import NewComponent from './NewComponent';

describe('NewComponent', () => {
  test('renders correctly', () => {
    render(<NewComponent />);
    expect(screen.getByRole('...')).toBeInTheDocument();
  });
});
```

**Step 2 - Run the test to confirm it FAILS (Red phase):**

```bash
npx jest features/products/components/NewComponent.test.tsx
```

The test should fail because the component does not exist yet. Confirm the failure before proceeding.

**Step 3 - Create the component with minimal code to pass (Green phase):**

Create `{ComponentName}.tsx` in the same directory. Write only the minimum code needed to make the tests pass.

**Step 4 - Run the test to confirm it PASSES:**

```bash
npx jest features/products/components/NewComponent.test.tsx
```

**Step 5 - Verify 100% coverage:**

```bash
npx jest --coverage --collectCoverageFrom="features/products/components/NewComponent.tsx" features/products/components/NewComponent.test.tsx
```

All four metrics must be 100%:
- Lines: 100%
- Branches: 100%
- Functions: 100%
- Statements: 100%

If any metric is below 100%, add more tests to cover the missing paths before writing any more component code.

**Step 6 - Refactor if needed (Refactor phase):**

Improve code quality while keeping tests green and coverage at 100%. Re-run tests after each refactor.

### Creating a new page

**Step 1 - Create the test file FIRST:**

Create `{pageName}.test.tsx` in the same directory as the page file (`pages/`).

```typescript
// Example: pages/products.test.tsx
import { render, screen } from '@testing-library/react';
import ProductsPage from './products';

describe('ProductsPage', () => {
  test('renders the products page', () => {
    render(<ProductsPage />);
    expect(screen.getByRole('heading', { name: /products/i })).toBeInTheDocument();
  });
});
```

**Step 2 - Run the test to confirm it FAILS (Red phase):**

```bash
npx jest pages/products.test.tsx
```

**Step 3 - Create the page with minimal code to pass (Green phase):**

Create the page file in `pages/`. Write only the minimum code needed to make the tests pass.

**Step 4 - Run the test to confirm it PASSES:**

```bash
npx jest pages/products.test.tsx
```

**Step 5 - Verify 100% coverage:**

```bash
npx jest --coverage --collectCoverageFrom="pages/products.tsx" pages/products.test.tsx
```

All four metrics must be 100%. If any metric is below 100%, add more tests first.

**Step 6 - Refactor if needed (Refactor phase).**

### Modifying an existing component or page

1. First check if the corresponding `.test.tsx` file exists in the same directory
2. If it does NOT exist, create it with full coverage of the current behavior BEFORE making any changes
3. Write new/updated tests for the desired behavior change FIRST
4. Run tests to confirm the new tests fail (Red phase)
5. Modify the component/page to make all tests pass (Green phase)
6. Verify 100% coverage
7. Refactor if needed

## Test File Requirements

### Naming and location (co-located)

```
Component:  features/{feature}/components/{ComponentName}.tsx
Test:       features/{feature}/components/{ComponentName}.test.tsx

Page:       pages/{pageName}.tsx
Test:       pages/{pageName}.test.tsx
```

### Coverage thresholds (per file, not global)

| Metric     | Required |
|------------|----------|
| Lines      | 100%     |
| Branches   | 100%     |
| Functions  | 100%     |
| Statements | 100%     |

### What makes a valid test file

A test file is INVALID and must be fixed if it:
- Is empty or contains only imports
- Has no `describe()` block
- Has no `test()` or `it()` block
- Has no `render()` call from `@testing-library/react`
- Has no `expect()` assertion

## Testing patterns

### Basic component rendering

```typescript
import { render, screen } from '@testing-library/react';
import ComponentName from './ComponentName';

describe('ComponentName', () => {
  test('renders expected content', () => {
    render(<ComponentName />);
    expect(screen.getByText('Expected text')).toBeInTheDocument();
  });
});
```

### Page rendering

```typescript
// Example: pages/index.test.tsx
import { render, screen } from '@testing-library/react';
import HomePage from './index';

describe('HomePage', () => {
  test('renders the home page', () => {
    render(<HomePage />);
    expect(screen.getByRole('heading')).toBeInTheDocument();
  });
});
```

### Pages using next/router

```typescript
import { render, screen } from '@testing-library/react';
import ProductPage from './[id]';

jest.mock('next/router', () => ({
  useRouter: () => ({
    query: { id: '1' },
    push: jest.fn(),
    pathname: '/products/1',
  }),
}));

describe('ProductPage', () => {
  test('renders product details', () => {
    render(<ProductPage />);
    expect(screen.getByRole('heading')).toBeInTheDocument();
  });
});
```

### Components with props

```typescript
test('renders with provided props', () => {
  render(<ComponentName title="Test" price={29.99} />);
  expect(screen.getByText('Test')).toBeInTheDocument();
  expect(screen.getByText('$29.99')).toBeInTheDocument();
});
```

### User interactions

```typescript
import userEvent from '@testing-library/user-event';

test('calls handler on click', async () => {
  const user = userEvent.setup();
  const handleClick = jest.fn();
  render(<ComponentName onClick={handleClick} />);
  await user.click(screen.getByRole('button'));
  expect(handleClick).toHaveBeenCalledTimes(1);
});
```

### Conditional rendering (branch coverage)

```typescript
test('renders loading state', () => {
  render(<ComponentName isLoading={true} />);
  expect(screen.getByRole('status')).toBeInTheDocument();
});

test('renders content when not loading', () => {
  render(<ComponentName isLoading={false} />);
  expect(screen.queryByRole('status')).not.toBeInTheDocument();
});
```

### Components using next/router

```typescript
jest.mock('next/router', () => ({
  useRouter: () => ({
    push: jest.fn(),
    query: {},
    pathname: '/',
  }),
}));
```

## Argument handling

If invoked as `/tdd-enforcement ComponentOrPageName`:
- Search for the component at `features/**/components/$ARGUMENTS.tsx`
- Also search for a page at `pages/$ARGUMENTS.tsx`
- If found, check for co-located test file and run coverage analysis
- If not found, guide the user through creating the test file first, then the component or page

## Verification commands

| Purpose | Command |
|---------|---------|
| Run specific test | `npx jest path/to/Component.test.tsx` |
| Run with coverage | `npx jest --coverage --collectCoverageFrom="path/to/Component.tsx" path/to/Component.test.tsx` |
| Run all tests | `npm test` |
| Watch mode | `npm test -- --watch` |

## When you must STOP and alert the user

- If asked to create a component or page without writing tests first, REFUSE. Explain TDD requires tests first.
- If asked to skip tests or coverage, REFUSE. Explain the 100% coverage requirement.
- If coverage is below 100% after writing tests, DO NOT proceed to commit. Add more tests first.
- If a test file is empty or has no real assertions, flag it as invalid.
- The only page files exempt from TDD are `_app.tsx` and `_document.tsx` (Next.js special files) and API routes (`pages/api/**`).
