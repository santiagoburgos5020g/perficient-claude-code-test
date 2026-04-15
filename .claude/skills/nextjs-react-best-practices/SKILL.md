---
name: nextjs-react-best-practices
description: Strict Next.js 14 (Pages Router), React 18, and TypeScript 5 best practices reference — agents consult this during code creation, modification, and review to enforce correct frontend patterns including Container-Presentational, useSWR, Tailwind CSS, accessibility, and performance
when_to_use: "TRIGGER when: working with .tsx/.ts files in pages/, components/, containers/, hooks/, types/, styles/; building from mockups or wireframes; reviewing React components; creating useSWR hooks; checking accessibility or Tailwind usage. SKIP when: backend-only work (API routes, Prisma, database)"
effort: high
user-invocable: true
---

# Next.js 14 / React 18 / TypeScript 5 Best Practices Reference

Strict reference for frontend best practices in this project. Agents and subagents consult this as the authoritative source of truth during any code creation, modification, or review involving `.tsx`, `.ts` files in `pages/`, `components/`, `containers/`, `hooks/`, `types/`, `lib/`, `utils/`, or when building components from mockups.

## Workflow Overview

1. **Detect** — Identify code that violates a best practice defined in this skill
2. **Match** — Determine which category is relevant (see per-category "Code Smells")
3. **Evaluate** — Assess severity: Critical (must fix), Recommended (should fix), Informational (agent discretion)
4. **Act** — Refactor/create/modify code to follow the best practice, or flag the violation when reviewing

---

## Agent Decision Process

1. **Identify the task** — What is the code trying to accomplish?
2. **Check for violations** — Does the existing or proposed code violate any best practice? (See per-category "Code Smells")
3. **Match to a category** — Consult the relevant section
4. **Evaluate severity** — Critical, Recommended, or Informational
5. **Apply or flag** — If creating/modifying, follow the best practice. If reviewing, flag with explanation of *why* it matters.

### Key Rule: All Violations Must Be Addressed

This skill enforces strict compliance. Any component that violates these patterns must be refactored, created, or changed accordingly. No exceptions for Critical and Recommended findings.

---

## How the Categories Interact

- **Container-Presentational enables Testing** — Separated components are testable in isolation
- **TypeScript Strictness enables Error Handling** — Typed responses catch bugs at compile time
- **useSWR enforces Container-Presentational** — Data fetching lives in hooks/containers only
- **Folder Structure enforces Container-Presentational** — Separate directories make violations visible
- **Naming Conventions support Folder Structure** — `Container` suffix and `use` prefix clarify roles
- **Accessibility enables Testing** — Semantic HTML provides accessible queries for tests (`getByRole`)
- **Tailwind CSS supports Presentational Components** — Utility-first keeps styles co-located
- **Data Fetching Strategy drives Container-Presentational** — Where data is fetched determines the container

---

## The 13 Categories

1. Container-Presentational Component Pattern
2. Folder Structure
3. Naming Conventions
4. Component File Internal Structure
5. TypeScript Strictness
6. React 18 Hooks Best Practices
7. useSWR Best Practices
8. Error Handling
9. Testing Patterns
10. Tailwind CSS Conventions
11. Pages Router Data Fetching Strategy
12. Performance Optimization
13. Accessibility (a11y)

For complete rules, code smells, and examples for each category, see [reference.md](reference.md).

---

## Category Selection Quick Reference

| Problem | Category |
|---|---|
| Component mixes data fetching with rendering | 1 — Container-Presentational |
| File in wrong directory | 2 — Folder Structure |
| Inconsistent naming | 3 — Naming Conventions |
| Imports in wrong order | 4 — File Internal Structure |
| `any`, inline types, untyped responses | 5 — TypeScript Strictness |
| `useEffect` misuse, class components | 6 — React 18 Hooks |
| `fetch` + `useEffect`, untyped SWR | 7 — useSWR |
| Missing error boundary, unhandled API errors | 8 — Error Handling |
| Snapshot tests, `data-testid` first | 9 — Testing |
| Inline styles, `@apply`, wrong class order | 10 — Tailwind CSS |
| Wrong data fetching strategy | 11 — Data Fetching |
| Missing `next/image`, prop drilling | 12 — Performance |
| Non-semantic HTML, missing alt text | 13 — Accessibility |

---

## Refactoring Order When Multiple Categories Are Violated

1. **TypeScript Strictness** — Add proper types first
2. **Folder Structure** — Move files to correct locations
3. **Container-Presentational** — Split mixed components
4. **useSWR** — Replace `useEffect` + `fetch` patterns
5. **Remaining categories** — Naming, hooks, error handling, testing, Tailwind, performance, accessibility

---

## Important Notes

- This skill is specific to **Next.js 14.2 (Pages Router)**, **React 18**, **TypeScript 5**, **Tailwind CSS 3**, and **useSWR**.
- All Critical and Recommended violations must be addressed — this is enforced, not advisory.
- When reviewing, always explain *why* a best practice applies — don't just state the rule name.
- This skill complements `tdd-enforcement` (testing workflow) and `solid-principles-reference` (OOP principles). They do not overlap.
- The `ErrorBoundary` class component is the only exception to the "functional components only" rule.
- When building from mockups, always output the component tree diagram before writing any code.
- useSWR must be installed (`npm install swr`) before client-side data fetching can follow these patterns.
