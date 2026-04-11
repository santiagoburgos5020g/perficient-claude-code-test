# QA Visual Tester — Skill Specification (Opus 4.6 Reviewed)

## Overview

A user-invocable Claude Code skill that acts as an automated QA tester for this Next.js 14 (Pages Router) e-commerce project. It starts the dev server, opens the browser using MCP chrome-devtools, discovers all routes from the `pages/` directory, navigates every page, reads `.test.tsx` files for specific test scenarios, and performs end-user-like interactions to verify the UI is fully functional across desktop, tablet, and mobile viewports.

## Purpose

To simulate a real end-user testing the entire application — verifying that pages render correctly, interactive elements work (spinners, infinite scroll, forms, buttons, navigation), and the UI behaves properly across all breakpoints. This replaces manual QA by automating the visual and functional verification loop.

## Trigger Conditions

- **User-invoked only** via `/qa-visual-tester`
- Claude must NOT auto-invoke this skill
- No arguments required — the skill is fully autonomous once triggered

## Project Context

This skill is tailored for the current project:

- **Framework**: Next.js 14.2.29 with Pages Router
- **Routing**: File-based via `pages/` directory
- **Known user-facing routes**: `/` (product listing with infinite scroll), `/orders`, `/users`
- **API routes**: `/api/products` (paginated product endpoint)
- **Key interactive features**: Infinite scroll (IntersectionObserver-based), loading spinners, error states with retry, product cards, navigation links
- **Styling**: Tailwind CSS with Perficient brand tokens (`perficient-teal`, `perficient-dark`, `rounded-none`, `cursor-default`)
- **Database**: Prisma ORM + SQLite

## Available MCP Chrome-DevTools Tools

The skill must exclusively use these MCP chrome-devtools tools for all browser interactions:

| Tool | Purpose |
|---|---|
| `mcp__chrome-devtools__navigate_page` | Navigate to a URL |
| `mcp__chrome-devtools__take_screenshot` | Capture screenshots (for issues and verification) |
| `mcp__chrome-devtools__take_snapshot` | Capture page DOM state |
| `mcp__chrome-devtools__click` | Click on elements |
| `mcp__chrome-devtools__fill` | Fill form/input fields |
| `mcp__chrome-devtools__press_key` | Simulate keyboard input |
| `mcp__chrome-devtools__evaluate_script` | Execute JavaScript in the page context |
| `mcp__chrome-devtools__list_pages` | List open browser pages/tabs |

**CRITICAL**: Do NOT use Playwright, Puppeteer, Selenium, or any other browser automation tool. Only MCP chrome-devtools.

## Workflow Steps

### Step 1 — Start the Dev Server

1. Run `npm run dev` in the project root as a background process
2. Parse the server output to detect the port it starts on (do NOT hardcode a port)
3. Wait for the server to be ready by checking for the "ready" message or by polling the URL
4. If the server fails to start within 30 seconds, report the error to the user and abort

### Step 2 — Open the Browser and Verify Connection

1. Use `mcp__chrome-devtools__list_pages` to verify the browser connection is active
2. Use `mcp__chrome-devtools__navigate_page` to navigate to the detected localhost URL (e.g., `http://localhost:3000`)
3. Verify the page loads successfully by taking a snapshot or screenshot
4. If the browser is not connected, instruct the user to open Chrome with remote debugging enabled and retry

### Step 3 — Discover All Routes

1. Read the `pages/` directory structure to discover all user-facing routes
2. Exclude non-page files: `_app.tsx`, `_document.tsx`, `_error.tsx`, and files under `pages/api/`
3. Map file paths to routes:
   - `pages/index.tsx` -> `/`
   - `pages/orders.tsx` -> `/orders`
   - `pages/users.tsx` -> `/users`
   - `pages/[slug].tsx` -> skip dynamic routes or note them for manual testing
4. Build an ordered list of all routes to visit
5. Report the discovered routes to the user before proceeding

### Step 4 — Read and Parse `.test.tsx` Files

1. Find all `.test.tsx` files in the project using glob pattern `**/*.test.tsx`
2. Read each test file and extract:
   - Component/page being tested
   - Specific behaviors being asserted (e.g., "renders loading spinner", "displays error message", "loads more products on scroll")
   - User interactions being simulated (clicks, scrolls, form fills)
   - Expected visual outcomes (text content, element visibility, CSS classes)
3. Map test files to their corresponding routes/components:
   - `pages/index.test.tsx` -> `/`
   - `pages/orders.test.tsx` -> `/orders`
   - `pages/users.test.tsx` -> `/users`
   - `pages/_app.test.tsx` -> Global layout (applies to all pages)
   - `features/products/components/*.test.tsx` -> Components visible on `/`
4. Build a checklist of behaviors to verify in the browser based on test assertions

### Step 5 — Test Each Page Across All Viewports

For each discovered route, test in three viewports (in this order):

1. **Desktop**: 1920x1080
2. **Tablet**: 768x1024
3. **Mobile**: 375x812

To change viewport size, use `mcp__chrome-devtools__evaluate_script` to run:
```javascript
// Set viewport dimensions
window.resizeTo(width, height);
```
Or instruct the user if viewport resizing requires DevTools Protocol commands.

**For each viewport on each page:**

1. Navigate to the page using `mcp__chrome-devtools__navigate_page`
2. Wait for the page to fully load (check for network idle or specific content)
3. Take a snapshot using `mcp__chrome-devtools__take_snapshot` to inspect the DOM
4. **Rendering checks**:
   - Verify the page is not blank (has meaningful content in the DOM)
   - Verify no broken layouts (elements overlapping, overflowing viewport)
   - Verify text is readable and not truncated unexpectedly
   - Verify images load (no broken image placeholders)
   - Verify navigation/header is present and functional
5. **Responsive checks**:
   - Verify content adapts to the viewport width
   - Verify no horizontal scrollbar on mobile/tablet (unless intended)
   - Verify touch targets are appropriately sized on mobile
   - Verify grid layouts adjust (e.g., product grid columns change)
6. Report progress to the user: "Testing [route] at [viewport]..."

### Step 6 — Test Interactive Elements

For each page, identify and test all interactive elements:

#### Spinners/Loaders
- Navigate to the page and observe the initial load
- Use `mcp__chrome-devtools__take_snapshot` to check for spinner/loading elements
- Verify the spinner appears during data fetching
- Wait and verify the spinner disappears once content loads
- If spinner persists for more than 10 seconds, flag as an issue

#### Infinite Scroll (Homepage `/`)
- After initial content loads, verify product cards are visible
- Use `mcp__chrome-devtools__evaluate_script` to scroll to the bottom of the page:
  ```javascript
  window.scrollTo(0, document.body.scrollHeight);
  ```
- Wait for the IntersectionObserver to trigger and new content to load
- Verify new product cards appear (compare product count before and after scroll)
- Repeat scroll 2-3 times to verify continuous loading
- Verify the loading indicator appears between scrolls
- If `hasMore` is false, verify scrolling stops loading new content

#### Form Submissions
- Identify any forms on the page
- Use `mcp__chrome-devtools__fill` to enter test data:
  - Text fields: "Test User", "test@example.com", etc.
  - Number fields: reasonable values
- Use `mcp__chrome-devtools__click` to submit
- Verify form response (success message, validation errors, etc.)

#### Buttons and Links
- Identify all clickable elements using snapshots
- Use `mcp__chrome-devtools__click` to interact with each button
- Verify the expected action occurs (navigation, state change, modal, etc.)
- For product cards: verify they display name, price, description, and image

#### Navigation
- Click navigation links in the header/sidebar
- Verify each link navigates to the correct route
- Use `mcp__chrome-devtools__navigate_page` to verify the URL changed
- Verify the back button works (navigate back and verify previous page loads)

#### Error States
- If testable, simulate an error condition (e.g., disconnect network via evaluate_script)
- Verify error message displays correctly
- Verify retry button appears and functions
- Verify recovery after retry

### Step 7 — Run `.test.tsx` Specific Verifications

For each behavior extracted from `.test.tsx` files in Step 4, verify it in the live browser:

1. Cross-reference the test assertions with what was observed during Steps 5-6
2. For any test case NOT already covered, perform the specific interaction:
   - If a test checks "renders product name", verify product names are visible
   - If a test checks "displays loading spinner", verify spinner behavior
   - If a test checks "handles error state", attempt to trigger and verify error UI
3. Mark each `.test.tsx` behavior as: VERIFIED, FAILED, or SKIPPED (with reason)
4. Include this mapping in the final report

### Step 8 — Verify API Endpoint

1. Use `mcp__chrome-devtools__evaluate_script` to make a fetch request to `/api/products`:
   ```javascript
   fetch('/api/products?page=1&limit=5').then(r => r.json()).then(console.log);
   ```
2. Verify the response structure includes products array and pagination metadata
3. Verify `pagination.hasMore` correctly reflects whether more pages exist
4. Test edge cases: invalid page numbers, exceeding max limit
5. This is a supporting check — log results but do not screenshot API responses

### Step 9 — Handle Issues and Take Screenshots

When any issue is found during testing:

1. Immediately take a screenshot using `mcp__chrome-devtools__take_screenshot`
2. Save the screenshot to: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
3. Name screenshots descriptively: `{route}-{viewport}-{issue-slug}.png`
   - Example: `home-mobile-spinner-stuck.png`
   - Example: `orders-desktop-blank-page.png`
4. Log the issue with:
   - Page/route where it occurred
   - Viewport size
   - Description of the issue
   - Expected vs. actual behavior
   - Screenshot filename
   - Severity: **Critical** (page broken/blank), **Major** (feature not working), **Minor** (visual glitch), **Info** (observation)

### Step 10 — Generate QA Report

1. **Always** generate a report at: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.md`
2. The report must follow this structure:

```markdown
# QA Visual Test Report

## Run Info
- **Date**: {YYYY-MM-DD}
- **Time**: {HH:MM:SS}
- **Dev Server Port**: {port}
- **Total Pages Tested**: {count}
- **Total Viewports**: 3 (Desktop 1920x1080, Tablet 768x1024, Mobile 375x812)

## Summary
- **Total Checks**: {number}
- **Passed**: {number}
- **Failed**: {number}
- **Warnings**: {number}
- **Overall Status**: PASS / FAIL

## Pages Tested

### / (Homepage)
| Check | Desktop | Tablet | Mobile |
|-------|---------|--------|--------|
| Page renders | PASS/FAIL | PASS/FAIL | PASS/FAIL |
| Loading spinner | PASS/FAIL | PASS/FAIL | PASS/FAIL |
| Infinite scroll | PASS/FAIL | PASS/FAIL | PASS/FAIL |
| Product cards display | PASS/FAIL | PASS/FAIL | PASS/FAIL |
| Navigation works | PASS/FAIL | PASS/FAIL | PASS/FAIL |
| Responsive layout | N/A | PASS/FAIL | PASS/FAIL |

### /orders
| Check | Desktop | Tablet | Mobile |
|-------|---------|--------|--------|
| ... | ... | ... | ... |

### /users
| Check | Desktop | Tablet | Mobile |
|-------|---------|--------|--------|
| ... | ... | ... | ... |

## .test.tsx Coverage
| Test File | Behavior | Status |
|-----------|----------|--------|
| pages/index.test.tsx | renders loading spinner | VERIFIED |
| pages/index.test.tsx | displays products | VERIFIED |
| ... | ... | ... |

## Issues Found
### Issue 1: {title}
- **Page**: {route}
- **Viewport**: {size}
- **Severity**: Critical/Major/Minor/Info
- **Description**: {what happened}
- **Expected**: {what should have happened}
- **Screenshot**: `screenshots/{filename}.png`

## Test History
| Date | Time | Status | Issues |
|------|------|--------|--------|
| {date} | {time} | PASS/FAIL | {count} |
```

3. If the report file **already exists** for today's date, **append** the new run to the "Test History" table and update the latest results above it (preserving prior run data)
4. If **no issues** were found AND the date folder was freshly created (no prior runs with issues), delete the entire `{YYYY-MM-DD}` folder
5. If no issues were found BUT prior runs had issues (screenshots exist), keep the folder and update the report showing the latest run passed

### Step 11 — Stop the Dev Server

1. Stop the `npm run dev` background process
2. Verify the process has been terminated (check that the port is freed)
3. If the process fails to stop, force-kill it and warn the user
4. **This step must execute regardless of whether tests passed or failed** — wrap the entire test workflow in a try/finally pattern

### Step 12 — Report Results to User

1. Summarize the test results in the conversation:
   - Total pages tested, viewports checked
   - Number of issues found (by severity)
   - Location of the report file
   - Location of screenshots (if any)
2. If all tests passed, confirm everything looks good
3. If issues were found, highlight the most critical ones and suggest fixes

## Rules & Constraints

- **MUST use MCP chrome-devtools exclusively** for all browser interactions — NEVER use Playwright, Puppeteer, Selenium, or any other browser automation
- All file operations must stay within the project directory (per project rule in `.claude/rules/folder-restriction.md`)
- Screenshots path: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
- Report path: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.md`
- The report is always generated (even when all tests pass) to maintain testing history
- The date folder is only deleted when there are zero issues AND no prior history in that folder
- Dev server must be stopped after testing completes, regardless of success or failure
- Use descriptive screenshot filenames that include route, viewport, and issue slug
- Report progress to the user as each page/viewport is tested (do not run silently)
- Issue severity levels: Critical > Major > Minor > Info
- Timeout: If any single page takes more than 30 seconds to load, flag as an issue and move on

## Inputs

- No user input required beyond invoking the skill with `/qa-visual-tester`
- The skill auto-discovers routes from `pages/` directory and test files via glob

## Outputs

- **Screenshots**: Saved in `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/` for any issues found
- **QA Report**: Markdown file at `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.md` with full test summary and history
- **Console output**: Real-time progress updates during testing (which page/viewport is being tested, pass/fail per check)

## Edge Cases

- **Dev server fails to start**: Report the error with details (missing dependencies, port in use, etc.) and abort gracefully
- **Port detection fails**: Parse server output for port; if not found, try common ports (3000, 3001, 5173) as fallback
- **Browser not connected**: Instruct the user to open Chrome with `--remote-debugging-port=9222` flag and retry
- **Page fails to load**: Take a screenshot of the error state, log as Critical issue, continue to next page
- **Page loads but is blank**: Take a screenshot, check console for JS errors via `evaluate_script`, log as Critical
- **Interactive element not found**: Log as a warning (Minor), continue testing — it may be viewport-specific
- **Infinite scroll has no more content**: Verify "end of list" indicator or that `hasMore` returns false — this is expected behavior, not an issue
- **Form requires specific data**: Use reasonable test data (e.g., "Test User", "test@example.com", "123 Test St")
- **Auth-protected routes**: If a page redirects to login, log that the route requires authentication, take a screenshot, mark as Skipped with reason
- **Dev server crashes mid-test**: Attempt to restart once; if it fails again, save partial results to the report and notify the user
- **Network errors during testing**: Distinguish between app errors and test infrastructure errors; only flag app errors as issues
- **Dynamic routes** (e.g., `[id].tsx`): Skip or note in report that they require specific parameters; do not attempt to guess IDs
- **Console errors/warnings**: Check browser console for JavaScript errors using `evaluate_script` — log any uncaught errors as issues even if the page appears to render correctly

## Frontmatter Settings

- `name`: qa-visual-tester
- `description`: Opens browser and QA-tests all pages using chrome-devtools — verifies rendering, spinners, infinite scroll, forms, navigation across desktop/tablet/mobile viewports
- `user-invocable`: true (default — omit from frontmatter)
- `disable-model-invocation`: true (user-only — include in frontmatter)
- `allowed-tools`: Bash, Read, Write, Glob, Grep, Edit, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__click, mcp__chrome-devtools__fill, mcp__chrome-devtools__press_key, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__list_pages
