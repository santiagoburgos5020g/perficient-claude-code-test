# Next.js 14 / React 18 / TypeScript 5 Best Practices — Skill Specification (Opus 4.6 Reviewed)

## Overview

A background reference skill that agents automatically consult during code creation, modification, and review. It enforces best practices for **Next.js 14.2 (Pages Router)**, **React 18**, and **TypeScript 5** with **Tailwind CSS 3** and **useSWR** for client-side data fetching.

This skill is **not user-invocable** — it operates as passive knowledge that agents and subagents load automatically when working with frontend code.

## Purpose

- Serve as the authoritative source of truth for frontend best practices in this project
- Enforce strict adherence to the Container-Presentational Component Pattern
- Guide agents when building components from mockups (Figma, images, wireframes)
- Ensure consistent folder structure, naming conventions, and code patterns
- Complement the existing `tdd-enforcement` skill (testing workflow) and `solid-principles-reference` skill (OOP principles)

## Trigger Conditions

Agents should consult this skill when:

- Creating or modifying `.tsx`, `.ts` files in `pages/`, `components/`, `containers/`, `hooks/`, `types/`, `lib/`, `utils/`
- Building components from a mockup, image, or wireframe
- Reviewing frontend code for best practice violations
- Making data fetching decisions (server-side vs client-side)
- Adding or modifying styles with Tailwind CSS
- Creating or modifying API routes in `pages/api/`

---

## Agent Decision Process

When agents encounter a frontend coding task, follow this process:

1. **Identify the task** — What is the code trying to accomplish?
2. **Check for violations** — Does the existing or proposed code violate any best practice defined in this skill? (See per-category "Code Smells" below)
3. **Match to a category** — Consult the relevant section's "When It Applies" and "Code Smells"
4. **Evaluate severity** — Categorize as Critical, Recommended, or Informational
5. **Apply or flag** — If creating/modifying code, follow the best practice. If reviewing, flag the violation with a reference to the specific category and an explanation of *why* it matters.

### Severity Levels

- **Critical** — A best practice is clearly violated and causes maintainability, performance, or correctness problems. Must be fixed immediately.
- **Recommended** — Following the best practice would improve the code but the current approach is functional.
- **Informational** — A best practice could apply but the code is simple enough that enforcement would be over-engineering.

### Key Rule: All Violations Must Be Addressed

This skill enforces strict compliance. Any component that violates the patterns defined here must be refactored, created, or changed to follow these principles. No exceptions for Critical and Recommended findings. Informational findings are at agent discretion.

---

## How the Categories Interact

- **Container-Presentational enables Testing** — Separated components are easier to test in isolation; presentational components can be tested with props alone, containers by mocking hooks.
- **TypeScript Strictness enables Error Handling** — Typed API responses and error states catch bugs at compile time that would otherwise surface at runtime.
- **useSWR enforces Container-Presentational** — Data fetching lives in hooks/containers, never in presentational components.
- **Folder Structure enforces Container-Presentational** — Separate `components/` and `containers/` directories make violations immediately visible.
- **Naming Conventions support Folder Structure** — `Container` suffix and `use` prefix make the role of each file clear without reading it.
- **Accessibility enables Testing** — Semantic HTML and ARIA roles provide the accessible queries that tests should use (`getByRole`, `getByLabelText`).
- **Tailwind CSS supports Presentational Components** — Utility-first styling keeps styles co-located with markup, making presentational components self-contained.
- **Data Fetching Strategy drives Container-Presentational** — The decision of where data is fetched (server vs client) determines which component acts as the container.
- **Performance rules reinforce all other categories** — `next/image`, `next/link`, dynamic imports, and selective memoization apply across all component types.

---

## THE 12 BEST PRACTICE CATEGORIES

### 1. Container-Presentational Component Pattern

**Statement:** All components must follow the Container-Presentational pattern. Components that mix data fetching/business logic with rendering are violations and must be split.

#### Definitions

- **Presentational Components**: Concerned only with *how things look*. Receive all data and callbacks via props. No data fetching, no business logic, no state management beyond local UI state (e.g., accordion open/closed, input focus). Pure rendering functions.
- **Container Components**: Concerned with *how things work*. Handle data fetching (useSWR), business logic, state management, and pass data/callbacks down to presentational components. Minimal JSX — only enough to compose presentational children and wrapping layout elements.
- **Pages** (`pages/*.tsx`): Act as top-level containers. They handle server-side data fetching (`getServerSideProps`, `getStaticProps`) and compose container and presentational components.

#### When It Applies

- Any `.tsx` file that renders UI
- Any new component being created
- Any existing component being modified

#### Code Smells That Signal a Violation

- A component imports `useSWR` or `fetch` AND contains significant JSX rendering
- A component has `getServerSideProps`/`getStaticProps` logic AND complex nested JSX
- A component manages business state (cart calculations, form validation logic) AND renders the UI for it
- A component file exceeds ~150 lines because it handles both data and display
- A component is hard to test because it requires mocking data fetching AND asserting rendered output in the same test

#### Rules

- A presentational component must NEVER: import `useSWR`, call `fetch`, contain business logic, directly access APIs, or manage non-UI state
- A container component must NEVER: contain complex JSX beyond composing its presentational children with basic wrapping elements (`<div>`, `<section>`, error/loading wrappers)
- Pages (`pages/*.tsx`) act as containers — they handle server-side data fetching via `getServerSideProps`/`getStaticProps` and compose components
- If a component does both data fetching and rendering, it must be split into a container + presentational pair
- A presentational component with zero data fetching and only 2-3 lines of JSX does NOT need a container — the container pattern applies when there is data fetching or business logic to separate

#### Examples

```typescript
// BAD — mixed data fetching and rendering
const ProductList = () => {
  const { data, error, isLoading } = useSWR<Product[]>('/api/products', fetcher);

  if (isLoading) return <div role="status">Loading...</div>;
  if (error) return <ErrorMessage message="Failed to load products" />;

  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-6 p-4">
      <h2 className="col-span-full text-2xl font-bold text-gray-900">Products</h2>
      {data?.map((product) => (
        <div key={product.id} className="rounded-lg border border-gray-200 p-4 shadow-sm">
          <Image src={product.imageUrl} alt={product.title} width={300} height={200} />
          <h3 className="mt-2 text-lg font-semibold">{product.title}</h3>
          <p className="text-gray-600">${product.price.toFixed(2)}</p>
        </div>
      ))}
    </section>
  );
};

// GOOD — separated into container + presentational

// components/ProductList/ProductList.tsx (Presentational)
interface ProductListProps {
  products: Product[];
}

const ProductList = ({ products }: ProductListProps) => (
  <section className="grid grid-cols-1 md:grid-cols-3 gap-6 p-4">
    <h2 className="col-span-full text-2xl font-bold text-gray-900">Products</h2>
    {products.map((product) => (
      <ProductCard key={product.id} product={product} />
    ))}
  </section>
);

// containers/ProductListContainer/ProductListContainer.tsx (Container)
const ProductListContainer = () => {
  const { products, isLoading, error } = useProducts();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message="Failed to load products" />;
  if (!products) return null;

  return <ProductList products={products} />;
};
```

#### Mockup-to-Code Workflow

When building components from a mockup (Figma, image, wireframe), follow this exact order:

**Step 1 — Decompose the mockup into a component tree:**
- Analyze the visual hierarchy of the mockup
- Identify which parts are presentational components (visual elements with no data dependency)
- Identify which parts are containers (sections that need data fetching or business logic)
- Map out the parent-child relationships
- Output a text diagram of the component tree before writing any code:

```
PageName (page — container)
├── HeaderSection (presentational)
│   ├── Logo (presentational)
│   └── Navigation (presentational)
├── ProductListContainer (container — uses useProducts hook)
│   └── ProductList (presentational)
│       └── ProductCard (presentational)
└── Footer (presentational)
```

**Step 2 — Define TypeScript interfaces for props:**
- Create explicit interfaces for every component's props before writing any JSX
- Place shared/reusable types in `types/` (e.g., `Product`, `Order`)
- Place component-specific prop interfaces co-located in the component file
- Define return types for custom hooks

**Step 3 — Build presentational components first:**
- Create presentational components with typed props
- These must render correctly with hardcoded/mock data passed as props
- Style with Tailwind CSS utility classes
- Ensure accessibility (semantic HTML, alt text, ARIA where needed)

**Step 4 — Wire up container components and hooks:**
- Create custom hooks for data fetching (wrapping useSWR)
- Create container components that use hooks and manage state
- Pass data and callbacks to presentational components via typed props
- Handle loading, error, and empty states in containers

---

### 2. Folder Structure

**Statement:** Every file must live in the correct directory according to its role. Misplaced files are violations.

#### Enforced Layout

```
project-root/
  components/              # Reusable presentational components ONLY
    ProductCard/
      ProductCard.tsx
      ProductCard.test.tsx
    ErrorMessage/
      ErrorMessage.tsx
      ErrorMessage.test.tsx
    LoadingSpinner/
      LoadingSpinner.tsx
      LoadingSpinner.test.tsx
  containers/              # Container components ONLY
    ProductListContainer/
      ProductListContainer.tsx
      ProductListContainer.test.tsx
  hooks/                   # Custom hooks ONLY
    useProducts.ts
    useProducts.test.ts
    useCart.ts
    useCart.test.ts
  types/                   # Shared TypeScript interfaces and types ONLY
    product.ts
    order.ts
    api.ts
  pages/                   # Next.js route pages and API routes ONLY
    index.tsx
    index.test.tsx
    products.tsx
    products.test.tsx
    api/
      products/
        index.ts
      orders/
        index.ts
  lib/                     # External service configs and shared utilities
    fetcher.ts             # useSWR fetcher function
    prisma.ts              # Prisma client instance
  utils/                   # Pure utility functions
    formatPrice.ts
    formatDate.ts
  styles/                  # Global styles only
    globals.css
  public/                  # Static assets
    images/
```

#### Rules

- `components/` — Only presentational components. No data fetching, no business logic. Each component in its own PascalCase folder with co-located test file.
- `containers/` — Only container components. Handle data fetching and state, render presentational components. Each container in its own PascalCase folder with co-located test file.
- `hooks/` — Only custom hooks. Each hook in its own file with co-located test file. No component code.
- `types/` — Only TypeScript interfaces, types, and enums. No runtime code. No function implementations.
- `pages/` — Only Next.js route pages and API routes. Pages act as containers. Test files co-located.
- `lib/` — External service configurations (Prisma client, fetcher, third-party SDK wrappers). No business logic.
- `utils/` — Pure utility functions with no side effects. No React hooks, no API calls.
- `styles/` — Global CSS only. No component-specific styles (use Tailwind utility classes instead).
- `public/` — Static assets only.

#### Code Smells

- A file in `components/` imports `useSWR` or calls `fetch`
- A file in `types/` exports a function
- A hook file lives inside `components/` instead of `hooks/`
- A container lives inside `components/` without the `Container` suffix
- Test files are in a separate `__tests__/` directory instead of co-located

---

### 3. Naming Conventions

**Statement:** Consistent naming makes the role of every file and symbol immediately clear without reading the implementation.

#### File and Folder Names

| Type | Convention | Example |
|---|---|---|
| Presentational component folder | PascalCase | `ProductCard/` |
| Presentational component file | PascalCase | `ProductCard.tsx` |
| Container component folder | PascalCase with `Container` suffix | `ProductListContainer/` |
| Container component file | PascalCase with `Container` suffix | `ProductListContainer.tsx` |
| Custom hook file | camelCase with `use` prefix | `useProducts.ts` |
| Type/Interface file | camelCase | `product.ts`, `api.ts` |
| Test file | Same name + `.test` suffix | `ProductCard.test.tsx` |
| Page file | camelCase (Next.js convention) | `products.tsx` |
| API route file | camelCase | `pages/api/products/index.ts` |
| Utility file | camelCase, named after primary export | `formatPrice.ts` |
| Lib file | camelCase | `fetcher.ts`, `prisma.ts` |

#### TypeScript Interfaces and Types

| Kind | Convention | Example |
|---|---|---|
| Component props | PascalCase + `Props` suffix | `ProductCardProps` |
| Hook return type | PascalCase + `Return` suffix | `UseProductsReturn` |
| API response | PascalCase + `Response` suffix | `ProductListResponse` |
| API request body | PascalCase + `Request` suffix | `CreateProductRequest` |
| API error | `ApiError` (standard) | `ApiError` |
| Data model | PascalCase, matching Prisma model name | `Product`, `Order`, `User` |
| Enum | PascalCase | `OrderStatus` |

#### Component and Variable Names

| Kind | Convention | Example |
|---|---|---|
| Components | PascalCase | `ProductCard`, `OrderList` |
| Hooks | camelCase with `use` prefix | `useProducts`, `useCart` |
| Event handlers (inside component) | `handle` prefix | `handleClick`, `handleSubmit` |
| Callback props (passed to component) | `on` prefix | `onClick`, `onSubmit`, `onAddToCart` |
| Boolean props | `is`/`has`/`should` prefix | `isLoading`, `hasError`, `shouldAnimate` |
| Boolean variables | `is`/`has`/`should` prefix | `isValid`, `hasItems` |
| Constants | SCREAMING_SNAKE_CASE (module-level only) | `MAX_ITEMS_PER_PAGE`, `API_BASE_URL` |

#### Code Smells

- A container file without the `Container` suffix
- A hook without the `use` prefix
- A component file in camelCase instead of PascalCase
- Props interface without the `Props` suffix
- Boolean variable named `loading` instead of `isLoading`
- Event handler named `click` instead of `handleClick` or `onClick`

---

### 4. Component File Internal Structure

**Statement:** Every component file must follow a consistent internal ordering so agents and developers can navigate files predictably.

#### Required Order

```typescript
// 1. External library imports (React, Next.js, third-party)
import { useState } from 'react';
import Image from 'next/image';

// 2. Internal absolute imports (project modules)
import { useProducts } from '@/hooks/useProducts';
import { Product } from '@/types/product';

// 3. Internal relative imports (sibling files)
import ProductCard from './ProductCard';

// 4. Type/Interface definitions (props, local types)
interface ProductListProps {
  products: Product[];
  onProductClick: (id: string) => void;
}

// 5. Constants (if any)
const MAX_VISIBLE_PRODUCTS = 12;

// 6. Component definition (named export preferred for non-pages)
const ProductList = ({ products, onProductClick }: ProductListProps) => {
  // hooks first
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // derived state (computed during render, no useEffect)
  const visibleProducts = products.slice(0, MAX_VISIBLE_PRODUCTS);

  // event handlers
  const handleProductClick = (id: string) => {
    setSelectedId(id);
    onProductClick(id);
  };

  // render
  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {visibleProducts.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          isSelected={product.id === selectedId}
          onClick={handleProductClick}
        />
      ))}
    </section>
  );
};

export default ProductList;

// 7. Server-side functions (pages only — getServerSideProps, getStaticProps, getStaticPaths)
```

#### Import Ordering Rules

Imports must be grouped in this order, with a blank line between each group:

1. **React** — `import React`, `import { useState, useEffect }` (React imports always first)
2. **Next.js** — `import Image from 'next/image'`, `import Link from 'next/link'`, `import { useRouter } from 'next/router'`
3. **Third-party libraries** — `import useSWR from 'swr'`
4. **Internal absolute imports** — `import { Product } from '@/types/product'`
5. **Internal relative imports** — `import ProductCard from './ProductCard'`

---

### 5. TypeScript Strictness

**Statement:** TypeScript must be used to its fullest. Every value, prop, return type, and API response must be properly typed. Type safety is not optional.

#### Rules

- **Never use `any`** — Use proper types. Use `unknown` if the type is truly unknown, then narrow with type guards.
- **All component props must have an explicit named interface** — No inline anonymous types. Always define a `ComponentNameProps` interface.
- **API responses must be typed** — No untyped `fetch` results or `res.json()` without a type parameter.
- **Strict null checks** — Always handle `null`/`undefined` cases explicitly. No non-null assertions (`!`) unless absolutely necessary with a `// reason` comment.
- **No type assertions (`as`)** unless absolutely necessary — Prefer type guards and narrowing. When `as` is used, add a comment explaining why.
- **No `@ts-ignore` or `@ts-expect-error`** — Fix the type error properly.
- **Use `const` over `let`** — Only use `let` when reassignment is needed. Never use `var`.
- **Prefer `interface` for object shapes** — Use `type` for unions, intersections, mapped types, and utility types.
- **Export types from `types/` files** — Don't define shared types inline in component files.
- **Function return types** — Explicit return types on exported functions and hooks. Components may rely on inference.

#### Code Smells

- `: any` anywhere in the codebase
- `as SomeType` without a comment
- `@ts-ignore` or `@ts-expect-error`
- Inline `{ title: string; price: number }` in a component parameter
- `res.json()` without a type assertion or generic
- `!` (non-null assertion) without a comment
- `let` where `const` would suffice
- `var` anywhere
- Shared types defined inside component files instead of `types/`

#### Examples

```typescript
// BAD — inline anonymous type, any, no null handling
const ProductCard = ({ title, price }: { title: string; price: number }) => { ... }
const data: any = await fetch('/api/products');
const name = user!.name;

// GOOD — named interface, typed, null-safe
interface ProductCardProps {
  title: string;
  price: number;
}
const ProductCard = ({ title, price }: ProductCardProps) => { ... }

const res = await fetch('/api/products');
const data: ProductListResponse = await res.json();

const name = user?.name ?? 'Unknown';
```

```typescript
// BAD — type assertion without reason
const element = document.getElementById('root') as HTMLDivElement;

// GOOD — type guard
const element = document.getElementById('root');
if (element instanceof HTMLDivElement) {
  // safe to use as HTMLDivElement
}

// ACCEPTABLE — assertion with reason
// getElementById is guaranteed to exist because it's rendered in _document.tsx
const element = document.getElementById('root') as HTMLDivElement;
```

---

### 6. React 18 Hooks Best Practices

**Statement:** All components must be functional. Hooks must be used correctly according to React 18 patterns.

#### General Rules

- **Functional components only** — No class components. Ever. (Exception: error boundaries, which React 18 still requires as class components.)
- **Hooks at the top level** — Never call hooks inside conditions, loops, or nested functions.
- **Custom hook extraction** — If a component has more than ~15 lines of hook logic (state declarations, effects, callbacks), extract into a custom hook in `hooks/`.
- **Hooks return typed objects** — Custom hooks must define and return an explicit return type interface.

#### Specific Hook Rules

| Hook | When to Use | When NOT to Use |
|---|---|---|
| `useState` | Simple, independent UI state (toggle, input value, selected tab) | Complex state with multiple related sub-values (use `useReducer`) |
| `useReducer` | Complex state logic, multiple related values that change together, state machines | Simple boolean toggles or single values |
| `useEffect` | Synchronizing with external systems (subscriptions, DOM measurement, third-party widget setup) | Data fetching (use useSWR), event handlers, computing derived state |
| `useMemo` | Expensive computations with same inputs across re-renders, referential stability for objects/arrays passed to memoized children | Premature optimization — don't wrap everything "just in case" |
| `useCallback` | Stable function references passed to `React.memo`-wrapped children or used as useEffect dependencies | Every handler by default — only when preventing measurable unnecessary re-renders |
| `useRef` | DOM element references, mutable values that persist across renders without triggering re-renders (timers, previous values) | Values that should trigger re-renders when changed (use `useState`) |
| `useContext` | Sharing data that avoids prop drilling beyond 2 levels (theme, auth, locale) | Frequently changing global state (causes unnecessary re-renders in all consumers) |

#### Forbidden Patterns

- **No `useEffect` for data fetching** — Always use useSWR for client-side data fetching. No `fetch` inside `useEffect`.
- **No `useEffect` for derived state** — If a value can be computed from props or state, compute it during render. No `useEffect` + `setState` for transformations.
- **No `useEffect` for event handling** — Respond to events in event handlers, not in effects that watch for state changes.
- **No cascading state updates in `useEffect`** — If an effect sets state that triggers another effect that sets more state, refactor to `useReducer` or compute values during render.
- **No empty dependency array `useEffect` as componentDidMount** — This is a code smell; ensure the effect is truly for synchronization, not for initialization logic that belongs in an event handler or `getServerSideProps`.

#### Code Smells

- `useEffect` with `fetch` or `axios` inside it
- `useEffect` that only calls `setState` with a transformation of props
- Multiple `useState` calls that always update together (should be `useReducer`)
- `useMemo`/`useCallback` wrapping a trivial operation
- A `useEffect` with no cleanup that runs a subscription
- `// eslint-disable-next-line react-hooks/exhaustive-deps` — this almost always means the effect is structured wrong

```typescript
// BAD — useEffect for derived state
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);

// GOOD — compute during render
const fullName = `${firstName} ${lastName}`;
```

```typescript
// BAD — useEffect for event response
const [items, setItems] = useState<Item[]>([]);
const [sortedItems, setSortedItems] = useState<Item[]>([]);
useEffect(() => {
  setSortedItems([...items].sort(compareFn));
}, [items]);

// GOOD — compute during render
const sortedItems = useMemo(() => [...items].sort(compareFn), [items]);
```

---

### 7. useSWR Best Practices

**Statement:** useSWR is the mandatory solution for all client-side data fetching. No `fetch` + `useEffect` patterns are permitted.

#### Setup

A shared fetcher must be defined in `lib/fetcher.ts`:

```typescript
// lib/fetcher.ts
export class FetchError extends Error {
  status: number;
  info: unknown;

  constructor(message: string, status: number, info: unknown) {
    super(message);
    this.status = status;
    this.info = info;
  }
}

const fetcher = async (url: string) => {
  const res = await fetch(url);

  if (!res.ok) {
    const info = await res.json().catch(() => null);
    throw new FetchError(
      `Fetch error: ${res.status}`,
      res.status,
      info
    );
  }

  return res.json();
};

export default fetcher;
```

Global SWR configuration should be set in `pages/_app.tsx`:

```typescript
import { SWRConfig } from 'swr';
import fetcher from '@/lib/fetcher';

function App({ Component, pageProps }: AppProps) {
  return (
    <SWRConfig value={{ fetcher, revalidateOnFocus: false }}>
      <Component {...pageProps} />
    </SWRConfig>
  );
}
```

#### Rules

- All client-side data fetching must use useSWR — no exceptions
- Always use the shared fetcher from `lib/fetcher.ts`
- Always type useSWR with generics: `useSWR<Product[]>(key, fetcher)`
- Use SWR's built-in `error` and `isLoading` states — never create separate `useState` for loading/error
- Use `mutate` for optimistic updates after mutations
- Wrap every useSWR call in a custom hook in `hooks/` (e.g., `useProducts`, `useOrders`)
- Custom hooks must define a return type interface
- Use conditional fetching with `null` key to disable requests: `useSWR(shouldFetch ? key : null, fetcher)`
- SWR key naming convention: use the API route path as the key (e.g., `/api/products`, `/api/products/${id}`)

#### Custom Hook Pattern

```typescript
// hooks/useProducts.ts
import useSWR from 'swr';
import { Product } from '@/types/product';

interface UseProductsReturn {
  products: Product[] | undefined;
  isLoading: boolean;
  error: Error | undefined;
  mutate: () => void;
}

export function useProducts(): UseProductsReturn {
  const { data, error, isLoading, mutate } = useSWR<Product[]>('/api/products');
  return { products: data, isLoading, error, mutate };
}
```

```typescript
// hooks/useProduct.ts — conditional fetching
import useSWR from 'swr';
import { Product } from '@/types/product';

interface UseProductReturn {
  product: Product | undefined;
  isLoading: boolean;
  error: Error | undefined;
}

export function useProduct(id: string | undefined): UseProductReturn {
  const { data, error, isLoading } = useSWR<Product>(
    id ? `/api/products/${id}` : null
  );
  return { product: data, isLoading, error };
}
```

#### Forbidden

- `useEffect` + `fetch` + `useState` for data fetching
- Untyped `useSWR` calls (must always have `useSWR<Type>`)
- Inline fetcher functions in components (use the shared fetcher)
- Direct `useSWR` calls in components — always wrap in a custom hook
- Creating `useState` for `isLoading` or `error` alongside useSWR

#### Code Smells

- `const [data, setData] = useState()` + `useEffect(() => { fetch(...) }, [])` — replace with useSWR hook
- `const [loading, setLoading] = useState(true)` alongside a `useSWR` call — use SWR's built-in `isLoading`
- `useSWR('/api/products', (url) => fetch(url).then(r => r.json()))` — use the shared fetcher
- `useSWR` call directly in a component file instead of a `hooks/use*.ts` file

---

### 8. Error Handling

**Statement:** Errors must be handled at every level — component rendering, data fetching, API routes, and server-side functions. No unhandled exceptions.

#### Component Error Boundaries

React 18 still requires class components for error boundaries. Use a shared error boundary:

```typescript
// components/ErrorBoundary/ErrorBoundary.tsx
import React, { Component, ReactNode } from 'react';

interface ErrorBoundaryProps {
  fallback: ReactNode;
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
    console.error('ErrorBoundary caught:', error, errorInfo);
  }

  render(): ReactNode {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
```

Rules:
- Each major section of the page should be wrapped in its own `ErrorBoundary`
- Error boundaries must render a user-friendly fallback UI (not blank screen)
- The `ErrorBoundary` class component is the ONLY exception to the "no class components" rule

#### useSWR Error States

- Always handle the `error` state from useSWR in container components
- Use a reusable `ErrorMessage` presentational component
- Type error states using the `FetchError` class from `lib/fetcher.ts`

```typescript
// In a container component
const { products, isLoading, error } = useProducts();

if (isLoading) return <LoadingSpinner />;
if (error) return <ErrorMessage message="Failed to load products" />;
if (!products || products.length === 0) return <EmptyState message="No products found" />;

return <ProductList products={products} />;
```

#### API Route Error Responses

All API routes must return errors in a standard shape:

```typescript
// types/api.ts
interface ApiError {
  error: string;
  statusCode: number;
}

interface ApiSuccess<T> {
  data: T;
}
```

API routes must:
- Validate request method and return 405 for unsupported methods
- Wrap all logic in try/catch
- Return typed error responses
- Never expose internal error details to the client

```typescript
// pages/api/products/index.ts
import type { NextApiRequest, NextApiResponse } from 'next';
import { Product } from '@/types/product';
import { ApiError } from '@/types/api';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<Product[] | ApiError>
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed', statusCode: 405 });
  }

  try {
    const products = await prisma.product.findMany();
    return res.status(200).json(products);
  } catch {
    return res.status(500).json({ error: 'Internal server error', statusCode: 500 });
  }
}
```

#### getServerSideProps / getStaticProps

- Always wrap data fetching in try/catch
- Return proper fallback props or redirect on error
- Never let unhandled exceptions crash the page

```typescript
export const getServerSideProps: GetServerSideProps<ProductPageProps> = async () => {
  try {
    const products = await prisma.product.findMany();
    return { props: { products } };
  } catch {
    return { redirect: { destination: '/error', permanent: false } };
  }
};
```

#### 404 Handling

- Use `notFound: true` return from `getServerSideProps`/`getStaticProps` when a resource doesn't exist
- Create a custom `pages/404.tsx` page

---

### 9. Testing Patterns

**Statement:** This section complements the `tdd-enforcement` skill by defining React/Next.js-specific testing patterns. The `tdd-enforcement` skill governs the workflow (tests first, 100% coverage). This section governs *how* tests are written.

#### Rules

- Every presentational component must have a corresponding `.test.tsx` file
- Container components tested separately from presentational ones
- Custom hooks must have dedicated tests using `renderHook`
- API routes must have integration tests
- No snapshot tests — use explicit assertions only
- Query priority (in order of preference):
  1. `getByRole` — accessible role queries (buttons, headings, links, etc.)
  2. `getByLabelText` — form inputs associated with labels
  3. `getByPlaceholderText` — form inputs by placeholder
  4. `getByText` — visible text content
  5. `getByDisplayValue` — form elements by current value
  6. `getByAltText` — images by alt text
  7. `getByTitle` — elements by title attribute
  8. `getByTestId` — **last resort only**, when no accessible query works

#### Presentational Component Testing

Test with props alone. No mocking of hooks or data fetching.

```typescript
import { render, screen } from '@testing-library/react';
import ProductCard from './ProductCard';
import { ProductCardProps } from './ProductCard';

describe('ProductCard', () => {
  const defaultProps: ProductCardProps = {
    title: 'Test Product',
    price: 29.99,
    imageUrl: '/test.jpg',
  };

  test('renders product title as heading', () => {
    render(<ProductCard {...defaultProps} />);
    expect(screen.getByRole('heading', { name: /test product/i })).toBeInTheDocument();
  });

  test('renders formatted price', () => {
    render(<ProductCard {...defaultProps} />);
    expect(screen.getByText('$29.99')).toBeInTheDocument();
  });

  test('renders product image with alt text', () => {
    render(<ProductCard {...defaultProps} />);
    expect(screen.getByAltText('Test Product')).toBeInTheDocument();
  });
});
```

#### Container Component Testing

Mock the custom hook. Test loading, error, empty, and success states.

```typescript
import { render, screen } from '@testing-library/react';
import ProductListContainer from './ProductListContainer';
import { useProducts } from '@/hooks/useProducts';

jest.mock('@/hooks/useProducts');
const mockUseProducts = useProducts as jest.MockedFunction<typeof useProducts>;

describe('ProductListContainer', () => {
  test('renders loading state', () => {
    mockUseProducts.mockReturnValue({
      products: undefined,
      isLoading: true,
      error: undefined,
      mutate: jest.fn(),
    });
    render(<ProductListContainer />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  test('renders error state', () => {
    mockUseProducts.mockReturnValue({
      products: undefined,
      isLoading: false,
      error: new Error('Failed'),
      mutate: jest.fn(),
    });
    render(<ProductListContainer />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  test('renders product list when data is available', () => {
    mockUseProducts.mockReturnValue({
      products: [{ id: '1', title: 'Product 1', price: 10 }],
      isLoading: false,
      error: undefined,
      mutate: jest.fn(),
    });
    render(<ProductListContainer />);
    expect(screen.getByText('Product 1')).toBeInTheDocument();
  });
});
```

#### Custom Hook Testing

```typescript
import { renderHook, waitFor } from '@testing-library/react';
import { SWRConfig } from 'swr';
import { useProducts } from './useProducts';
import { ReactNode } from 'react';

// Wrapper to provide SWR config for tests
const wrapper = ({ children }: { children: ReactNode }) => (
  <SWRConfig value={{ dedupingInterval: 0, provider: () => new Map() }}>
    {children}
  </SWRConfig>
);

describe('useProducts', () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  test('returns products on success', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => [{ id: '1', title: 'Product 1', price: 10 }],
    });

    const { result } = renderHook(() => useProducts(), { wrapper });

    await waitFor(() => {
      expect(result.current.products).toHaveLength(1);
    });
    expect(result.current.isLoading).toBe(false);
    expect(result.current.error).toBeUndefined();
  });

  test('returns error on failure', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 500,
      json: async () => ({ error: 'Server error' }),
    });

    const { result } = renderHook(() => useProducts(), { wrapper });

    await waitFor(() => {
      expect(result.current.error).toBeDefined();
    });
  });
});
```

#### API Route Testing

```typescript
import handler from './index';
import { createMocks } from 'node-mocks-http';
import type { NextApiRequest, NextApiResponse } from 'next';

describe('/api/products', () => {
  test('returns 200 with products for GET', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: 'GET',
    });
    await handler(req, res);
    expect(res._getStatusCode()).toBe(200);
    const data = JSON.parse(res._getData());
    expect(Array.isArray(data)).toBe(true);
  });

  test('returns 405 for unsupported methods', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: 'DELETE',
    });
    await handler(req, res);
    expect(res._getStatusCode()).toBe(405);
  });
});
```

---

### 10. Tailwind CSS Conventions

**Statement:** Tailwind CSS utility classes are the only permitted styling approach. No inline styles, no CSS modules, no `@apply`.

#### Rules

- **No inline styles** — No `style={{ }}` props on any element. Always use Tailwind utility classes.
- **No `@apply` in CSS files** — If a class combination is repeated, extract it into a reusable presentational component instead.
- **No CSS modules or styled-components** — Tailwind utilities only.
- **Responsive design** must use Tailwind breakpoint prefixes: `sm:` (640px), `md:` (768px), `lg:` (1024px), `xl:` (1280px), `2xl:` (1536px). Mobile-first approach.
- **Consistent class ordering** (within a `className` string):
  1. Layout: `flex`, `grid`, `block`, `inline`, `hidden`
  2. Positioning: `relative`, `absolute`, `fixed`, `sticky`, `z-*`
  3. Spacing: `p-*`, `m-*`, `gap-*`, `space-*`
  4. Sizing: `w-*`, `h-*`, `min-*`, `max-*`
  5. Typography: `text-*` (size), `font-*`, `leading-*`, `tracking-*`
  6. Colors: `bg-*`, `text-*` (color), `border-*`
  7. Borders: `border`, `rounded-*`
  8. Effects: `shadow-*`, `opacity-*`
  9. Transitions: `transition-*`, `duration-*`, `ease-*`
  10. Responsive/State: `sm:*`, `md:*`, `hover:*`, `focus:*`
- **Use design tokens** from `tailwind.config.ts` — Don't hardcode arbitrary values like `text-[13px]` when a config token exists (e.g., `text-sm`).
- **Long className strings** — If a `className` exceeds ~100 characters, break across multiple lines for readability.

#### Forbidden

- `style={{ }}` prop on any element
- `@apply` in any CSS/SCSS file
- `<img>` tag (use `next/image`)
- `<a>` tag for internal links (use `next/link`)
- Arbitrary values (`text-[13px]`, `bg-[#ff0000]`) when a Tailwind token exists
- CSS modules (`.module.css`) or styled-components
- Inline color hex values

#### Code Smells

- A component file importing a `.css` or `.module.css` file (except `globals.css` in `_app.tsx`)
- `style=` appearing in JSX
- `@apply` in any CSS file
- Arbitrary bracket values like `w-[327px]` for common widths that should be Tailwind tokens

---

### 11. Pages Router Data Fetching Strategy

**Statement:** Every data fetch must use the correct strategy based on the data's freshness requirements. The wrong strategy is a violation.

#### Decision Rules

| Scenario | Strategy | Example |
|---|---|---|
| Data rarely changes, same for all users | `getStaticProps` | Product catalog, marketing pages |
| Data rarely changes but has many dynamic paths | `getStaticPaths` + `getStaticProps` with `fallback: 'blocking'` | Individual product pages |
| Data changes occasionally, acceptable staleness | `getStaticProps` with `revalidate: <seconds>` (ISR) | Blog posts, category listings |
| Data must be fresh every request, user-specific | `getServerSideProps` | User dashboard, order history |
| Data changes after initial page load | useSWR (client-side via custom hook) | Cart contents, live inventory status |
| Data never changes | `getStaticProps` without `revalidate` | About page, terms of service |

#### Rules

- **Never fetch data in `useEffect`** — Use useSWR for client-side, `getServerSideProps`/`getStaticProps` for server-side
- **Always type server-side functions** — Use `GetServerSideProps<PageProps>` and `GetStaticProps<PageProps>` generics
- **Use `InferGetServerSidePropsType` or `InferGetStaticPropsType`** for page component prop types when possible
- **API routes must validate request method** — Return 405 for unsupported methods
- **API routes must type their response** — Use `NextApiResponse<DataType | ApiError>`
- **Prefer `getStaticProps` over `getServerSideProps`** when data freshness allows — static is faster and cheaper
- **Use ISR (`revalidate`)** as a middle ground between fully static and fully server-rendered

#### Code Smells

- `useEffect` + `fetch` for loading initial page data
- `getServerSideProps` for data that changes weekly (should be ISR)
- `getStaticProps` for user-specific data (should be `getServerSideProps` or useSWR)
- API route without method validation
- Untyped `GetServerSideProps` (missing generic parameter)

```typescript
// BAD — untyped, no method validation
export default async function handler(req, res) {
  const products = await prisma.product.findMany();
  res.json(products);
}

// GOOD — typed, method validated
export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<Product[] | ApiError>
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed', statusCode: 405 });
  }

  try {
    const products = await prisma.product.findMany();
    return res.status(200).json(products);
  } catch {
    return res.status(500).json({ error: 'Internal server error', statusCode: 500 });
  }
}
```

---

### 12. Performance Optimization

**Statement:** Use Next.js built-in optimizations. Avoid premature optimization but enforce known performance patterns.

#### Rules

- **`next/image` over `<img>`** — Always. No exceptions. Provides automatic optimization, lazy loading, and responsive sizing.
- **`next/link` over `<a>`** — Always for internal navigation. Provides prefetching and client-side transitions. Use plain `<a>` only for external links.
- **Dynamic imports (`next/dynamic`)** — Use for components not needed on initial render: modals, dialogs, charts, rich text editors, heavy libraries.
- **`useMemo`** — Only when the computation is expensive (sorting/filtering large arrays, complex calculations). Not for simple property access or string concatenation.
- **`useCallback`** — Only when the callback is passed to a `React.memo`-wrapped child or used as a `useEffect` dependency. Not for every handler.
- **`React.memo`** — Only for components that receive complex/object props and render frequently. Not for leaf components or components that always receive new props.
- **No prop drilling beyond 2 levels** — If data passes through more than 2 intermediate components that don't use it, extract to a custom hook or use React Context.
- **Avoid creating objects/arrays in render** — Inline `style={{ }}` (already banned by Tailwind rule), inline array/object literals as props to memoized children.

#### Examples

```typescript
// Dynamic import — modal not needed on initial load
import dynamic from 'next/dynamic';

const ProductModal = dynamic(() => import('@/components/ProductModal/ProductModal'), {
  loading: () => <LoadingSpinner />,
});

// next/image — always
import Image from 'next/image';
<Image src={product.imageUrl} alt={product.title} width={300} height={200} />

// next/link — always for internal
import Link from 'next/link';
<Link href={`/products/${product.id}`}>{product.title}</Link>

// External link — plain <a> is acceptable
<a href="https://external-site.com" target="_blank" rel="noopener noreferrer">External</a>
```

#### Code Smells

- `<img src=` anywhere in the codebase
- `<a href="/internal-route">` for internal navigation
- `useMemo(() => items.length, [items])` — trivial computation, no memoization needed
- `useCallback` on a handler not passed to a memoized child
- Props being passed through 3+ component layers without being used by intermediate components

---

### 13. Accessibility (a11y)

**Statement:** All UI must be accessible. Accessibility is not optional and not a separate concern — it is built into every component.

#### Rules

- **Semantic HTML** — Use `<main>`, `<nav>`, `<section>`, `<article>`, `<header>`, `<footer>`, `<aside>` instead of generic `<div>` when semantically appropriate. Use `<button>` for clickable actions, `<a>` for navigation.
- **All images must have `alt` text** — Decorative images use `alt=""`. Meaningful images describe the content concisely.
- **Interactive elements must be keyboard accessible** — All clickable elements must be focusable and operable via keyboard. Don't attach `onClick` to `<div>` or `<span>` — use `<button>` instead.
- **Proper heading hierarchy** — `h1` > `h2` > `h3`. No skipping levels. Exactly one `h1` per page.
- **ARIA attributes** — Only when semantic HTML isn't sufficient. Prefer native semantics. Common valid uses: `role="status"` for loading indicators, `role="alert"` for error messages, `aria-label` for icon-only buttons.
- **Form labels** — Every form input must have an associated `<label>` element with a `htmlFor` attribute matching the input's `id`.
- **Color contrast** — Text must meet WCAG AA minimum contrast ratios (4.5:1 for normal text, 3:1 for large text).
- **Focus indicators** — Never remove `:focus` outlines (`outline-none`) without providing a visible alternative (`focus:ring-2 focus:ring-blue-500`).
- **No `onClick` on non-interactive elements** — If something is clickable, it must be a `<button>` or `<a>`. Never add click handlers to `<div>`, `<span>`, or `<p>`.
- **Loading states** — Use `role="status"` and `aria-busy="true"` for loading indicators.
- **Error states** — Use `role="alert"` for error messages so screen readers announce them.

#### Code Smells

- `<div onClick=` — should be `<button onClick=`
- `<img>` without `alt` attribute (or `next/image` without `alt`)
- Headings that skip levels (`h1` then `h3`)
- `<input>` without a `<label>`
- `className="outline-none"` without a focus ring alternative
- `<a>` without `href` used as a button — use `<button>` instead
- ARIA attributes used where semantic HTML would suffice

---

## Category Selection Quick Reference

| Problem | Category |
|---|---|
| Component mixes data fetching with rendering | Container-Presentational (1) |
| File in wrong directory | Folder Structure (2) |
| Inconsistent naming | Naming Conventions (3) |
| Imports in wrong order | File Internal Structure (4) |
| `any` type, inline types, untyped responses | TypeScript Strictness (5) |
| `useEffect` misuse, class components | React 18 Hooks (6) |
| `fetch` + `useEffect` for data, untyped SWR | useSWR (7) |
| Missing error boundary, unhandled API errors | Error Handling (8) |
| Snapshot tests, `data-testid` first, untested hooks | Testing (9) |
| Inline styles, `@apply`, `<img>`, wrong class order | Tailwind CSS (10) |
| Wrong data fetching strategy, untyped SSR functions | Data Fetching (11) |
| Missing `next/image`, unnecessary memoization, prop drilling | Performance (12) |
| Non-semantic HTML, missing alt text, broken heading hierarchy | Accessibility (13) |

---

## Refactoring Toward Best Practices

When violations are identified during review or modification:

### General Approach

1. **Fix one category at a time** — Do not refactor toward all 13 categories simultaneously
2. **Prioritize by severity** — Critical first, then Recommended, then Informational
3. **Preserve behavior** — Refactoring should not change what the code does, only how it is structured. Ensure tests pass before and after.
4. **Small steps** — Extract a component, move a file, add types one at a time. Large refactors increase risk.

### Recommended Order When Multiple Categories Are Violated

1. **TypeScript Strictness first** — Add proper types. This catches bugs early and informs all other refactoring.
2. **Folder Structure second** — Move files to correct locations. This makes the codebase navigable.
3. **Container-Presentational third** — Split mixed components. This is the largest structural change.
4. **useSWR fourth** — Replace `useEffect` + `fetch` patterns. This simplifies data fetching.
5. **Remaining categories** — Naming, hooks, error handling, testing, Tailwind, performance, accessibility.

---

## Important Notes

- This skill is specific to **Next.js 14.2 (Pages Router)**, **React 18**, and **TypeScript 5** with **Tailwind CSS 3** and **useSWR**.
- All Critical and Recommended violations must be addressed — this is not advisory, it is enforced.
- When reviewing code, always explain *why* a best practice applies — don't just state the rule.
- This skill complements `tdd-enforcement` (testing workflow) and `solid-principles-reference` (OOP principles). They do not overlap.
- The `ErrorBoundary` class component is the only permitted exception to the "functional components only" rule.
- When building from mockups, always output the component tree diagram before writing any code.
- useSWR must be installed as a project dependency (`npm install swr`) before any client-side data fetching can follow these patterns.
