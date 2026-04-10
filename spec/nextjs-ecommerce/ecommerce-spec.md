# Next.js E-commerce Application Specification

**Version:** 2.0  
**Date:** April 10, 2026  
**Status:** Ready for Implementation

---

## 1. Project Overview

### 1.1 Description
Build a Next.js e-commerce application featuring an infinite-scroll product listing with approximately 1,000 products. The application uses Perficient's corporate design system (teal and blue color scheme) with a clean, professional aesthetic derived from the provided brand templates.

### 1.2 Key Objectives
- Display products in a responsive grid with infinite scrolling
- Match the Perficient corporate brand aesthetic from `templates-example/` reference files
- Use a local SQLite database seeded with 1,000 realistic mock products
- Implement robust loading and error states
- Maintain type-safe, well-organized TypeScript code

---

## 2. Technical Stack

### 2.1 Core Technologies
| Technology | Version / Detail |
|---|---|
| **Framework** | Next.js 14.x (Pages Router) |
| **Language** | TypeScript |
| **React** | React 18 (default with Next.js 14) |
| **Package Manager** | npm |

### 2.2 Styling
| Technology | Detail |
|---|---|
| **CSS Framework** | Tailwind CSS (utility-first) |
| **Font** | Inter (Google Fonts) |

### 2.3 Database & ORM
| Technology | Detail |
|---|---|
| **Database** | SQLite (local file-based) |
| **ORM** | Prisma |

### 2.4 Development Tools
| Tool | Purpose |
|---|---|
| **ESLint** | Linting |
| **Prettier** | Code formatting |
| **ts-node** | Execute TypeScript seed script |
| **Dev Server** | Port 3000 (Next.js default) |

### 2.5 Browser Support
- Chrome (latest 2 versions)
- Firefox (latest 2 versions)
- Safari (latest 2 versions)
- Edge (latest 2 versions)

---

## 3. Architecture

### 3.1 Routing Approach
- **Type:** Pages Router (`pages/` directory)
- **Reason:** Selected over App Router per project requirements

### 3.2 Project Folder Structure
Feature-based organization:

```
project-root/
├── .claude/                          # Claude rules
│   ├── folder-restriction.md
│   └── spec-structure.md
├── CLAUDE.md                         # Claude config (references .claude/ rules)
├── spec/
│   └── nextjs-ecommerce/
│       └── ecommerce-spec.md         # This specification
├── templates-example/                # Design reference images
│   ├── 1.png
│   ├── 2.png
│   └── 3.png
├── pages/
│   ├── _app.tsx                      # Global layout, font, Tailwind CSS import
│   ├── index.tsx                     # Product listing page (entry point)
│   └── api/
│       └── products/
│           └── index.ts              # Products REST endpoint
├── features/
│   └── products/
│       ├── components/
│       │   ├── ProductCard.tsx        # Single product card
│       │   ├── ProductGrid.tsx        # Responsive grid of cards
│       │   ├── LoadingSpinner.tsx     # Reusable branded spinner
│       │   └── ErrorDisplay.tsx       # Error message + retry button
│       ├── types/
│       │   └── product.ts            # Product & API response types
│       ├── hooks/
│       │   └── useInfiniteScroll.ts   # Infinite scroll logic
│       └── utils/
│           └── formatPrice.ts         # Price formatting utility
├── styles/
│   └── globals.css                   # Tailwind directives + global styles
├── prisma/
│   ├── schema.prisma                 # Database schema
│   └── seed.ts                       # Seed script (1,000 products)
├── public/                           # Static assets (if any)
├── next.config.js                    # Next.js configuration (image domains)
├── tailwind.config.ts                # Tailwind with Perficient custom colors
├── tsconfig.json
├── .eslintrc.json
├── .prettierrc
├── .env.development
├── .env.production
├── package.json
└── README.md
```

### 3.3 Data Flow
```
User scrolls to bottom
  → Intersection Observer fires
  → useInfiniteScroll hook calls GET /api/products?page=N&limit=30
  → API route queries Prisma → SQLite
  → JSON response with products + pagination metadata
  → Hook appends products to state
  → ProductGrid re-renders with new cards
```

---

## 4. Data Model

### 4.1 Prisma Schema

**File:** `prisma/schema.prisma`

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model Product {
  id          Int      @id @default(autoincrement())
  name        String
  description String
  price       Float
  image       String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

### 4.2 Field Definitions
| Field | Type | Constraints | Notes |
|---|---|---|---|
| `id` | Int | PK, auto-increment | Unique identifier |
| `name` | String | Required | Realistic product name (e.g., "Wireless Headphones") |
| `description` | String | Required | Short, 1 sentence, 10-20 words |
| `price` | Float | Required | Numeric only, $10.00-$500.00 (cents included). "$" added in UI |
| `image` | String | Required | Lorem Picsum URL |
| `createdAt` | DateTime | Auto-set | Record creation timestamp |
| `updatedAt` | DateTime | Auto-set | Record update timestamp |

### 4.3 Data Seeding

**File:** `prisma/seed.ts`

**Seed script requirements:**
- Generate exactly 1,000 products
- **Product names:** Draw from a predefined list of realistic product name patterns. Combine a category adjective with a product noun to produce names like "Premium Wireless Headphones", "Ultra-Slim Laptop Stand", "Compact Bluetooth Speaker". The list should be large enough to avoid excessive repetition across 1,000 entries (use at least 50 adjectives and 50 nouns, combined randomly).
- **Descriptions:** Single sentence, 10-20 words. Use a set of template sentences with varied product descriptors.
- **Prices:** Random float between 10.00 and 500.00, rounded to 2 decimal places (e.g., `Math.round(Math.random() * 49000 + 1000) / 100`).
- **Images:** `https://picsum.photos/400/400?random={id}` where `{id}` is the product's sequential number (1-1000). Square 400x400.

**package.json seed config (required for `npx prisma db seed`):**
```json
{
  "prisma": {
    "seed": "ts-node --compiler-options {\"module\":\"CommonJS\"} prisma/seed.ts"
  }
}
```

**Dev dependency:** `ts-node` must be listed in `devDependencies`.

---

## 5. API Design

### 5.1 Products Endpoint

**Endpoint:** `GET /api/products`

**File:** `pages/api/products/index.ts`

### 5.2 Query Parameters
| Param | Type | Default | Validation |
|---|---|---|---|
| `page` | integer | 1 | Must be >= 1. Non-numeric or <= 0 returns 400. |
| `limit` | integer | 30 | Must be >= 1 and <= 100. Non-numeric or out of range returns 400. |

### 5.3 Success Response (200)
```json
{
  "products": [
    {
      "id": 1,
      "name": "Wireless Headphones",
      "description": "High-quality wireless headphones with active noise cancellation technology.",
      "price": 99.99,
      "image": "https://picsum.photos/400/400?random=1"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 30,
    "total": 1000,
    "totalPages": 34,
    "hasMore": true
  }
}
```

### 5.4 Response Fields
| Field | Type | Description |
|---|---|---|
| `products` | Product[] | Array of product objects for the requested page |
| `pagination.page` | number | Current page number |
| `pagination.limit` | number | Products per page |
| `pagination.total` | number | Total product count in database |
| `pagination.totalPages` | number | `Math.ceil(total / limit)` |
| `pagination.hasMore` | boolean | `true` if more pages exist after current |

### 5.5 Error Responses

**400 Bad Request** - Invalid query parameters:
```json
{
  "error": "Invalid parameters",
  "message": "page must be a positive integer"
}
```

**404 / Empty page** - Page beyond total pages returns 200 with empty products array and `hasMore: false`:
```json
{
  "products": [],
  "pagination": {
    "page": 50,
    "limit": 30,
    "total": 1000,
    "totalPages": 34,
    "hasMore": false
  }
}
```

**500 Internal Server Error** - Database or server failure:
```json
{
  "error": "Failed to fetch products",
  "message": "Internal server error"
}
```

### 5.6 Prisma Query
```typescript
const products = await prisma.product.findMany({
  skip: (page - 1) * limit,
  take: limit,
  orderBy: { id: 'asc' },
});
const total = await prisma.product.count();
```

---

## 6. UI/UX Specifications

### 6.1 Design System (Perficient Brand)

**Source:** `templates-example/` (3 reference PNGs)

#### Colors

**Tailwind custom colors (in `tailwind.config.ts`):**

| Token | Hex | Usage |
|---|---|---|
| `perficient-teal` | `#004d57` | Reserved for headers/hero sections (not used in current scope since there is no header, but defined for consistency) |
| `perficient-blue` | `#005a87` | Buttons, CTAs, loading spinners |
| `perficient-light` | `#f5f7f9` | Light backgrounds (available but page background is white) |
| `perficient-dark` | `#333333` | Body text color |

#### Typography
- **Font family:** Inter (Google Fonts), loaded in `_app.tsx`
- **Fallback stack:** `Inter, ui-sans-serif, system-ui, sans-serif`
- **Product name:** `font-bold text-base` (16px, bold)
- **Description:** `font-normal text-sm text-perficient-dark/70` (14px, regular, slightly muted)
- **Price:** `font-bold text-base` (16px, bold, same size as name)

#### Buttons
- **Background:** `bg-perficient-blue` (`#005a87`)
- **Text:** White, semi-bold, uppercase
- **Corners:** Sharp (no border radius, `rounded-none`)
- **Padding:** `px-6 py-3`
- **Hover:** `hover:bg-opacity-90` with transition

#### Cards
- **Background:** White (`bg-white`)
- **Shadow:** `shadow-md` default, `shadow-xl` on hover
- **Corners:** Sharp (`rounded-none`)
- **Padding:** Medium/standard (`p-4`)
- **Transition:** `transition-shadow duration-200`

### 6.2 Page Layout

- **No header** - Page begins directly with the product grid
- **No footer** - Page ends with the last product, an end-of-list message, or a loading/error state
- **Background:** White (`bg-white`)
- **Grid container:** Full viewport width, edge to edge, with small horizontal padding (`px-4`) for mobile safety

### 6.3 Responsive Grid

**Mobile-first approach using Tailwind breakpoints:**

| Breakpoint | Tailwind Prefix | Columns | Description |
|---|---|---|---|
| Default (< 640px) | none | 1 | Mobile |
| `sm` (>= 640px) | `sm:` | 2 | Tablet |
| `lg` (>= 1024px) | `lg:` | 4 | Desktop |

**Tailwind classes:** `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`

**Grid gap:** `gap-4` (1rem / 16px) in both directions.

### 6.4 Product Card Layout

**Content order (top to bottom):**
1. **Product image** - Square (1:1 aspect ratio), full card width
2. **Product name** - Bold, medium size
3. **Description** - Regular weight, smaller, slightly muted color
4. **Price** - Bold, same size as name, prefixed with "$"

**Image rendering:**
- Use `next/image` component for optimization (lazy loading, responsive sizing)
- Maintain 1:1 aspect ratio via `aspect-square` Tailwind class with `object-cover`
- `alt` attribute set to the product name for accessibility
- Configure `picsum.photos` as allowed remote image domain in `next.config.js`

**Price formatting:**
- Store as numeric float in database (e.g., `99.99`)
- Display with `$` prefix and exactly 2 decimal places
- Formatting utility: `(price: number) => \`$${price.toFixed(2)}\``
- Located at `features/products/utils/formatPrice.ts`

### 6.5 End-of-List State

When all 1,000 products have been loaded (API returns `hasMore: false`):
- Remove the Intersection Observer sentinel
- Display a subtle text message below the grid: "You've reached the end of the catalog"
- Style: `text-sm text-gray-400 text-center py-8`

### 6.6 SEO / Metadata
- Use default Next.js metadata only
- No custom Open Graph tags, structured data, or advanced SEO setup

---

## 7. Error Handling

### 7.1 Initial Page Load Error

**Trigger:** API fails when fetching the first 30 products.

**Display:**
- Centered on page (where the spinner was)
- Error message in red (`text-red-600`)
- Text: "Failed to load products. Please try again."
- Retry button below the message

**Retry button:**
- Perficient blue background (`bg-perficient-blue`), white text, sharp corners, uppercase
- On click: show loading spinner again, re-attempt fetch

### 7.2 Infinite Scroll Error

**Trigger:** API fails while loading subsequent batches.

**Display:**
- Appears at the bottom of the grid, below existing products
- Error message in red (`text-red-600`)
- Text: "Failed to load more products."
- Retry button below the message

**Behavior:**
- All previously loaded products remain visible
- On retry click: show bottom spinner, re-attempt the same page fetch

### 7.3 Error & Retry Styling Summary
| Element | Style |
|---|---|
| Error text | `text-red-600 text-sm` |
| Retry button background | `bg-perficient-blue` (`#005a87`) |
| Retry button text | White, semi-bold, uppercase |
| Retry button corners | Sharp (`rounded-none`) |

---

## 8. Testing Strategy

### 8.1 Manual Testing Checklist

**Initial Load:**
- [ ] Page loads and displays a centered Perficient blue loading spinner
- [ ] First 30 products render in the grid after loading
- [ ] Each card shows image, name, description, and price
- [ ] Grid displays 1 column on mobile (< 640px)
- [ ] Grid displays 2 columns on tablet (>= 640px)
- [ ] Grid displays 4 columns on desktop (>= 1024px)
- [ ] Hover effect increases card shadow elevation
- [ ] Product images are square and load lazily

**Infinite Scroll:**
- [ ] Scrolling to the bottom triggers a fetch for the next 30 products
- [ ] A Perficient blue loading spinner appears at the bottom while fetching
- [ ] New products append below existing ones
- [ ] No duplicate products appear
- [ ] Scrolling quickly does not trigger multiple simultaneous fetches
- [ ] All 1,000 products can be reached by continuous scrolling
- [ ] "You've reached the end of the catalog" message appears after all products load
- [ ] Intersection Observer is cleaned up after end of list

**Error Handling:**
- [ ] Simulate initial load failure: error message + retry button appear centered
- [ ] Clicking retry on initial load re-triggers the fetch with a spinner
- [ ] Simulate infinite scroll failure: error + retry appear at grid bottom
- [ ] Existing products remain visible during scroll errors
- [ ] Retry on scroll error re-fetches the failed page

**Styling & Brand:**
- [ ] Perficient blue (`#005a87`) is used for spinners and buttons
- [ ] Font is Inter throughout the application
- [ ] Cards have white background with box shadows and sharp corners
- [ ] Buttons have sharp corners, white uppercase text, blue background
- [ ] Prices display as "$XX.XX" (dollar sign + exactly 2 decimal places)

**Accessibility:**
- [ ] All product images have descriptive `alt` text (product name)
- [ ] Retry buttons are keyboard-focusable and have visible focus indicators
- [ ] Page is navigable via keyboard (Tab order makes sense)
- [ ] Color contrast meets WCAG AA for text on backgrounds

### 8.2 API Testing

| Test Case | Expected Result |
|---|---|
| `GET /api/products?page=1&limit=30` | 200, 30 products, `hasMore: true` |
| `GET /api/products?page=34&limit=30` | 200, remaining 10 products, `hasMore: false` |
| `GET /api/products?page=35&limit=30` | 200, empty products array, `hasMore: false` |
| `GET /api/products` (no params) | 200, defaults to page=1, limit=30 |
| `GET /api/products?page=0` | 400, invalid parameter error |
| `GET /api/products?page=-1` | 400, invalid parameter error |
| `GET /api/products?page=abc` | 400, invalid parameter error |
| `GET /api/products?limit=200` | 400, limit exceeds maximum (100) |

### 8.3 Performance Checks
- [ ] Initial page load is under 2 seconds on localhost
- [ ] Infinite scroll feels smooth (no visible jank)
- [ ] Images lazy-load (offscreen images don't load until near viewport)
- [ ] No memory leaks after scrolling through all 1,000 products (check DevTools)
- [ ] No unnecessary re-renders (React DevTools Profiler)

---

## 9. Implementation Notes

### 9.1 Key Requirements
- Mobile-first responsive design
- Type-safe TypeScript throughout
- Feature-based folder organization
- Custom infinite scroll with Intersection Observer API (no external libraries)
- Robust error handling with retry capability
- Perficient brand aesthetic from template references
- Accessible markup (semantic HTML, alt text, focus management)

### 9.2 Non-Requirements
- No shopping cart or "Add to Cart" functionality
- No product detail pages or routing beyond the listing
- No user authentication or accounts
- No payment processing
- No product search, filtering, or sorting
- No header or footer
- No custom SEO or Open Graph tags
- No server-side rendering for product data (client-side fetching via API)

### 9.3 Critical Implementation Details

#### `_app.tsx` Setup
```typescript
// pages/_app.tsx
import '@/styles/globals.css';
import type { AppProps } from 'next/app';
import { Inter } from 'next/font/google';

const inter = Inter({ subsets: ['latin'] });

export default function App({ Component, pageProps }: AppProps) {
  return (
    <main className={inter.className}>
      <Component {...pageProps} />
    </main>
  );
}
```

#### Global CSS (`styles/globals.css`)
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

#### Next.js Config (`next.config.js`)
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'picsum.photos',
      },
    ],
  },
};

module.exports = nextConfig;
```

#### Tailwind Config (`tailwind.config.ts`)
```typescript
import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './features/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'perficient-teal': '#004d57',
        'perficient-blue': '#005a87',
        'perficient-light': '#f5f7f9',
        'perficient-dark': '#333333',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
export default config;
```

#### Infinite Scroll Hook (`useInfiniteScroll`)
- Uses a `ref` attached to a sentinel `<div>` rendered after the last product card
- Creates an `IntersectionObserver` that watches the sentinel
- When the sentinel enters the viewport, fires the next page fetch
- **Concurrent fetch prevention:** Uses a `loading` ref (not just state) checked before dispatching fetch; the observer callback is a no-op while `loading.current === true`
- On `hasMore === false`, disconnects the observer and removes the sentinel
- Cleans up the observer on component unmount (`useEffect` cleanup)
- Returns: `{ products, isLoading, isInitialLoading, error, retry }`

#### Image Handling
- Use `next/image` with `width={400}` and `height={400}` for proper sizing
- Wrap in a container with `aspect-square` and `overflow-hidden`
- Apply `object-cover` to handle any minor aspect ratio variance
- On image load error: hide the broken image icon by rendering a neutral gray placeholder `div` as fallback (via `onError` handler)

---

## 10. Environment Variables

### 10.1 File Structure
| File | Purpose |
|---|---|
| `.env.development` | Local development settings |
| `.env.production` | Production settings |

### 10.2 Variables
```env
# .env.development
DATABASE_URL="file:./dev.db"
NEXT_PUBLIC_API_URL="http://localhost:3000"
```

```env
# .env.production
DATABASE_URL="file:./prod.db"
NEXT_PUBLIC_API_URL=""
```

**Note:** `NEXT_PUBLIC_API_URL` is optional; the app can use relative URLs (`/api/products`) and only needs the full URL if deployed to a different origin.

---

## 11. TypeScript Types

**File:** `features/products/types/product.ts`

```typescript
export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  image: string;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

export interface ProductsApiResponse {
  products: Product[];
  pagination: PaginationMeta;
}

export interface ProductsApiError {
  error: string;
  message: string;
}
```

---

## 12. Component Specifications

### 12.1 `pages/index.tsx` - Product Listing Page
- Renders `<ProductGrid>` with products from `useInfiniteScroll`
- Conditionally renders `<LoadingSpinner>` (centered) during initial load
- Conditionally renders `<ErrorDisplay>` for initial load failure
- Renders bottom `<LoadingSpinner>` during scroll fetches
- Renders bottom `<ErrorDisplay>` for scroll fetch failures
- Renders end-of-list message when `hasMore === false` and products are loaded

### 12.2 `ProductCard.tsx`
- **Props:** `product: Product`
- Renders: image (via `next/image`), name, description, formatted price
- Semantic HTML: `<article>` element for each card
- Accessible: `alt` text on image = product name

### 12.3 `ProductGrid.tsx`
- **Props:** `products: Product[]`
- Renders responsive CSS Grid: `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`
- Maps over products and renders `<ProductCard>` for each
- Semantic HTML: `<section>` wrapper with an `aria-label="Product catalog"`

### 12.4 `LoadingSpinner.tsx`
- **Props:** `centered?: boolean` (if `true`, centers on page; if `false`, displays inline at bottom)
- Renders an animated spinner using Perficient blue (`#005a87`)
- Implementation: CSS animation (spin) on a bordered circle element
- Accessible: `role="status"` and `aria-label="Loading products"`

### 12.5 `ErrorDisplay.tsx`
- **Props:** `message: string`, `onRetry: () => void`
- Renders error message in red and retry button in Perficient blue
- Accessible: retry button has clear label text ("Retry")

---

## 13. Claude Configuration

### 13.1 Directory Structure
```
.claude/
├── folder-restriction.md   # All operations within project folder only
└── spec-structure.md        # Spec files must follow spec/{name}/{spec}.md
```

### 13.2 CLAUDE.md
**Location:** Project root (`/CLAUDE.md`)

**Content:**
- References all rules in the `.claude/` directory
- Explicit statement: "Do not use, reference, or apply any external rules."
- Lists each active rule file with a brief description

### 13.3 Rules Summary
| Rule File | Purpose |
|---|---|
| `folder-restriction.md` | All file operations restricted to the project directory |
| `spec-structure.md` | Specifications must follow `spec/{project-name}/{spec-name}.md` structure and include all required sections |

---

## 14. Database Setup & Migration

### 14.1 Setup Commands (executed in order)
```bash
npx prisma generate          # Generate Prisma Client
npx prisma migrate dev --name init   # Create and apply initial migration
npx prisma db seed           # Populate 1,000 products
```

### 14.2 Verification
After seeding, verify with:
```bash
npx prisma studio            # Opens browser UI to inspect data
```
Confirm exactly 1,000 product rows exist.

---

## 15. Development Workflow

### 15.1 Setup Steps
1. Clone the repository
2. `npm install` - Install all dependencies
3. Copy `.env.development` to `.env` (or rely on Next.js auto-loading `.env.development`)
4. `npx prisma generate` - Generate Prisma Client
5. `npx prisma migrate dev --name init` - Create database and apply schema
6. `npx prisma db seed` - Seed 1,000 products
7. `npm run dev` - Start development server
8. Open `http://localhost:3000`

### 15.2 NPM Scripts
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "format": "prettier --write .",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:seed": "prisma db seed",
    "prisma:studio": "prisma studio"
  }
}
```

### 15.3 README.md Content
The README should contain:
- Project title and one-line description
- Prerequisites (Node.js >= 18, npm)
- Setup steps (from section 15.1 above)
- Available npm scripts
- Tech stack summary (one-liner per technology)

---

## 16. Design Reference

### 16.1 Template Files
**Location:** `templates-example/`

| File | Content | Key Elements |
|---|---|---|
| `1.png` | Perficient Brand Center header | Dark teal hero section, clean typography |
| `2.png` | Overview & Brand Standards | Card grid layout, white cards with shadows |
| `3.png` | Creative Requests page | CTA button style (solid blue, white uppercase text, sharp corners) |

### 16.2 Extracted Design Tokens
| Element | Value | Source |
|---|---|---|
| Dark teal | `#004d57` | Template 1 - header/hero |
| Primary blue | `#005a87` | Template 3 - CTA buttons |
| Light background | `#f5f7f9` | Template 2 - page background |
| Dark text | `#333333` | Template 2 - body text |
| Card style | White, shadow, sharp corners | Template 2 - card grid |
| Button style | Solid blue, white text, uppercase, sharp | Template 3 - CTA |
| Spacing | Generous, professional | All templates |

---

## 17. Accessibility

### 17.1 Requirements
- All `<img>` elements (via `next/image`) must have descriptive `alt` text (product name)
- Interactive elements (retry buttons) must be keyboard-accessible with visible focus indicators
- Use semantic HTML: `<main>`, `<section>`, `<article>` where appropriate
- Loading spinner must have `role="status"` and `aria-label`
- Color contrast for text must meet WCAG 2.1 AA minimum (4.5:1 for normal text)
- Perficient blue (`#005a87`) on white passes AA for large text; verify body text contrast

---

## 18. Deliverables

### 18.1 Code Deliverables
- [ ] Fully functional Next.js 14 application with Pages Router
- [ ] Prisma schema, migration files, and seed script
- [ ] Database seeded with 1,000 realistic mock products
- [ ] All components implemented in TypeScript
- [ ] Tailwind CSS configuration with Perficient custom colors
- [ ] Custom infinite scroll using Intersection Observer (no libraries)
- [ ] Loading states (initial spinner, bottom spinner)
- [ ] Error handling with retry for both initial load and scroll failures
- [ ] End-of-list message when all products are loaded
- [ ] `next/image` for optimized, lazy-loaded product images

### 18.2 Configuration Deliverables
- [ ] `.claude/` directory with `folder-restriction.md` and `spec-structure.md`
- [ ] `CLAUDE.md` at project root referencing `.claude/` rules
- [ ] `next.config.js` with remote image domain configuration
- [ ] `tailwind.config.ts` with Perficient brand tokens
- [ ] `.env.development` and `.env.production`
- [ ] `.eslintrc.json` and `.prettierrc`

### 18.3 Documentation Deliverables
- [ ] This specification document (`spec/nextjs-ecommerce/ecommerce-spec.md`)
- [ ] `README.md` with setup instructions

---

## 19. Success Criteria

The implementation is complete when:

### Functionality
- [ ] Initial page load displays exactly 30 products
- [ ] Infinite scroll loads subsequent batches of 30 products each
- [ ] All 1,000 products are reachable by continuous scrolling
- [ ] End-of-list message appears after the last product
- [ ] Error states display correctly with functional retry buttons
- [ ] No duplicate products or duplicate fetches occur

### Design
- [ ] Visual style matches Perficient brand templates (teal/blue palette)
- [ ] Responsive grid: 1 col mobile, 2 col tablet, 4 col desktop
- [ ] Cards have white background, box shadows, sharp corners
- [ ] Hover elevates card shadow
- [ ] Buttons are solid blue, white uppercase text, sharp corners
- [ ] Font is Inter throughout

### Performance
- [ ] Initial load completes in under 2 seconds (localhost)
- [ ] Scroll loading is smooth with no visible jank
- [ ] Images lazy-load via `next/image`
- [ ] No memory leaks over extended scrolling

### Code Quality
- [ ] TypeScript with proper typing (no `any` types)
- [ ] Clean feature-based folder structure
- [ ] Passes ESLint and Prettier checks
- [ ] No console errors or warnings in browser DevTools

### Configuration
- [ ] `.claude/` rules properly configured
- [ ] `CLAUDE.md` correctly references all rules
- [ ] Prisma database migrated and seeded with 1,000 products

---

**End of Specification**
