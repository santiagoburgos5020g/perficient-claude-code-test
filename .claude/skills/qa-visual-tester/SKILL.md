---
name: qa-visual-tester
description: Opens browser and QA-tests all pages using chrome-devtools — verifies rendering, spinners, infinite scroll, forms, navigation across desktop/tablet/mobile viewports
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Glob, Grep, Edit, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__click, mcp__chrome-devtools__fill, mcp__chrome-devtools__press_key, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__list_pages, mcp__chrome-devtools__close_page
---

# QA Visual Tester

Automated QA testing skill that behaves like a real end-user — starts the dev server, opens the browser via MCP chrome-devtools, navigates every page, and verifies rendering, interactions, and responsiveness across desktop, tablet, and mobile viewports.

## Time Tracking

Record timestamps at these moments to populate the Test History table:

| Marker | When to capture | Column |
|--------|----------------|--------|
| **Start Process Time** | The very first action (before starting dev server, reading files, etc.) | `Start Process Time` |
| **Start Testing Time** | Right before navigating to the first page for testing (after dev server is ready, routes discovered, test files read) | `Start Testing Time` |
| **End Testing Time** | Right after the last browser test completes (before cleanup, report generation, stopping server) | `End Testing Time` |
| **End Process Time** | The very last action (after report is written, server stopped, cleanup done) | `End Process Time` |

Derived columns:
- **Testing Time** = End Testing Time - Start Testing Time
- **Process Time** = End Process Time - Start Process Time

Use `date +%H:%M` (or equivalent) to capture each timestamp. All times in HH:MM format.

## Workflow Overview

1. **Record Start Process Time** ← capture timestamp now
2. Start dev server (`npm run dev`)
3. Connect to browser via chrome-devtools
4. Discover all routes from `pages/` directory
5. Read all `.test.tsx` files for expected behaviors
6. **Record Start Testing Time** ← capture timestamp now
7. Test every page across 3 viewports (desktop, tablet, mobile)
8. Test all interactive elements (spinners, infinite scroll, forms, buttons, navigation)
9. Verify behaviors defined in `.test.tsx` files
10. Verify API endpoints
11. **Record End Testing Time** ← capture timestamp now
12. Screenshot and log any issues found
13. Generate/update QA report
14. Close the browser and stop the dev server
15. Report results to the user
16. **Record End Process Time** ← capture timestamp now

---

## Step 1 — Start the Dev Server

1. Run `npm run dev` in the project root as a **background process**
2. Parse the server output to detect the port (do NOT hardcode a port)
3. Wait for the server to be ready (look for the "ready" message or poll the URL)
4. If the server fails to start within 30 seconds, report the error and **abort**

## Step 2 — Connect to Browser

1. Use `mcp__chrome-devtools__list_pages` to verify the browser connection is active
2. Use `mcp__chrome-devtools__navigate_page` to go to the detected localhost URL
3. Verify the page loads by taking a snapshot or screenshot
4. If the browser is not connected, tell the user to open Chrome with `--remote-debugging-port=9222` and retry

## Step 3 — Discover All Routes

1. Read the `pages/` directory to find all user-facing routes
2. **Exclude**: `_app.tsx`, `_document.tsx`, `_error.tsx`, and everything under `pages/api/`
3. **Skip dynamic routes** (e.g., `[id].tsx`) — note them in the report as requiring manual testing
4. Map files to routes:
   - `pages/index.tsx` -> `/`
   - `pages/orders.tsx` -> `/orders`
   - `pages/users.tsx` -> `/users`
5. Report discovered routes to the user before proceeding

## Step 4 — Read `.test.tsx` Files

1. Find all `.test.tsx` files using glob: `**/*.test.tsx`
2. Read each file and extract:
   - What component/page is being tested
   - Specific behaviors asserted (e.g., "renders loading spinner", "displays error message")
   - User interactions simulated (clicks, scrolls, form fills)
   - Expected visual outcomes
3. Map test files to routes/components:
   - `pages/index.test.tsx` -> `/`
   - `pages/orders.test.tsx` -> `/orders`
   - `pages/users.test.tsx` -> `/users`
   - `pages/_app.test.tsx` -> Global layout (all pages)
   - `features/products/components/*.test.tsx` -> Components on `/`
4. Build a checklist of behaviors to verify in the browser

## Step 5 — Test Each Page Across All Viewports

Test every route in three viewports, in this order:

| Viewport | Width | Height |
|----------|-------|--------|
| Desktop  | 1920  | 1080   |
| Tablet   | 768   | 1024   |
| Mobile   | 375   | 812    |

To resize the viewport, use `mcp__chrome-devtools__evaluate_script`:
```javascript
window.resizeTo(width, height);
```

**For each viewport on each page:**

1. Navigate using `mcp__chrome-devtools__navigate_page`
2. Wait for full page load
3. Take a snapshot with `mcp__chrome-devtools__take_snapshot` to inspect the DOM
4. **Rendering checks:**
   - Page is not blank (has meaningful DOM content)
   - No broken layouts (overlapping, overflowing elements)
   - Text is readable, not truncated
   - Images load (no broken placeholders)
   - Navigation/header is present
5. **Responsive checks:**
   - Content adapts to viewport width
   - No unexpected horizontal scrollbar on mobile/tablet
   - Grid layouts adjust column count appropriately
   - Touch targets are appropriately sized on mobile
6. Report progress: `"Testing [route] at [viewport]..."`

## Step 6 — Test Interactive Elements

### Spinners/Loaders
- Observe initial page load
- Use `mcp__chrome-devtools__take_snapshot` to detect spinner elements
- Verify spinner **appears** during data fetching
- Verify spinner **disappears** when content loads
- If spinner persists > 10 seconds, flag as an issue

### Infinite Scroll (Homepage `/`)
- After initial load, verify product cards are visible
- Scroll to bottom using `mcp__chrome-devtools__evaluate_script`:
  ```javascript
  window.scrollTo(0, document.body.scrollHeight);
  ```
- Wait for IntersectionObserver to trigger new content
- Verify new product cards appear (compare count before/after)
- Repeat scroll 2-3 times to verify continuous loading
- Verify loading indicator appears between loads
- When `hasMore` is false, verify scrolling stops triggering loads — this is expected, not an issue

### Form Submissions
- Identify forms on each page
- Use `mcp__chrome-devtools__fill` to enter test data:
  - Text: "Test User", "test@example.com"
  - Numbers: reasonable values
- Use `mcp__chrome-devtools__click` to submit
- Verify the response (success message, validation errors, etc.)

### Buttons and Links
- Identify all clickable elements via snapshots
- Use `mcp__chrome-devtools__click` to interact
- Verify expected action (navigation, state change, modal, etc.)
- For product cards: verify name, price, description, and image display

### Navigation
- Click nav links in header/sidebar
- Verify correct route navigation
- Verify back button works

### Error States
- If triggerable, simulate error conditions
- Verify error message displays
- Verify retry button appears and works
- Verify recovery after retry

## Step 7 — Verify `.test.tsx` Behaviors in Browser

1. Cross-reference test assertions from Step 4 with observations from Steps 5-6
2. For any test case NOT already covered, perform the specific interaction in the browser
3. Mark each behavior as: **VERIFIED**, **FAILED**, or **SKIPPED** (with reason)
4. Include this mapping in the report

## Step 8 — Verify API Endpoint

1. Use `mcp__chrome-devtools__evaluate_script` to fetch from `/api/products`:
   ```javascript
   fetch('/api/products?page=1&limit=5').then(r => r.json()).then(d => JSON.stringify(d));
   ```
2. Verify response includes products array and pagination metadata
3. Verify `pagination.hasMore` is correct
4. Test edge cases: invalid page, exceeding max limit
5. Log results in the report (no screenshots for API checks)

## Step 9 — Handle Issues and Screenshots

When an issue is found:

1. Take a screenshot with `mcp__chrome-devtools__take_screenshot`
2. Save to: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
3. Name descriptively: `{route}-{viewport}-{issue-slug}.png`
   - Examples: `home-mobile-spinner-stuck.png`, `orders-desktop-blank-page.png`
4. Log the issue:
   - **Page/route**
   - **Viewport**
   - **Description**
   - **Expected vs. actual behavior**
   - **Screenshot filename**
   - **Severity**: Critical (page broken/blank), Major (feature not working), Minor (visual glitch), Info (observation)

Also check the browser console for JS errors using `mcp__chrome-devtools__evaluate_script` — log any uncaught errors as issues even if the page appears to render.

## Step 10 — Generate QA Report

**Always** generate a report at: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.html`

The report is an HTML file. Use `chrome-dev-tools/qa-ai/2026-04-11/qa-report.html` as the reference template for structure and styling. When generating or updating the report:

1. **Read the existing `qa-report.html`** to get the current HTML structure, styles, and data
2. **Update all sections** with the new run's data (Run Info, Summary, Pages Tested, .test.tsx Coverage, API Endpoint, Interactive Elements, Issues Found)
3. **Add a new row** to the Test Run History `<tbody>` at the top (most recent first)
4. **Increment the Run number** based on existing rows in the history table

The Test Run History table uses this column structure with grouped headers:

| Group | Column | Format |
|-------|--------|--------|
| (none) | Run | Run {n} |
| Process | Start Date Time | YYYY-MM-DD HH:MM |
| Process | End Date Time | YYYY-MM-DD HH:MM |
| Testing | Start Date Time | YYYY-MM-DD HH:MM |
| Testing | End Date Time | YYYY-MM-DD HH:MM |
| Duration | Testing Time | {Xm Ys} |
| Duration | Process Time | {Xm Ys} |
| Result | Status | PASS / FAIL badge |
| Result | Issues | count |

Use the CSS classes from the template: `td-process`, `td-testing`, `td-dur`, `td-center`, `badge-pass`/`badge-fail`, `issues-zero`/`issues-nonzero`, `empty` (for `--` values).

**Report update rules:**
- If the report already exists for today, **append** the new run (incrementing the Run number) to the "Test History" table and update the latest results in all sections above
- If **no issues** found in the current run, **delete the entire `screenshots/` folder** (including any screenshots from prior runs)
- If **no issues** found AND the date folder has no other files besides the report, **delete** the entire `{YYYY-MM-DD}` folder
- If issues are found, keep screenshots and reference them in the "Issues Found" section as normal

## Step 11 — Close Browser and Stop the Dev Server

1. Close all browser pages opened during testing using `mcp__chrome-devtools__close_page`
2. Stop the `npm run dev` background process
3. Verify the port is freed
4. If the process won't stop, force-kill it and warn the user
5. **This step MUST execute regardless of test success or failure**

## Step 12 — Report Results to User

Summarize in the conversation:
- Total pages tested and viewports checked
- Number of issues found (grouped by severity)
- Location of the report file and screenshots (if any)
- If all passed, confirm everything looks good
- If issues found, highlight the most critical ones and suggest fixes

---

## Critical Rules

- **MUST use MCP chrome-devtools exclusively** — NEVER use Playwright, Puppeteer, Selenium, or any other browser automation tool
- All file operations must stay within the project directory
- Screenshots: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
- Report: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.html`
- Always generate the report (even when all tests pass)
- Always close the browser and stop the dev server when done (even on failure)
- Report progress to the user as testing proceeds — do not run silently
- Timeout: if a page takes > 30 seconds to load, flag as issue and move on
- Use descriptive screenshot filenames: `{route}-{viewport}-{issue-slug}.png`

## Edge Cases

- **Dev server fails to start**: Report error details and abort
- **Port detection fails**: Try common ports (3000, 3001, 5173) as fallback
- **Browser not connected**: Tell user to launch Chrome with `--remote-debugging-port=9222`
- **Page blank**: Screenshot, check console for JS errors, log as Critical
- **Spinner stuck**: Flag after 10 seconds, screenshot, log as Major
- **Auth-protected routes**: Screenshot redirect, mark as Skipped in report
- **Dynamic routes** (`[id].tsx`): Skip, note in report as needing manual test
- **Dev server crashes mid-test**: Restart once; if fails again, save partial report and notify user
- **Console JS errors**: Log as issues even if page appears to render correctly
