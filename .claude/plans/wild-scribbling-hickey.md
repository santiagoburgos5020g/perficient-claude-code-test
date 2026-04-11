# Implementation Plan: Next.js E-commerce with Infinite Scroll

## Context

Build a Next.js 14 e-commerce app from scratch per `ecommerce-spec.md`. The project directory currently contains only the spec file and 3 Perficient brand reference images in `templates-example/`. Every file (Next.js project, database, components, API, config) must be created.

The app displays ~1,000 products in an infinite-scroll grid using Perficient's corporate brand (teal/blue, Inter font, sharp corners, shadow cards). Data comes from a local SQLite database via Prisma, fetched through a paginated REST API.

---

## Phase 1: Project Scaffolding & Configuration

1. **Initialize Next.js 14** with Pages Router, TypeScript, Tailwind, ESLint:
   ```
   npx create-next-app@14 . --typescript --tailwind --eslint --src-dir=false --app=false --import-alias="@/*"
   ```
2. **Install dependencies**: `prisma`, `@prisma/client`, `ts-node` (dev), `prettier` (dev)
3. **Overwrite config files** with spec-provided versions:
   - `next.config.js` — add `picsum.photos` to `remotePatterns`
   - `tailwind.config.ts` — Perficient colors, Inter font, content paths for `pages/` + `features/`
   - `styles/globals.css` — Tailwind directives only
   - `pages/_app.tsx` — Inter font via `next/font/google`, `<main>` wrapper
4. **Create**: `.prettierrc`, `.env.development`, `.env.production`

**Verify**: `npm run dev` starts without errors, Inter font loads, Tailwind compiles.

---

## Phase 2: Database (Prisma + SQLite + Seed)

1. `npx prisma init --datasource-provider sqlite`
2. Write `prisma/schema.prisma` — Product model (id, name, description, price, image, timestamps)
3. Write `prisma/seed.ts`:
   - 50+ adjectives + 50+ nouns for random product names
   - Template sentences for descriptions (10-20 words)
   - Prices: `Math.round(Math.random() * 49000 + 1000) / 100`
   - Images: `https://picsum.photos/400/400?random={id}`
   - Batch inserts (100 per `createMany`) to avoid SQLite variable limits
4. Add `prisma.seed` config to `package.json`
5. Run: `npx prisma generate && npx prisma migrate dev --name init && npx prisma db seed`

**Verify**: `npx prisma studio` shows exactly 1,000 products with valid data.

---

## Phase 3: TypeScript Types & Utilities

1. Create directory structure: `features/products/{types,hooks,components,utils}/`
2. `features/products/types/product.ts` — `Product`, `PaginationMeta`, `ProductsApiResponse`, `ProductsApiError`
3. `features/products/utils/formatPrice.ts` — `(price: number) => \`$${price.toFixed(2)}\``

---

## Phase 4: Products API Endpoint

**File**: `pages/api/products/index.ts`

- Parse & validate `page` (default 1, >= 1) and `limit` (default 30, 1-100)
- 400 for invalid params, 405 for non-GET
- Prisma query: `findMany` with skip/take + `count()`
- Return `{ products, pagination: { page, limit, total, totalPages, hasMore } }`
- 500 with try/catch for database errors

**Verify**: Test all 8 API scenarios from spec section 8.2 via curl.

---

## Phase 5: UI Components

All in `features/products/components/`:

1. **LoadingSpinner.tsx** — `centered?: boolean` prop, `animate-spin` circle in `border-perficient-blue`, `role="status"` + `aria-label`
2. **ErrorDisplay.tsx** — red error text + Perficient blue retry button (sharp corners, uppercase, white text)
3. **ProductCard.tsx** — `<article>`, `next/image` with `onError` gray fallback, name/description/price, `shadow-md` → `hover:shadow-xl`
4. **ProductGrid.tsx** — `<section aria-label="Product catalog">`, `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`

---

## Phase 6: Infinite Scroll Hook

**File**: `features/products/hooks/useInfiniteScroll.ts`

- **State**: `products[]`, `page`, `isLoading`, `isInitialLoading`, `error`, `hasMore`
- **Refs**: `loadingRef` (concurrent fetch guard), `sentinelRef` (observer target), `observerRef`
- **fetchProducts**: checks `loadingRef.current` first, fetches `/api/products?page=N&limit=30`, appends products on success, sets error on failure, only increments page on success
- **IntersectionObserver**: watches sentinel, fires fetch when intersecting + hasMore
- **retry()**: re-calls fetchProducts at same page
- Returns: `{ products, isLoading, isInitialLoading, error, hasMore, sentinelRef, retry }`

Key: Use `useRef` for loading guard (not state) to avoid stale closures in observer callback.

---

## Phase 7: Page Assembly

**File**: `pages/index.tsx`

Conditional rendering order:
1. `isInitialLoading` → `<LoadingSpinner centered />`
2. `error && products.length === 0` → `<ErrorDisplay>` centered
3. `products.length > 0` → `<ProductGrid>`
4. `isLoading && !isInitialLoading` → `<LoadingSpinner>` at bottom
5. `error && products.length > 0` → `<ErrorDisplay>` at bottom
6. `!hasMore && products.length > 0` → "You've reached the end of the catalog"
7. `hasMore` → sentinel `<div ref={sentinelRef}>`

Wrapper: `<div className="px-4 py-4 bg-white min-h-screen">`

**Verify** (full manual test):
- Initial load: spinner → 30 products
- Scroll loads batches of 30, all 1,000 reachable
- Responsive: 1/2/4 columns at mobile/tablet/desktop
- Card hover shadow, lazy images, "$XX.XX" prices
- End-of-list message appears
- No duplicate products or fetches
- Error + retry works for both initial and scroll failures

---

## Phase 8: Documentation & Claude Config

1. `spec/nextjs-ecommerce/ecommerce-spec.md` — copy spec to canonical location
2. `.claude/folder-restriction.md` — restrict operations to project directory
3. `.claude/spec-structure.md` — spec naming convention rule
4. `CLAUDE.md` — references both rules, "Do not use external rules"
5. `README.md` — title, prerequisites, setup steps, npm scripts, tech stack
6. Update `package.json` scripts: add `format`, `prisma:generate`, `prisma:migrate`, `prisma:seed`, `prisma:studio`

---

## Critical Files (most complex logic)

| File | Why |
|---|---|
| `features/products/hooks/useInfiniteScroll.ts` | Observer lifecycle, stale closure risk, concurrent fetch prevention |
| `pages/api/products/index.ts` | Validation, Prisma queries, pagination math |
| `pages/index.tsx` | Orchestrates all conditional rendering states |
| `prisma/seed.ts` | 1,000 products, batching for SQLite limits |
| `features/products/components/ProductCard.tsx` | next/image + error fallback + brand styling |

---

## Verification

After all phases, run the full manual testing checklist (spec section 8.1):
- Start dev server (`npm run dev`)
- Confirm initial load, infinite scroll through all 1,000 products
- Test all responsive breakpoints
- Verify Perficient brand: blue spinners/buttons, Inter font, sharp corners, shadow cards
- Test error states (temporarily break API)
- Check accessibility (alt text, keyboard nav, focus indicators)
- Check Network tab for no duplicate fetches
- Confirm no console errors/warnings
