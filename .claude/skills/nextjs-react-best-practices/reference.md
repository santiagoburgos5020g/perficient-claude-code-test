# Next.js / React / TypeScript — Detailed Category Reference

Complete rules, code smells, and examples for all 13 best practice categories. This file is the detailed companion to `SKILL.md`.

---

## 1. Container-Presentational Component Pattern

**Statement:** All components must follow the Container-Presentational pattern. Components that mix data fetching/business logic with rendering must be split.

**Definitions:**
- **Presentational Components**: Only concerned with *how things look*. Receive data and callbacks via props. No data fetching, no business logic, no state beyond local UI state (toggle, focus).
- **Container Components**: Only concerned with *how things work*. Handle data fetching (useSWR), business logic, state management. Minimal JSX — only composing presentational children.
- **Pages** (`pages/*.tsx`): Act as top-level containers. Handle server-side data fetching and compose components.

**Rules:**
- A presentational component must NEVER import useSWR, call fetch, or contain business logic
- A container component must NEVER contain complex JSX beyond composing presentational children
- Pages act as containers — they handle `getServerSideProps`/`getStaticProps` and compose components
- If a component does both data fetching and rendering, it must be split
- A trivially simple component with no data fetching does NOT need a container

**Code Smells:**
- A component imports `useSWR` or `fetch` AND contains significant JSX
- A component manages business state AND renders UI for it
- A component file exceeds ~150 lines because it handles both data and display
- A component is hard to test because it requires mocking data AND asserting rendered output

**Example:**

```typescript
// BAD — mixed
const ProductList = () => {
  const { data, isLoading } = useSWR<Product[]>('/api/products', fetcher);
  if (isLoading) return <div>Loading...</div>;
  return (
    <section className="grid grid-cols-1 md:grid-cols-3 gap-6 p-4">
      {data?.map((p) => (
        <div key={p.id} className="rounded-lg border p-4">
          <h3>{p.title}</h3>
          <p>${p.price}</p>
        </div>
      ))}
    </section>
  );
};

// GOOD — separated

// components/ProductList/ProductList.tsx (Presentational)
interface ProductListProps {
  products: Product[];
}
const ProductList = ({ products }: ProductListProps) => (
  <section className="grid grid-cols-1 md:grid-cols-3 gap-6 p-4">
    {products.map((p) => (
      <ProductCard key={p.id} product={p} />
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

### Mockup-to-Code Workflow

When building components from a mockup (Figma, image, wireframe), follow this exact order:

**Step 1 — Decompose the mockup into a component tree.** Output a text diagram before writing any code:

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

**Step 2 — Define TypeScript interfaces for all props** before writing any JSX. Shared types go in `types/`, component-specific types co-located.

**Step 3 — Build presentational components first** with typed props and Tailwind CSS. They must render correctly with mock data.

**Step 4 — Wire up container components and hooks** with data fetching, state management, and loading/error/empty state handling.

---

## 2. Folder Structure

**Statement:** Every file must live in the correct directory according to its role.

**Enforced Layout:**

```
project-root/
  components/              # Presentational components ONLY
    ProductCard/
      ProductCard.tsx
      ProductCard.test.tsx
  containers/              # Container components ONLY
    ProductListContainer/
      ProductListContainer.tsx
      ProductListContainer.test.tsx
  hooks/                   # Custom hooks ONLY
    useProducts.ts
    useProducts.test.ts
  types/                   # TypeScript interfaces/types/enums ONLY (no runtime code)
    product.ts
    api.ts
  pages/                   # Next.js route pages and API routes ONLY
    index.tsx
    api/products/index.ts
  lib/                     # External service configs (fetcher, prisma client)
    fetcher.ts
    prisma.ts
  utils/                   # Pure utility functions (no hooks, no API calls)
  styles/                  # Global CSS only
  public/                  # Static assets
```

**Rules:**
- Each component/container lives in its own PascalCase folder with co-located test file
- `components/` — No data fetching, no business logic
- `containers/` — Handle data fetching and state, render presentational components
- `hooks/` — Each hook in its own file with co-located test
- `types/` — No runtime code, only type definitions
- `lib/` — No business logic, only service configurations

**Code Smells:**
- A file in `components/` imports useSWR or calls fetch
- A file in `types/` exports a function
- A hook lives inside `components/` instead of `hooks/`
- Test files in `__tests__/` instead of co-located

---

## 3. Naming Conventions

**Statement:** Consistent naming makes every file and symbol's role immediately clear.

**Files:**

| Type | Convention | Example |
|---|---|---|
| Presentational component | PascalCase | `ProductCard.tsx` |
| Container component | PascalCase + `Container` suffix | `ProductListContainer.tsx` |
| Custom hook | camelCase + `use` prefix | `useProducts.ts` |
| Type/Interface file | camelCase | `product.ts` |
| Test file | Same name + `.test` | `ProductCard.test.tsx` |
| Page file | camelCase | `products.tsx` |
| API route | camelCase | `pages/api/products/index.ts` |
| Utility | camelCase | `formatPrice.ts` |

**TypeScript:**

| Kind | Convention | Example |
|---|---|---|
| Props | PascalCase + `Props` | `ProductCardProps` |
| Hook return | PascalCase + `Return` | `UseProductsReturn` |
| API response | PascalCase + `Response` | `ProductListResponse` |
| API request | PascalCase + `Request` | `CreateProductRequest` |
| Data model | PascalCase | `Product`, `Order` |
| Enum | PascalCase | `OrderStatus` |

**Variables:**

| Kind | Convention | Example |
|---|---|---|
| Components | PascalCase | `ProductCard` |
| Hooks | `use` prefix | `useProducts` |
| Event handlers (internal) | `handle` prefix | `handleClick` |
| Callback props | `on` prefix | `onClick`, `onSubmit` |
| Boolean props/vars | `is`/`has`/`should` prefix | `isLoading`, `hasError` |
| Constants (module-level) | SCREAMING_SNAKE_CASE | `MAX_ITEMS_PER_PAGE` |

**Code Smells:**
- Container file without `Container` suffix
- Hook without `use` prefix
- Component file in camelCase
- Boolean named `loading` instead of `isLoading`

---

## 4. Component File Internal Structure

**Statement:** Every component file must follow a consistent internal ordering.

**Required Order:**

```typescript
// 1. External imports (React, Next.js, third-party)
import { useState } from 'react';
import Image from 'next/image';

// 2. Internal absolute imports
import { useProducts } from '@/hooks/useProducts';
import { Product } from '@/types/product';

// 3. Internal relative imports
import ProductCard from './ProductCard';

// 4. Type/Interface definitions
interface ProductListProps {
  products: Product[];
}

// 5. Constants
const MAX_VISIBLE = 12;

// 6. Component definition
const ProductList = ({ products }: ProductListProps) => {
  // hooks first
  // derived state (computed during render)
  // event handlers
  // render (return)
};

export default ProductList;

// 7. Server-side functions (pages only)
```

**Import Group Order** (blank line between each):
1. React
2. Next.js
3. Third-party libraries
4. Internal absolute imports (`@/`)
5. Internal relative imports (`./`)

---

## 5. TypeScript Strictness

**Statement:** Every value, prop, return type, and API response must be properly typed.

**Rules:**
- **Never use `any`** — Use `unknown` + type guards if type is truly unknown
- **All props must have a named interface** — No inline `{ title: string }` in component signatures
- **API responses must be typed** — No untyped `res.json()`
- **Strict null checks** — Handle `null`/`undefined` explicitly. No `!` without a comment
- **No `as` assertions** without a comment explaining why. Prefer type guards
- **No `@ts-ignore` or `@ts-expect-error`** — Fix the type error
- **`const` over `let`** — Use `let` only when reassignment is needed. Never `var`
- **`interface` for object shapes** — `type` for unions, intersections, mapped types
- **Export shared types from `types/`** — Not defined inline in component files
- **Explicit return types** on exported functions and hooks

**Code Smells:**
- `: any` anywhere
- `as SomeType` without a comment
- `@ts-ignore` or `@ts-expect-error`
- Inline anonymous types in component parameters
- Untyped `res.json()`
- `!` without a comment
- `var` anywhere
- Shared types defined inside component files

```typescript
// BAD
const ProductCard = ({ title, price }: { title: string; price: number }) => { ... }
const data: any = await fetch('/api/products');

// GOOD
interface ProductCardProps {
  title: string;
  price: number;
}
const ProductCard = ({ title, price }: ProductCardProps) => { ... }
const data: ProductListResponse = await res.json();
```

---

## 6. React 18 Hooks Best Practices

**Statement:** All components must be functional. Hooks must follow React 18 patterns.

**General Rules:**
- **Functional components only** — No class components. (Exception: ErrorBoundary)
- **Hooks at the top level** — Never inside conditions, loops, or nested functions
- **Custom hook extraction** — If ~15+ lines of hook logic, extract to `hooks/`

**Hook Decision Table:**

| Hook | Use When | Don't Use When |
|---|---|---|
| `useState` | Simple UI state | Complex multi-value state (use `useReducer`) |
| `useReducer` | Complex/related state values | Simple toggles |
| `useEffect` | Syncing with external systems | Data fetching, derived state, event handling |
| `useMemo` | Expensive computations with same inputs | Trivial operations "just in case" |
| `useCallback` | Stable refs for memoized children | Every handler by default |
| `useRef` | DOM refs, mutable non-rendering values | State that should trigger re-renders |
| `useContext` | Avoiding prop drilling beyond 2 levels | Frequently changing global state |

**Forbidden Patterns:**
- `useEffect` for data fetching — use useSWR
- `useEffect` for derived state — compute during render
- `useEffect` for event handling — use event handlers
- Cascading state updates in `useEffect` — use `useReducer`
- `// eslint-disable-next-line react-hooks/exhaustive-deps` — restructure the effect

```typescript
// BAD — useEffect for derived state
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);

// GOOD — compute during render
const fullName = `${firstName} ${lastName}`;
```

---

## 7. useSWR Best Practices

**Statement:** useSWR is mandatory for all client-side data fetching. No `fetch` + `useEffect`.

**Setup — Shared fetcher in `lib/fetcher.ts`:**

```typescript
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
    throw new FetchError(`Fetch error: ${res.status}`, res.status, info);
  }
  return res.json();
};

export default fetcher;
```

**Global config in `pages/_app.tsx`:**

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

**Rules:**
- All client-side data fetching must use useSWR
- Always type with generics: `useSWR<Product[]>(key)`
- Use SWR's built-in `error` and `isLoading` — no separate `useState` for these
- Wrap every `useSWR` call in a custom hook in `hooks/`
- Custom hooks must define a return type interface
- Conditional fetching: `useSWR(shouldFetch ? key : null)`
- Key convention: use the API route path (`/api/products`, `/api/products/${id}`)
- Use `mutate` for optimistic updates

**Custom Hook Pattern:**

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

**Forbidden:**
- `useEffect` + `fetch` + `useState` for data fetching
- Untyped `useSWR` (must use `useSWR<Type>`)
- Inline fetchers — use shared fetcher
- Direct `useSWR` in components — always wrap in custom hook

---

## 8. Error Handling

**Statement:** Errors must be handled at every level. No unhandled exceptions.

**Error Boundary** (the only permitted class component):

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
    if (this.state.hasError) return this.props.fallback;
    return this.props.children;
  }
}

export default ErrorBoundary;
```

**Rules:**
- Wrap each major page section in its own `ErrorBoundary`
- Always handle useSWR `error` state in containers
- Use a reusable `ErrorMessage` presentational component with `role="alert"`
- All API routes return errors in standard shape: `{ error: string, statusCode: number }`
- API routes must validate request method — return 405 for unsupported
- `getServerSideProps`/`getStaticProps` must wrap fetching in try/catch
- Use `notFound: true` when a resource doesn't exist
- Never expose internal error details to the client

**API Error Standard Shape:**

```typescript
// types/api.ts
interface ApiError {
  error: string;
  statusCode: number;
}
```

**API Route Pattern:**

```typescript
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

## 9. Testing Patterns

**Statement:** Complements `tdd-enforcement` by defining *how* tests are written. The TDD skill governs workflow (tests first, 100% coverage). This section governs patterns.

**Rules:**
- Every presentational component must have a `.test.tsx` file
- Container components tested separately from presentational
- Custom hooks tested with `renderHook`
- API routes must have integration tests
- No snapshot tests — explicit assertions only

**Query Priority (in order):**
1. `getByRole` — buttons, headings, links
2. `getByLabelText` — form inputs
3. `getByPlaceholderText` — form inputs
4. `getByText` — visible text
5. `getByDisplayValue` — current form values
6. `getByAltText` — images
7. `getByTitle` — title attribute
8. `getByTestId` — **last resort only**

**Presentational Test** — test with props alone, no mocking:

```typescript
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
});
```

**Container Test** — mock the hook, test loading/error/success:

```typescript
jest.mock('@/hooks/useProducts');
const mockUseProducts = useProducts as jest.MockedFunction<typeof useProducts>;

describe('ProductListContainer', () => {
  test('renders loading state', () => {
    mockUseProducts.mockReturnValue({
      products: undefined, isLoading: true, error: undefined, mutate: jest.fn(),
    });
    render(<ProductListContainer />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  test('renders error state', () => {
    mockUseProducts.mockReturnValue({
      products: undefined, isLoading: false, error: new Error('Failed'), mutate: jest.fn(),
    });
    render(<ProductListContainer />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });
});
```

**Hook Test** — with SWR wrapper:

```typescript
const wrapper = ({ children }: { children: ReactNode }) => (
  <SWRConfig value={{ dedupingInterval: 0, provider: () => new Map() }}>
    {children}
  </SWRConfig>
);

describe('useProducts', () => {
  test('returns products on success', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: true, json: async () => [{ id: '1', title: 'Product', price: 10 }],
    });
    const { result } = renderHook(() => useProducts(), { wrapper });
    await waitFor(() => expect(result.current.products).toHaveLength(1));
  });
});
```

**API Route Test:**

```typescript
describe('/api/products', () => {
  test('returns 200 for GET', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({ method: 'GET' });
    await handler(req, res);
    expect(res._getStatusCode()).toBe(200);
  });

  test('returns 405 for unsupported method', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({ method: 'DELETE' });
    await handler(req, res);
    expect(res._getStatusCode()).toBe(405);
  });
});
```

---

## 10. Tailwind CSS Conventions

**Statement:** Tailwind utility classes are the only permitted styling approach.

**Rules:**
- **No inline styles** — No `style={{ }}`. Tailwind utilities only.
- **No `@apply`** — Extract repeated combinations into reusable presentational components
- **No CSS modules or styled-components**
- **Responsive**: mobile-first with `sm:`, `md:`, `lg:`, `xl:`, `2xl:` breakpoint prefixes
- **Class ordering**: layout > positioning > spacing > sizing > typography > colors > borders > effects > transitions > responsive/state
- **Use design tokens** from `tailwind.config.ts` — no arbitrary values when a token exists
- **Long classNames** — break across multiple lines if ~100+ characters

**Forbidden:**
- `style={{ }}` on any element
- `@apply` in CSS files
- `<img>` tag (use `next/image`)
- `<a>` for internal links (use `next/link`)
- Arbitrary values (`text-[13px]`) when a Tailwind token exists
- CSS modules or styled-components

**Code Smells:**
- Component importing `.css` or `.module.css` (except `globals.css` in `_app.tsx`)
- `style=` in JSX
- `@apply` in any CSS file
- Arbitrary bracket values for standard widths/sizes

---

## 11. Pages Router Data Fetching Strategy

**Statement:** Every data fetch must use the correct strategy based on freshness requirements.

**Decision Table:**

| Scenario | Strategy |
|---|---|
| Data rarely changes, same for all users | `getStaticProps` |
| Dynamic routes with known paths | `getStaticPaths` + `getStaticProps` (`fallback: 'blocking'`) |
| Data changes occasionally | `getStaticProps` with `revalidate` (ISR) |
| Must be fresh every request, user-specific | `getServerSideProps` |
| Changes after page load | useSWR (client-side via custom hook) |
| Never changes | `getStaticProps` without `revalidate` |

**Rules:**
- Never fetch data in `useEffect` — useSWR for client-side, SSR/SSG functions for server-side
- Always type with generics: `GetServerSideProps<PageProps>`, `GetStaticProps<PageProps>`
- Use `InferGetServerSidePropsType` / `InferGetStaticPropsType` for page props when possible
- API routes must validate request method (405 for unsupported)
- API routes must type responses: `NextApiResponse<DataType | ApiError>`
- Prefer `getStaticProps` over `getServerSideProps` when freshness allows

**Code Smells:**
- `useEffect` + `fetch` for initial page data
- `getServerSideProps` for data that changes weekly (use ISR)
- `getStaticProps` for user-specific data
- Untyped `GetServerSideProps` (missing generic)
- API route without method validation

---

## 12. Performance Optimization

**Statement:** Use Next.js built-in optimizations. Enforce known performance patterns.

**Rules:**
- **`next/image` over `<img>`** — Always, no exceptions
- **`next/link` over `<a>`** — Always for internal navigation. Plain `<a>` only for external links.
- **`next/dynamic`** — For components not needed on initial render (modals, charts, rich editors)
- **`useMemo`** — Only for expensive computations, not trivial operations
- **`useCallback`** — Only when passed to `React.memo`-wrapped children or used as effect dependencies
- **`React.memo`** — Only for components with complex props that render frequently
- **No prop drilling beyond 2 levels** — Extract to custom hook or React Context
- **No inline object/array literals** as props to memoized children

**Code Smells:**
- `<img src=` anywhere
- `<a href="/internal-route">` for internal navigation
- `useMemo` wrapping trivial operations
- `useCallback` on handlers not passed to memoized children
- Props passing through 3+ layers without use by intermediate components

---

## 13. Accessibility (a11y)

**Statement:** All UI must be accessible. Built into every component, not a separate concern.

**Rules:**
- **Semantic HTML** — `<main>`, `<nav>`, `<section>`, `<article>`, `<header>`, `<footer>` over `<div>`. `<button>` for actions, `<a>` for navigation.
- **All images must have `alt`** — Decorative: `alt=""`. Meaningful: describe content.
- **Keyboard accessible** — All interactive elements focusable and operable via keyboard. No `onClick` on `<div>` or `<span>`.
- **Heading hierarchy** — `h1` > `h2` > `h3`, no skipping. One `h1` per page.
- **ARIA** — Only when semantic HTML is insufficient. Use `role="status"` for loading, `role="alert"` for errors.
- **Form labels** — Every `<input>` must have `<label>` with matching `htmlFor`/`id`.
- **Color contrast** — WCAG AA minimum (4.5:1 normal text, 3:1 large text).
- **Focus indicators** — Never `outline-none` without a visible alternative (`focus:ring-2 focus:ring-blue-500`).
- **No `onClick` on non-interactive elements** — Use `<button>` or `<a>`, never `<div onClick=`.
- **Loading states** — `role="status"` and `aria-busy="true"`
- **Error states** — `role="alert"` for screen reader announcement

**Code Smells:**
- `<div onClick=` — should be `<button>`
- Image without `alt`
- Headings that skip levels
- `<input>` without `<label>`
- `outline-none` without focus ring alternative
- `<a>` without `href` used as button
