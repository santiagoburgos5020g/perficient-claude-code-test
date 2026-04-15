# Next.js 14 / React 18 / TypeScript 5 Best Practices — Skill Specification

## Overview

A background reference skill that agents automatically consult during code creation, modification, and review. It enforces best practices for **Next.js 14 (Pages Router)**, **React 18**, and **TypeScript 5** with **Tailwind CSS 3** in a Next.js e-commerce project.

This skill is **not user-invocable** — it operates as passive knowledge that agents and subagents load automatically when working with frontend code.

## Purpose

- Serve as the authoritative source of truth for frontend best practices in this project
- Enforce strict adherence to the Container-Presentational Component Pattern
- Guide agents when building components from mockups (Figma, images, wireframes)
- Ensure consistent folder structure, naming conventions, and code patterns
- Complement the existing `tdd-enforcement` and `solid-principles-reference` skills

## Trigger Conditions

Agents should consult this skill when:

- Creating or modifying `.tsx`, `.ts` files in `pages/`, `components/`, `containers/`, `hooks/`, `types/`
- Building components from a mockup, image, or wireframe
- Reviewing frontend code for best practice violations
- Making data fetching decisions (server-side vs client-side)
- Adding or modifying styles with Tailwind CSS

---

## Workflow Overview

1. **Detect** — Identify code that violates a best practice defined in this skill
2. **Match** — Determine which category of best practice is relevant
3. **Evaluate** — Assess the violation severity
4. **Act** — Refactor, create, or modify code to follow the best practice (when creating/modifying) or flag the violation (when reviewing)

### Severity Levels

- **Critical** — A best practice is clearly violated and causes maintainability, performance, or correctness problems. Must be fixed.
- **Recommended** — Following the best practice would improve the code but the current approach is functional.
- **Informational** — A best practice could apply but the code is simple enough that enforcement would be over-engineering.

### Key Rule: All Violations Must Be Addressed

Unlike advisory guidelines, this skill enforces strict compliance. Any component that violates the patterns defined here should be refactored, created, or changed to follow these principles. No exceptions.

---

## 1. Container-Presentational Component Pattern

### Statement

All components must follow the Container-Presentational pattern. Components that mix data fetching/business logic with rendering are violations and must be refactored.

### Definitions

- **Presentational Components**: Concerned only with how things look. Receive data and callbacks via props. No data fetching, no business logic, no state management beyond UI state (e.g., toggle open/closed). Pure rendering.
- **Container Components**: Concerned with how things work. Handle data fetching (useSWR, getServerSideProps, getStaticProps), business logic, state management, and pass data/callbacks down to presentational components.

### Rules

- A presentational component must NEVER import useSWR, call fetch, or contain business logic
- A container component must NEVER contain JSX beyond rendering its presentational component(s) and wrapping layout
- Pages (`pages/*.tsx`) act as containers — they handle data fetching and compose presentational components
- If a component does both data fetching and rendering, it must be split

### Mockup-to-Code Workflow

When building components from a mockup (Figma, image, wireframe), follow this exact order:

**Step 1 — Decompose the mockup into a component tree:**
- Identify the visual hierarchy
- Determine which parts are presentational components (visual elements)
- Determine which parts are containers (data-dependent sections)
- Map out the parent-child relationships

**Step 2 — Define TypeScript interfaces for props:**
- Create explicit interfaces for every component's props before writing any JSX
- Place shared types in `types/`
- Place component-specific types co-located with the component

**Step 3 — Build presentational components first:**
- Create presentational components with typed props
- These should render correctly with hardcoded/mock data
- Style with Tailwind CSS

**Step 4 — Wire up container components:**
- Create container components that fetch data and manage state
- Pass data and callbacks to presentational components via props

---

## 2. Folder Structure

### Enforced Conventions

```
project-root/
  components/          # Reusable presentational components
    ProductCard/
      ProductCard.tsx
      ProductCard.test.tsx
  containers/          # Container components
    ProductListContainer/
      ProductListContainer.tsx
      ProductListContainer.test.tsx
  hooks/               # Custom hooks
    useProducts.ts
    useProducts.test.ts
  types/               # Shared TypeScript interfaces and types
    product.ts
    api.ts
  pages/               # Next.js route pages (act as containers)
    index.tsx
    products.tsx
    api/
      products/
        index.ts
  styles/              # Global styles
  utils/               # Utility functions
  lib/                 # External service configurations
```

### Rules

- `components/` — Only presentational components. No data fetching, no business logic.
- `containers/` — Only container components. Handle data fetching and state, render presentational components.
- `hooks/` — Only custom hooks. Each hook in its own file.
- `types/` — Only TypeScript interfaces, types, and enums. No runtime code.
- `pages/` — Only Next.js route pages and API routes. Pages act as containers.
- Each component/container lives in its own folder with its test file co-located.

---

## 3. Naming Conventions

### Files and Folders

| Type | Convention | Example |
|---|---|---|
| Presentational component | PascalCase | `ProductCard.tsx` |
| Container component | PascalCase with `Container` suffix | `ProductListContainer.tsx` |
| Custom hook | camelCase with `use` prefix | `useProducts.ts` |
| Type/Interface file | camelCase | `product.ts` |
| Test file | Same name + `.test` | `ProductCard.test.tsx` |
| Page file | camelCase (Next.js convention) | `products.tsx` |
| API route file | camelCase | `pages/api/products/index.ts` |
| Utility file | camelCase | `formatPrice.ts` |

### TypeScript Interfaces and Types

| Type | Convention | Example |
|---|---|---|
| Component props | PascalCase + `Props` suffix | `ProductCardProps` |
| API response | PascalCase + `Response` suffix | `ProductListResponse` |
| API request | PascalCase + `Request` suffix | `CreateProductRequest` |
| Data model | PascalCase | `Product`, `Order`, `User` |
| Enum | PascalCase | `OrderStatus` |

### Component and Variable Naming

- Components: PascalCase — `ProductCard`, `OrderList`
- Hooks: camelCase with `use` prefix — `useProducts`, `useCart`
- Event handlers: camelCase with `handle` prefix — `handleClick`, `handleSubmit`
- Boolean props: camelCase with `is`/`has`/`should` prefix — `isLoading`, `hasError`
- Callback props: camelCase with `on` prefix — `onClick`, `onSubmit`

---

## 4. TypeScript Strictness

### Rules

- **Never use `any`** — Use proper types. Use `unknown` if the type is truly unknown, then narrow with type guards.
- **All component props must have an explicit interface** — No inline anonymous types like `{ title: string }` in the component signature. Always define a named `Props` interface.
- **API responses must be typed** — No untyped `fetch` results. Define response types and use them.
- **Strict null checks** — Always handle `null`/`undefined` cases explicitly. No non-null assertions (`!`) unless absolutely necessary with a comment.
- **No type assertions (`as`)** unless absolutely necessary — When used, add a comment explaining why. Prefer type guards and narrowing.
- **No `@ts-ignore` or `@ts-expect-error`** — Fix the type error instead.
- **Use `const` over `let`** — Only use `let` when reassignment is needed. Never use `var`.
- **Prefer `interface` for object shapes** — Use `type` for unions, intersections, and mapped types.

### Examples

```typescript
// BAD - inline anonymous type
const ProductCard = ({ title, price }: { title: string; price: number }) => { ... }

// GOOD - explicit named interface
interface ProductCardProps {
  title: string;
  price: number;
}
const ProductCard = ({ title, price }: ProductCardProps) => { ... }
```

```typescript
// BAD - any
const data: any = await fetch('/api/products');

// GOOD - typed
const data: ProductListResponse = await res.json();
```

---

## 5. React 18 Hooks Best Practices

### General Rules

- **Functional components only** — No class components. Ever.
- **Hooks at the top level** — Never call hooks inside conditions, loops, or nested functions.
- **Custom hook extraction** — If a component has more than ~15 lines of hook logic (state, effects, callbacks), extract into a custom hook in `hooks/`.

### Specific Hook Rules

| Hook | When to Use | When NOT to Use |
|---|---|---|
| `useState` | Simple UI state (toggle, input value) | Complex state with multiple sub-values (use `useReducer`) |
| `useReducer` | Complex state logic, multiple related state values | Simple boolean toggles |
| `useEffect` | Synchronizing with external systems (subscriptions, DOM manipulation) | Data fetching (use useSWR), event handlers, derived state |
| `useMemo` | Expensive computations that re-run on every render with same inputs | Everything "just in case" — only when there's a measurable reason |
| `useCallback` | Stable references for callbacks passed to memoized children | Every handler by default — only when preventing unnecessary re-renders |
| `useRef` | DOM references, mutable values that don't trigger re-renders | State that should trigger re-renders |
| `useContext` | Avoiding prop drilling beyond 2 levels | Global state management for frequently changing data |

### Forbidden Patterns

- **No `useEffect` for data fetching** — Always use useSWR for client-side data fetching
- **No `useEffect` for derived state** — Compute it during render instead
- **No `useEffect` for event handling** — Use event handlers directly
- **No nested state updates in `useEffect`** — Consider `useReducer` if multiple state updates happen together

---

## 6. useSWR Best Practices

### Statement

useSWR is the mandatory solution for all client-side data fetching. No `fetch` + `useEffect` patterns.

### Rules

- All client-side data fetching must use useSWR
- Define a reusable fetcher function in `lib/fetcher.ts`
- Always type the return value of useSWR with generics
- Use SWR's built-in `error` and `isLoading` states — don't create separate state for these
- Use `mutate` for optimistic updates
- Use SWR configuration for revalidation strategies (revalidateOnFocus, refreshInterval)
- Wrap related SWR calls in custom hooks (e.g., `useProducts`, `useOrders`)

### Examples

```typescript
// lib/fetcher.ts
const fetcher = (url: string) => fetch(url).then((res) => res.json());
export default fetcher;

// hooks/useProducts.ts
import useSWR from 'swr';
import fetcher from '@/lib/fetcher';
import { Product } from '@/types/product';

interface UseProductsReturn {
  products: Product[] | undefined;
  isLoading: boolean;
  error: Error | undefined;
  mutate: () => void;
}

export function useProducts(): UseProductsReturn {
  const { data, error, isLoading, mutate } = useSWR<Product[]>('/api/products', fetcher);
  return { products: data, isLoading, error, mutate };
}
```

### Forbidden

- `useEffect` + `fetch` + `useState` for data fetching
- Untyped useSWR calls (always use `useSWR<Type>`)
- Inline fetcher functions (use the shared fetcher)

---

## 7. Error Handling

### Component Error Boundaries

- Use custom error boundaries for component trees that can fail
- Each major section of the page should have its own error boundary
- Error boundaries must render a user-friendly fallback UI

### useSWR Error States

- Always handle the `error` state from useSWR
- Use a reusable `ErrorMessage` presentational component for displaying errors
- Type error states properly

### API Route Error Responses

All API routes must return errors in a standard shape:

```typescript
interface ApiError {
  error: string;
  statusCode: number;
}
```

### getServerSideProps / getStaticProps

- Always wrap data fetching in try/catch
- Return a proper fallback or redirect on error
- Never let unhandled exceptions crash the page

### Examples

```typescript
// Reusable error component
interface ErrorMessageProps {
  message: string;
}
const ErrorMessage = ({ message }: ErrorMessageProps) => (
  <div role="alert" className="text-red-600 p-4">
    <p>{message}</p>
  </div>
);

// API route error handling
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const data = await fetchData();
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error', statusCode: 500 });
  }
}

// getServerSideProps error handling
export const getServerSideProps: GetServerSideProps = async () => {
  try {
    const data = await fetchData();
    return { props: { data } };
  } catch {
    return { redirect: { destination: '/error', permanent: false } };
  }
};
```

---

## 8. Testing Patterns

This section complements the existing `tdd-enforcement` skill by adding React/Next.js-specific testing patterns.

### Rules

- Every presentational component must have a corresponding `.test.tsx` file
- Container components tested separately from presentational ones
- Tests should query by accessible roles/labels first (`getByRole`, `getByLabelText`), then `getByText` — use `data-testid` only as last resort
- Custom hooks must have dedicated tests using `renderHook` from `@testing-library/react`
- API routes must have integration tests
- No snapshot tests — use explicit assertions

### Presentational Component Testing

```typescript
import { render, screen } from '@testing-library/react';
import ProductCard from './ProductCard';

describe('ProductCard', () => {
  const defaultProps: ProductCardProps = {
    title: 'Test Product',
    price: 29.99,
    imageUrl: '/test.jpg',
  };

  test('renders product title', () => {
    render(<ProductCard {...defaultProps} />);
    expect(screen.getByRole('heading', { name: /test product/i })).toBeInTheDocument();
  });
});
```

### Container Component Testing

```typescript
// Mock the custom hook, test that the container passes correct data
jest.mock('@/hooks/useProducts');

describe('ProductListContainer', () => {
  test('renders loading state', () => {
    (useProducts as jest.Mock).mockReturnValue({ products: undefined, isLoading: true, error: undefined });
    render(<ProductListContainer />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });
});
```

### Custom Hook Testing

```typescript
import { renderHook, waitFor } from '@testing-library/react';
import { useProducts } from './useProducts';

describe('useProducts', () => {
  test('returns products', async () => {
    const { result } = renderHook(() => useProducts());
    await waitFor(() => {
      expect(result.current.products).toBeDefined();
    });
  });
});
```

### API Route Testing

```typescript
import handler from './index';
import { createMocks } from 'node-mocks-http';

describe('/api/products', () => {
  test('returns 200 with products', async () => {
    const { req, res } = createMocks({ method: 'GET' });
    await handler(req, res);
    expect(res._getStatusCode()).toBe(200);
  });
});
```

---

## 9. Tailwind CSS Conventions

### Rules

- **No inline styles** — Always use Tailwind utility classes. No `style={{ }}` props.
- **No `@apply` in CSS files** — Extract repeated class combinations into reusable presentational components instead.
- **Responsive design** must use Tailwind breakpoint prefixes (`sm:`, `md:`, `lg:`, `xl:`, `2xl:`)
- **Consistent class ordering**: layout (`flex`, `grid`, `block`) > positioning (`relative`, `absolute`) > spacing (`p-`, `m-`, `gap-`) > sizing (`w-`, `h-`) > typography (`text-`, `font-`) > colors (`bg-`, `text-`, `border-`) > effects (`shadow-`, `opacity-`) > transitions (`transition-`, `duration-`)
- **Use design tokens** from `tailwind.config.ts` — Don't hardcode arbitrary values (`text-[13px]`) when a config token exists

### Forbidden

- `style={{ }}` prop on any element
- `@apply` in CSS/SCSS files
- `<img>` tag (use `next/image`)
- `<a>` tag for internal links (use `next/link`)
- Arbitrary values when a Tailwind token exists

---

## 10. Pages Router Data Fetching Strategy

### Decision Rules

| Scenario | Strategy |
|---|---|
| Data doesn't change per request (catalog, blog) | `getStaticProps` |
| Data must be fresh on every request (user-specific, real-time) | `getServerSideProps` |
| Dynamic routes with known paths | `getStaticPaths` + `getStaticProps` with `fallback: 'blocking'` |
| Data that changes after page load (cart, live status) | useSWR (client-side) |
| Data that never changes | `getStaticProps` with `revalidate: false` |
| Data that changes occasionally | `getStaticProps` with `revalidate: <seconds>` (ISR) |

### Rules

- **Never fetch data in `useEffect`** — Use useSWR for client-side or `getServerSideProps`/`getStaticProps` for server-side
- Always type the return of `getServerSideProps` and `getStaticProps` with `GetServerSideProps<PageProps>` and `GetStaticProps<PageProps>`
- Use `InferGetServerSidePropsType` or `InferGetStaticPropsType` for page prop types when possible
- API routes must validate request method and return 405 for unsupported methods

---

## 11. Performance Optimization

### Rules

- **`next/image` over `<img>`** — Always. Provides automatic optimization, lazy loading, and responsive sizing.
- **`next/link` over `<a>`** — Always for internal navigation. Provides prefetching and client-side transitions.
- **Dynamic imports (`next/dynamic`)** — For heavy components not needed on initial render (modals, charts, rich editors).
- **`useMemo` and `useCallback`** — Only when there's a clear performance reason. Not by default.
- **No prop drilling beyond 2 levels** — If data passes through more than 2 intermediate components, extract to a custom hook or use React Context.
- **Avoid unnecessary re-renders** — Use `React.memo` only for components that receive complex props and render frequently.

### Examples

```typescript
// Dynamic import for heavy component
import dynamic from 'next/dynamic';

const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <p>Loading chart...</p>,
  ssr: false,
});
```

---

## 12. Accessibility (a11y)

### Rules

- **Semantic HTML** — Use `<main>`, `<nav>`, `<section>`, `<article>`, `<header>`, `<footer>` over generic `<div>` and `<span>` when semantically appropriate.
- **All images must have `alt` text** — Decorative images use `alt=""`. Meaningful images describe the content.
- **Interactive elements must be keyboard accessible** — All clickable elements must be focusable and operable with keyboard.
- **Proper heading hierarchy** — `h1` > `h2` > `h3`. No skipping levels. One `h1` per page.
- **ARIA attributes** — Only when semantic HTML isn't sufficient. Prefer native HTML semantics.
- **Form labels** — Every form input must have an associated `<label>` element.
- **Color contrast** — Text must have sufficient contrast against its background per WCAG AA.
- **Focus indicators** — Never remove focus outlines without providing a visible alternative.

---

## Principle Selection Quick Reference

| Problem | Category |
|---|---|
| Component mixes data fetching with rendering | Container-Presentational |
| Inline anonymous prop types | TypeScript Strictness |
| `useEffect` used for data fetching | useSWR / Hooks |
| `<img>` tag instead of `next/image` | Performance |
| Prop drilling through 3+ components | Performance / Hooks |
| `style={{ }}` on elements | Tailwind CSS |
| `@apply` in CSS files | Tailwind CSS |
| No `alt` on images | Accessibility |
| Generic `<div>` where semantic element fits | Accessibility |
| `any` type used | TypeScript Strictness |
| Data fetched client-side that could be static | Data Fetching Strategy |
| Missing error handling in API route | Error Handling |
| Component file in wrong directory | Folder Structure |
| Test queries using `data-testid` as first choice | Testing |
| `useEffect` for derived state | Hooks |
| Class component | Hooks / React 18 |

---

## Important Notes

- This skill is specific to **Next.js 14 (Pages Router)**, **React 18**, and **TypeScript 5**.
- All violations must be addressed — this is not advisory, it is enforced.
- When reviewing code, always explain *why* a best practice applies — don't just state the rule.
- This skill complements `tdd-enforcement` (testing workflow) and `solid-principles-reference` (OOP principles). They do not overlap.
- Do not enforce patterns that would over-engineer trivially simple code. A single-use utility component doesn't need a container/presentational split if it has no data fetching.
