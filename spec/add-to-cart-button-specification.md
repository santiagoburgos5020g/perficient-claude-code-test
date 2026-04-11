# Add to Cart Button - Feature Specification

**Version:** 1.1  
**Date:** 2026-04-10  
**Status:** Ready for Development

---

## 1. Overview

### 1.1 Feature Summary
Add an "Add To Cart" button to each product card on the main page. This is a UI-only implementation with no functional behavior (button click does nothing for now).

### 1.2 Scope
- **In Scope:** Add button UI to ProductCard component; refactor card layout to support consistent button placement; install and configure test framework
- **Out of Scope:** Cart functionality, state management, backend integration

---

## 2. Requirements

### 2.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Display "Add To Cart" button on every product card on the main page | MUST |
| FR-2 | Button must be pinned to the bottom of the product card, regardless of content height | MUST |
| FR-3 | Button click handler must be present but perform no action | MUST |
| FR-4 | Button must have no hover effect, no active/pressed visual change, and no cursor change (use default cursor) | MUST |

### 2.2 Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Button must follow Perficient brand guidelines | MUST |
| NFR-2 | Component must maintain existing accessibility standards | MUST |
| NFR-3 | Implementation must not affect existing product card functionality (image loading, error fallback, hover shadow) | MUST |
| NFR-4 | Button must be responsive across all breakpoints: mobile (<768px), tablet (768px-1024px), desktop (>1024px) | MUST |
| NFR-5 | Button touch target must be at least 44x44px on mobile for tap accessibility | SHOULD |

---

## 3. Technical Specification

### 3.1 Component Location
- **File:** `features/products/components/ProductCard.tsx`
- **Component:** `ProductCard`
- **Parent Component:** `ProductGrid` (renders cards in a CSS Grid: `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`)
- **Page:** `pages/index.tsx` (main page, uses infinite scroll via `useInfiniteScroll` hook)

### 3.2 UI/UX Design Specifications

#### 3.2.1 Button Placement
- **Position:** Pinned to the bottom of the product card, below the price
- **Width:** Full width of the card's content area (100% within the existing `p-4` padding — does NOT extend edge-to-edge past the card padding)
- **Vertical alignment:** The card's `<article>` must use `flex flex-col` layout so the button can use `mt-auto` to push itself to the bottom. This ensures buttons across cards in the same grid row are vertically aligned, even when product descriptions vary in length.
- **Spacing:** `mt-3` top margin to separate from price element

#### 3.2.2 Visual Design

| Property | Value | Notes |
|----------|-------|-------|
| **Background Color** | `#004d57` | Perficient teal (Tailwind class: `bg-perficient-teal`, defined in `tailwind.config.ts`) |
| **Text Color** | `#ffffff` (white) | Tailwind class: `text-white` |
| **Font Size** | `text-sm` (0.875rem / 14px at default root) | Matches product description and price font size |
| **Font Weight** | Regular/Normal (400) | Tailwind class: `font-normal` |
| **Font Family** | Inter | Inherited from Tailwind config (`fontFamily.sans`) |
| **Text Content** | "Add To Cart" | Exact casing — capital A, T, C. No CSS `text-transform` applied. |
| **Border Radius** | `rounded-none` (0px) | Matches card's sharp corners |
| **Padding** | `py-3` (0.75rem top and bottom) | Provides adequate height; combined with `text-sm`, total button height ~46px which meets the 44px minimum touch target |
| **Border** | None | Clean, flat design |
| **Box Shadow** | None | No elevation effect |
| **Cursor** | `cursor-default` | Default arrow cursor, not pointer — reinforces the non-functional nature in this phase |

#### 3.2.3 Interactive States

| State | Behavior |
|-------|----------|
| **Default** | Display with specs above |
| **Hover** | No visual change (no background color shift, no scale, no underline) |
| **Active/Click** | No visual change (no pressed state) |
| **Focus** | Default browser focus outline for accessibility (do not suppress with `outline-none`) |
| **Disabled** | Not applicable — button is always in the enabled state |

#### 3.2.4 WCAG Color Contrast Verification
- **White (#ffffff) on Perficient Teal (#004d57):** Contrast ratio is approximately **9.76:1**, which exceeds WCAG AAA requirements (7:1 for normal text, 4.5:1 for large text). Passes all levels.

### 3.3 Implementation Details

#### 3.3.1 Layout Refactor
The `<article>` element must be converted to a flex column layout to support bottom-pinning the button. This is a required structural change.

**Current `<article>` className:**
```
bg-white shadow-md hover:shadow-xl rounded-none p-4 transition-shadow duration-200
```

**Updated `<article>` className (add `flex flex-col`):**
```
bg-white shadow-md hover:shadow-xl rounded-none p-4 transition-shadow duration-200 flex flex-col
```

This change has no visual impact on the existing layout because the child elements already stack vertically. The only new behavior is that `mt-auto` on the button will push it to the bottom of the card.

#### 3.3.2 Component Structure (Updated)
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

**Key implementation notes:**
- `mt-auto` instead of `mt-3`: Uses auto margin to push the button to the bottom of the flex container. The visual gap between the price and button will vary by card, but will be at least the natural content flow distance. If a fixed minimum gap is desired, wrap the button in a `<div className="mt-auto pt-3">` instead.
- `cursor-default`: Overrides any browser default for buttons to ensure the cursor stays as an arrow.

#### 3.3.3 Accessibility Considerations
- Use semantic `<button>` element (not `<div>` with click handler)
- Include `type="button"` to prevent form submission behavior
- Add `aria-label` with product name for screen readers (e.g., "Add Wireless Headphones to cart")
- Maintain keyboard navigation support (inherent with `<button>`)
- Ensure focus state is visible — do NOT add `outline-none` or `focus:ring-0`
- Color contrast verified at 9.76:1 (WCAG AAA compliant)

#### 3.3.4 Actual Current ProductCard Structure
This is the **exact** current implementation. Developers should reference this, not a simplified version.

```tsx
import { useState } from 'react';
import Image from 'next/image';
import type { Product } from '@/features/products/types/product';
import { formatPrice } from '@/features/products/utils/formatPrice';

interface ProductCardProps {
  product: Product;
}

export default function ProductCard({ product }: ProductCardProps) {
  const [imgError, setImgError] = useState(false);

  return (
    <article className="bg-white shadow-md hover:shadow-xl rounded-none p-4 transition-shadow duration-200">
      <div className="aspect-square overflow-hidden relative mb-3">
        {imgError ? (
          <div className="bg-gray-200 w-full h-full flex items-center justify-center">
            <span className="text-gray-400 text-sm">No image</span>
          </div>
        ) : (
          <Image
            src={product.image}
            alt={product.name}
            width={400}
            height={400}
            className="object-cover w-full h-full"
            onError={() => setImgError(true)}
          />
        )}
      </div>
      <h2 className="font-bold text-base text-perficient-dark">{product.name}</h2>
      <p className="font-normal text-sm text-perficient-dark/70 mt-1">{product.description}</p>
      <p className="font-bold text-base text-perficient-dark mt-2">{formatPrice(product.price)}</p>
      {/* ADD BUTTON HERE */}
    </article>
  );
}
```

**Key details the implementation must preserve:**
- `useState` hook for `imgError` (image fallback behavior)
- Conditional rendering of Next.js `<Image>` vs. fallback `<div>`
- `onError` handler on `<Image>`
- All existing className values unchanged

---

## 4. Data & State Management

### 4.1 Component Props
No new props required. The button uses the existing `product` prop (specifically `product.name`) for the accessibility label.

### 4.2 State Management
No state changes required. No cart state, no button state (loading, disabled, etc.). The existing `imgError` state is unrelated and must not be affected.

### 4.3 Event Handling
```tsx
onClick={() => {}}  // No-op function (does nothing)
```

---

## 5. Error Handling

### 5.1 Error Scenarios
Since this is a UI-only implementation with no functionality:
- **No API calls:** No network errors possible
- **No state updates:** No state synchronization errors
- **No validation:** No user input validation needed

### 5.2 Edge Cases
- **Long product names:** Button label is fixed text ("Add To Cart"), not affected. However, the `aria-label` includes the product name — verify screen readers handle long names gracefully.
- **Missing product data:** Button still renders because it uses fixed text. The `aria-label` falls back to `Add undefined to cart` if `product.name` is missing — this is acceptable given the existing component makes no null guards on `product.name` elsewhere.
- **Rapid clicking:** No-op handler prevents any issues
- **Cards with varying description lengths:** Button is pinned to the bottom via `flex flex-col` + `mt-auto`, so buttons align across grid rows regardless of description length.
- **Image fallback state:** Button must render identically whether the product image loads or falls back to the "No image" placeholder.

---

## 6. Testing Plan

### 6.1 Testing Framework Prerequisites

**IMPORTANT:** The project currently has NO testing framework installed. Before any tests can be written, the following must be set up:

**Required packages (devDependencies):**
- `jest` — test runner
- `@testing-library/react` — React component testing utilities
- `@testing-library/jest-dom` — custom DOM matchers (e.g., `toBeInTheDocument()`)
- `jest-environment-jsdom` — browser-like environment for Jest
- `@types/jest` — TypeScript type definitions for Jest
- `ts-jest` or `@swc/jest` — TypeScript transform for Jest (or use Next.js built-in transform)

**Alternative:** Use Next.js recommended testing setup with Jest. See Next.js docs for `next/jest` configuration which handles module aliasing (`@/`), CSS/image mocking, and TypeScript transforms automatically.

**Required configuration files:**
- `jest.config.ts` (or `jest.config.js`)
- `jest.setup.ts` — to import `@testing-library/jest-dom`

**Required `package.json` script:**
```json
"test": "jest",
"test:watch": "jest --watch"
```

**Note:** This test framework setup should be completed as a prerequisite task before the button implementation begins.

### 6.2 Unit Tests
Create: `features/products/components/__tests__/ProductCard.test.tsx`

**Test Cases:**
1. Button renders with exact text content "Add To Cart"
2. Button has the expected CSS classes (`bg-perficient-teal`, `text-white`, `text-sm`, `font-normal`, `w-full`, `cursor-default`, `rounded-none`)
3. Button is the last child element within the `<article>` (verifies position)
4. Button click does not throw an error
5. Button has `aria-label` containing the product name (e.g., "Add Test Product to cart")
6. Button has `type="button"` attribute
7. Article element has `flex` and `flex-col` classes (verifies layout refactor)
8. Button renders correctly when image is in error fallback state
9. All existing ProductCard behavior is unaffected (product name, description, price, image rendering)

**Test Implementation Example:**
```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import ProductCard from '../ProductCard';

// Mock next/image since it requires Next.js context
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}));

describe('ProductCard - Add To Cart Button', () => {
  const mockProduct = {
    id: 1,
    name: 'Test Product',
    description: 'Test Description',
    price: 99.99,
    image: '/test-image.jpg',
  };

  it('renders Add To Cart button', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toBeInTheDocument();
  });

  it('button displays exact text "Add To Cart"', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveTextContent('Add To Cart');
  });

  it('button has correct styling classes', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveClass(
      'bg-perficient-teal',
      'text-white',
      'text-sm',
      'font-normal',
      'w-full',
      'cursor-default',
      'rounded-none'
    );
  });

  it('button has type="button"', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveAttribute('type', 'button');
  });

  it('button click does not throw error', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(() => fireEvent.click(button)).not.toThrow();
  });

  it('article uses flex column layout for button pinning', () => {
    render(<ProductCard product={mockProduct} />);
    const article = screen.getByRole('article');
    expect(article).toHaveClass('flex', 'flex-col');
  });

  it('does not break existing product card rendering', () => {
    render(<ProductCard product={mockProduct} />);
    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('Test Description')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
  });
});
```

### 6.3 Integration Tests
Not required for this phase (no integration with cart system).

### 6.4 Visual Regression Tests
Recommended but optional:
1. Capture screenshot of product card with button
2. Verify button spans full width at all breakpoints
3. Verify button color matches brand guidelines
4. Verify buttons align at the same vertical position across cards with different description lengths

### 6.5 Manual Testing Checklist

**Desktop (>1024px):**
- [ ] Button appears on all product cards
- [ ] Button is full width of card content area
- [ ] Button is pinned to the bottom of each card
- [ ] Buttons are vertically aligned across cards in the same row, even with different description lengths
- [ ] Button has correct Perficient teal color (#004d57)
- [ ] Text is white and reads "Add To Cart"
- [ ] Font size matches description/price (14px)
- [ ] Cursor stays as default arrow on hover (not pointer)
- [ ] No hover effect on mouse over
- [ ] No visual change on click
- [ ] Clicking button does nothing (no errors in console)
- [ ] Button is keyboard accessible (tab navigation works)
- [ ] Focus state is visible (browser default outline)
- [ ] Image fallback cards ("No image") display the button identically

**Tablet (768px - 1024px):**
- [ ] All desktop checks pass
- [ ] Button maintains full width responsively
- [ ] 2-column grid layout displays correctly with buttons

**Mobile (< 768px):**
- [ ] All desktop checks pass
- [ ] Button maintains full width responsively
- [ ] Button is easily tappable (adequate touch target size, minimum 44px height)
- [ ] 1-column grid layout displays correctly with buttons

**Accessibility:**
- [ ] Screen reader announces button correctly (e.g., "Add [Product Name] to cart")
- [ ] Keyboard navigation works (Tab to button, Enter/Space to activate)
- [ ] Focus indicator is visible
- [ ] Color contrast meets WCAG AA standards (white text on #004d57 — verified at 9.76:1)

---

## 7. Architecture & Design Decisions

### 7.1 Component Placement
**Decision:** Add button directly to existing ProductCard component  
**Rationale:** 
- Button is tightly coupled to product display
- No reusability needed elsewhere
- Keeps component structure simple
- Avoids unnecessary abstraction for no-op feature

### 7.2 Layout Refactor (flex flex-col)
**Decision:** Convert card `<article>` to flex column layout  
**Rationale:**
- Required to pin the button to the bottom of the card regardless of content height
- CSS Grid (`grid-cols-4`) makes all cards in a row equal height, but without flex column + `mt-auto`, buttons would float at different vertical positions based on content length
- Adding `flex flex-col` to the article has zero visual impact on existing elements since they already stack vertically
- This is the standard Tailwind/CSS approach for "sticky footer inside a card" patterns

### 7.3 Styling Approach
**Decision:** Use Tailwind utility classes  
**Rationale:**
- Consistent with existing codebase (ProductCard uses Tailwind)
- No need for custom CSS file
- Easy to maintain and modify
- Perficient colors already defined in tailwind.config.ts

### 7.4 Click Handler
**Decision:** Inline no-op arrow function `onClick={() => {}}`  
**Rationale:**
- Simplest implementation
- No need for separate handler function
- Clear intent (does nothing)
- Easy to replace with real functionality later
- No performance concern (React does not re-render due to a new arrow function reference here because nothing depends on this callback's identity)

### 7.5 Cursor Style
**Decision:** Use `cursor-default` instead of `cursor-pointer`  
**Rationale:**
- Since the button performs no action, a pointer cursor would set false user expectations
- Default cursor is consistent with the "no visual feedback" requirement
- When functionality is added in Phase 2, switch to `cursor-pointer`

### 7.6 Accessibility
**Decision:** Use semantic `<button>` with aria-label  
**Rationale:**
- Meets WCAG guidelines
- Proper keyboard navigation
- Screen reader compatible
- Future-proof (when functionality is added, semantics are correct)

---

## 8. Future Considerations

### 8.1 Phase 2 - Add Cart Functionality
When implementing actual cart functionality:
1. Replace no-op handler with cart state management
2. Change `cursor-default` to `cursor-pointer`
3. Add loading state during cart operations
4. Add visual feedback (success toast, icon change, etc.)
5. Add hover effects (darken background, etc.)
6. Add error handling for cart operations
7. Consider adding quantity selector
8. Update aria-live regions for cart updates

### 8.2 Design Enhancements (Not in Current Scope)
- Hover effects (darken background, scale, etc.)
- Click feedback (ripple effect, color change)
- Icon addition (cart icon next to text)
- Animation on add to cart
- Disabled state for out-of-stock items
- Transition from `cursor-default` to `cursor-pointer`

### 8.3 Performance Considerations
- Current implementation has no performance impact
- When adding functionality, consider:
  - Optimistic UI updates
  - Debouncing rapid clicks
  - Lazy loading cart state
  - Memoization if cart calculations are expensive

---

## 9. Implementation Steps

### 9.1 Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/add-to-cart-button
   ```

2. **Set Up Testing Framework (if not already done)**
   - Install testing dependencies:
     ```bash
     npm install --save-dev jest @testing-library/react @testing-library/jest-dom jest-environment-jsdom @types/jest
     ```
   - Create `jest.config.ts` using `next/jest` for proper Next.js integration
   - Create `jest.setup.ts` to import `@testing-library/jest-dom`
   - Add `"test": "jest"` to `package.json` scripts
   - Verify setup with a trivial test before proceeding

3. **Write Tests First (TDD)**
   - File: `features/products/components/__tests__/ProductCard.test.tsx`
   - Implement test cases from Section 6.2
   - Run tests and confirm they fail (red phase)

4. **Update ProductCard Component**
   - File: `features/products/components/ProductCard.tsx`
   - Add `flex flex-col` to the `<article>` className
   - Add button JSX after price paragraph, before closing `</article>`
   - Use specifications from Section 3.3.2
   - Run tests and confirm they pass (green phase)

5. **Manual Testing**
   - Run development server: `npm run dev`
   - Follow manual testing checklist (Section 6.5)
   - Test across different viewports (mobile, tablet, desktop)
   - Verify button alignment across cards with different content lengths

6. **Code Review Checklist**
   - [ ] Button renders on all product cards
   - [ ] Styling matches specifications exactly
   - [ ] Button is pinned to card bottom (flex layout working)
   - [ ] Buttons align across cards in the same grid row
   - [ ] No console errors or warnings
   - [ ] Tests pass (`npm test`)
   - [ ] Accessibility check passes
   - [ ] No impact on existing functionality (image loading, error fallback, hover shadow)
   - [ ] Cursor stays as default arrow on button hover

7. **Commit & Push**
   ```bash
   git add features/products/components/ProductCard.tsx
   git add features/products/components/__tests__/ProductCard.test.tsx
   git add jest.config.ts jest.setup.ts  # if test framework was set up in this branch
   git commit -m "feat: add non-functional 'Add To Cart' button to product cards"
   git push origin feature/add-to-cart-button
   ```

8. **Create Pull Request**
   - Title: "feat: Add 'Add To Cart' button to product cards"
   - Link this specification document
   - Include screenshots of before/after
   - Tag reviewers

---

## 10. Dependencies & Prerequisites

### 10.1 Technical Dependencies (Already Installed)
- **Next.js** 14.2.29
- **React** ^18
- **Tailwind CSS** ^3.3.0 (configured with Perficient brand colors)
- **TypeScript** ^5

### 10.2 Technical Dependencies (Must Be Installed)
- **Jest** — test runner (not currently in `package.json`)
- **@testing-library/react** — React component testing utilities
- **@testing-library/jest-dom** — custom DOM matchers
- **jest-environment-jsdom** — browser DOM simulation for Jest
- **@types/jest** — TypeScript types for Jest

### 10.3 Design Assets
- Perficient brand colors: Defined in `tailwind.config.ts` (specifically `perficient-teal: '#004d57'`)
- No additional assets required (no icons, no images)

### 10.4 Configuration Files to Create
- `jest.config.ts` — Jest configuration (recommend using `next/jest`)
- `jest.setup.ts` — Test setup file (import `@testing-library/jest-dom`)

---

## 11. Risk Assessment

### 11.1 Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Button doesn't align at card bottom across cards with varying content | Medium | Medium | Use `flex flex-col` + `mt-auto` layout pattern; test with products of different description lengths |
| Flex layout refactor breaks existing card appearance | Medium | Low | `flex flex-col` on a block of stacked elements produces identical visual output; verify with before/after screenshots |
| Button overlaps or misaligns content | Medium | Low | Test across viewports, follow existing spacing patterns |
| Color doesn't match brand guidelines | Low | Very Low | Use exact color from tailwind config (#004d57) |
| Breaks existing product card tests | Low | Very Low | No existing tests to break (test directory is empty) |
| Test framework setup introduces config issues | Medium | Medium | Use `next/jest` for automatic compatibility with Next.js module resolution and transforms |
| Accessibility issues | Medium | Low | Use semantic HTML, add aria-label, test with screen reader |
| User expects button to work | Low | Medium | Acceptable for this phase; cursor-default reduces affordance |

### 11.2 Rollback Plan
Since this is an additive change:
1. Revert commit (single commit, no migrations)
2. Or feature flag implementation if needed
3. No database migrations or data changes required

---

## 12. Acceptance Criteria

### 12.1 Definition of Done
- [ ] Testing framework is installed and configured
- [ ] Button appears on every product card on main page
- [ ] Button is pinned to the bottom of each card (flex layout)
- [ ] Buttons align vertically across cards in the same grid row
- [ ] Button spans full width of card content area
- [ ] Background color is Perficient teal (#004d57)
- [ ] Text color is white
- [ ] Text reads exactly "Add To Cart" (capital A, T, C — no CSS text-transform)
- [ ] Font size is 14px (text-sm)
- [ ] Font weight is regular (400)
- [ ] No hover effect
- [ ] Cursor stays as default arrow (not pointer)
- [ ] No visual change on click
- [ ] Button click does not throw errors
- [ ] Button is keyboard accessible
- [ ] Button has appropriate aria-label including product name
- [ ] Focus outline is visible (not suppressed)
- [ ] Image error fallback cards display button identically
- [ ] All existing functionality preserved (image loading, error fallback, hover shadow, product info)
- [ ] New tests added and passing
- [ ] Manual testing checklist completed
- [ ] Code reviewed and approved
- [ ] No console warnings or errors
- [ ] Works on Chrome, Firefox, Safari, Edge
- [ ] Responsive on mobile, tablet, desktop

---

## 13. Related Documentation

### 13.1 Referenced Files
- `features/products/components/ProductCard.tsx` — Component to modify
- `features/products/components/ProductGrid.tsx` — Parent component (renders `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4`)
- `features/products/types/product.ts` — Product type definition (id, name, description, price, image)
- `features/products/utils/formatPrice.ts` — Price formatting utility
- `features/products/hooks/useInfiniteScroll.ts` — Infinite scroll hook used by main page
- `tailwind.config.ts` — Brand color definitions and font configuration
- `pages/index.tsx` — Main page implementation
- `package.json` — Dependencies (test framework must be added here)

### 13.2 Design References
- Brand templates: `templates-example/1.png`, `2.png`, `3.png`
- Perficient Brand Center (referenced for color verification)

---

## 14. Contact & Questions

For questions or clarifications about this specification:
- Review this document thoroughly first
- Check existing ProductCard implementation
- Refer to Perficient brand guidelines for design questions
- Consult project tech lead for architectural decisions

---

**END OF SPECIFICATION**
