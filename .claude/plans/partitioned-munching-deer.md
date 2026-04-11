# Plan: Add To Cart Button + TDD Enforcement Setup

## Context

Two specs are ready for implementation:
1. **TDD Enforcement** (`spec/tdd-enforcement/tdd-enforcement-spec.md`) — sets up Jest, RTL, Husky pre-commit hooks, and a `check-tdd.ts` validation script requiring 100% coverage for all components in `features/**/components/**/*.tsx`
2. **Add To Cart Button** (`spec/add-to-cart-button-specification.md`) — adds a non-functional "Add To Cart" button to `ProductCard`, pinned to the bottom of each card via flex layout

The project currently has **zero test infrastructure** — no Jest, no RTL, no test files. The TDD enforcement spec must be completed first so that the button implementation follows the red-green-refactor TDD workflow.

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Test file location** | Co-located: `ProductCard.test.tsx` next to `ProductCard.tsx` | TDD spec mandates this; `check-tdd.ts` derives test paths by replacing `.tsx` → `.test.tsx` in same dir. The button spec's `__tests__/` suggestion conflicts — TDD spec takes precedence as foundational infrastructure. |
| **Jest config extension** | `jest.config.js` (not `.ts`) | TDD spec section 6.1 uses CommonJS `require('next/jest')` — `.js` is the correct extension for this format |
| **Setup file extension** | `jest.setup.js` | TDD spec section 6.2 specifies `.js`; single import line needs no TypeScript |
| **`mt-auto` vs `mt-3`** | `mt-auto` on the button class | Button spec section 3.3.2 clarifies: `mt-auto` pushes button to bottom of flex container, ensuring alignment across cards with different content heights |
| **Rollout mode** | Direct enforcement (not warning mode) | The spec's phased rollout (warning → blocking) is for team adoption. Since we're building from scratch with TDD from the start, go straight to enforcement. |

---

## Phase 1: Test Infrastructure Setup

### Step 1.1 — Install dev dependencies
```bash
npm install --save-dev jest@^29.0.0 @testing-library/react@^14.0.0 @testing-library/jest-dom@^6.0.0 @testing-library/user-event@^14.0.0 jest-environment-jsdom@^29.0.0 ts-jest@^29.0.0 @types/jest@^29.0.0 husky@^9.0.0 cross-env@^7.0.0
```

### Step 1.2 — Create `jest.config.js` (project root)
- Use `next/jest` with `dir: './'`
- `testEnvironment: 'jsdom'`
- `setupFilesAfterSetup: ['<rootDir>/jest.setup.js']` (note: verify this key name — may need to be `setupFilesAfterFramework` depending on Jest 29 docs)
- `moduleNameMapper: { '^@/(.*)$': '<rootDir>/$1' }`
- `collectCoverageFrom`: include `features/**/components/**/*.tsx`, exclude `*.test.tsx` and `*.spec.tsx`
- `coverageThreshold`: 100% on all four metrics (lines, branches, functions, statements)
- `coverageReporters: ['text', 'text-summary', 'lcov', 'json-summary']`

Full config provided in TDD spec section 6.1.

### Step 1.3 — Create `jest.setup.js` (project root)
```js
import '@testing-library/jest-dom';
```

### Step 1.4 — Update `package.json` scripts
Add to existing `scripts` object:
- `"test": "jest"`
- `"test:watch": "jest --watch"`
- `"test:coverage": "jest --coverage"`
- `"test:staged-components": "node scripts/check-tdd.js"`
- `"prepare": "husky"`

### Step 1.5 — Add `coverage/` to `.gitignore`

### Step 1.6 — Initialize Husky
```bash
npx husky init
```
Then set `.husky/pre-commit` contents to:
```bash
npx ts-node scripts/check-tdd.ts
```

### Step 1.7 — Create `scripts/check-tdd.ts`
Full pseudocode in TDD spec section 9.1. Key logic:
1. `git diff --cached --name-only --diff-filter=d` → get staged files
2. Filter to `features/**/components/**/*.tsx`, exclude `*.test.tsx` / `*.spec.tsx`
3. If no matches → exit 0 with skip message
4. For each component: check `.test.tsx` exists in same dir → if missing, record violation
5. If test exists: run Jest with `--coverage` for that file, verify 100% on all metrics
6. Report violations with formatted error messages (TDD spec section 7)
7. Windows path normalization with `path.resolve()` for coverage JSON key lookups

### Step 1.8 — Verify infrastructure
```bash
npm test -- --passWithNoTests
```
Expect clean exit with no errors.

---

## Phase 2: Write Tests First (Red Phase)

### Step 2.1 — Create `features/products/components/ProductCard.test.tsx`

Mock `next/image` to render a plain `<img>` passing through all props (ensures `onError` handler is preserved for branch coverage):
```tsx
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}));
```

Test data:
```tsx
const mockProduct: Product = {
  id: 1,
  name: 'Test Product',
  description: 'Test Description',
  price: 99.99,
  image: '/test-image.jpg',
};
```

**9 required test cases:**
1. Button renders with exact text "Add To Cart"
2. Button has expected CSS classes (`w-full`, `bg-perficient-teal`, `text-white`, `text-sm`, `font-normal`, `py-3`, `mt-auto`, `rounded-none`, `cursor-default`)
3. Button is the last child element within `<article>`
4. Button click does not throw an error
5. Button has `aria-label` = `"Add Test Product to cart"`
6. Button has `type="button"`
7. Article element has `flex` and `flex-col` classes
8. Button renders correctly when image is in error fallback state (fire `onError` on `<img>`, verify "No image" text AND button both present)
9. Existing ProductCard behavior preserved (product name, description, formatted price `$99.99`, image)

**Branch coverage note:** Test 8 covers the `imgError === true` branch. Other tests cover `imgError === false`. This ensures 100% branch coverage of the ternary.

### Step 2.2 — Run tests, confirm failure (Red)
```bash
npx jest features/products/components/ProductCard.test.tsx
```
Expect: tests for button (1-8) fail; test 9 (existing behavior) passes.

---

## Phase 3: Implement Component Change (Green Phase)

### Step 3.1 — Modify `features/products/components/ProductCard.tsx`

**Change 1:** Add `flex flex-col` to the `<article>` className (line 14):
```
bg-white shadow-md hover:shadow-xl rounded-none p-4 transition-shadow duration-200 flex flex-col
```

**Change 2:** Add button before closing `</article>` (after price `<p>` on line 33):
```tsx
<button
  type="button"
  className="w-full bg-perficient-teal text-white text-sm font-normal py-3 mt-auto rounded-none cursor-default"
  onClick={() => {}}
  aria-label={`Add ${product.name} to cart`}
>
  Add To Cart
</button>
```

No new imports. No new state. No new props.

### Step 3.2 — Run tests, confirm all pass (Green)
```bash
npx jest features/products/components/ProductCard.test.tsx
```

### Step 3.3 — Verify 100% coverage
```bash
npx jest --coverage --collectCoverageFrom="features/products/components/ProductCard.tsx" features/products/components/ProductCard.test.tsx
```
Expect: 100% lines, branches, functions, statements.

---

## Phase 4: Refactor (if needed)

Review test file for shared setup (`beforeEach` for repeated renders). Re-run tests + coverage after any changes.

---

## Phase 5: Verification

### 5.1 — Full test suite
```bash
npm test
```

### 5.2 — Manual testing with dev server
```bash
npm run dev
```
Verify per button spec section 6.5:
- Button on every product card, full width, pinned to bottom
- Buttons vertically aligned across cards with different description lengths
- Correct color (#004d57), white text, "Add To Cart"
- No hover effect, no click effect, cursor stays default arrow
- Keyboard accessible (Tab), visible focus outline
- Image fallback cards show button identically
- Check mobile (<768px), tablet (768-1024px), desktop (>1024px) viewports

### 5.3 — Test pre-commit hook
Stage both files and commit — hook should detect `ProductCard.tsx`, find `ProductCard.test.tsx`, verify 100% coverage, and allow the commit.

---

## Files to Create/Modify

| # | File | Action | Phase |
|---|------|--------|-------|
| 1 | `package.json` | Modify (deps auto-added by npm install; add scripts) | 1 |
| 2 | `jest.config.js` | **Create** | 1 |
| 3 | `jest.setup.js` | **Create** | 1 |
| 4 | `.gitignore` | Modify (add `coverage/`) | 1 |
| 5 | `.husky/pre-commit` | **Create** (via `npx husky init`, then edit) | 1 |
| 6 | `scripts/check-tdd.ts` | **Create** | 1 |
| 7 | `features/products/components/ProductCard.test.tsx` | **Create** | 2 (Red) |
| 8 | `features/products/components/ProductCard.tsx` | Modify (add flex layout + button) | 3 (Green) |

---

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| `next/image` mock drops `onError` prop → branch coverage gap | Explicit `jest.mock('next/image')` passes all props through to `<img>` |
| `setupFilesAfterSetup` may not be valid Jest 29 key | Verify on first run; correct to `setupFilesAfterFramework` if needed |
| `ts-node` issues running `check-tdd.ts` on Windows | Project already uses `ts-node` for Prisma seed; use same `--compiler-options {"module":"CommonJS"}` pattern if needed |
| Git path separators on Windows | Normalize with `path.resolve()` and `.replace(/\\/g, '/')` in `check-tdd.ts` |
| Coverage JSON uses absolute paths as keys (Windows backslashes) | Use `path.resolve(component)` to match key format |
