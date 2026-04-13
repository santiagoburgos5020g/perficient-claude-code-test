# QA Visual Tester — Skill Specification

## Overview

A user-invocable Claude Code skill that acts as an automated QA tester for this project. It starts the dev server, opens the browser using MCP chrome-devtools, discovers all routes from the app's router configuration, navigates every page, reads `.test.tsx` files for specific test cases, and performs end-user-like interactions to verify the UI is fully functional.

## Purpose

To simulate a real end-user testing the entire application — verifying that pages render correctly, interactive elements work (spinners, infinite scroll, forms, buttons), and the UI behaves properly across desktop, tablet, and mobile viewports.

## Trigger Conditions

- User-invoked only via `/qa-visual-tester`
- Not auto-invoked by Claude

## Workflow Steps

### Step 1 — Start the Dev Server

1. Run `npm run dev` in the project root
2. Detect the port the server starts on (do not hardcode a port)
3. Wait for the server to be ready before proceeding

### Step 2 — Open the Browser

1. Use MCP chrome-devtools to open the browser
2. Navigate to the detected localhost URL

### Step 3 — Discover All Routes

1. Read the app's router/directory structure (e.g., Next.js `app/` directory) to discover all available pages/routes
2. Build a list of all routes to visit

### Step 4 — Read `.test.tsx` Files

1. Find all `.test.tsx` files in the project
2. Parse them for specific test cases, expected behaviors, and interactions to verify
3. Map test files to their corresponding routes/components when possible

### Step 5 — Test Each Page Across All Viewports

For each discovered route, test in three viewports:

- **Desktop**: 1920x1080
- **Tablet**: 768x1024
- **Mobile**: 375x812

For each viewport on each page:

1. Navigate to the page
2. Wait for the page to fully load
3. Verify the page renders correctly (no blank screens, no broken layouts)
4. Check for visual elements: text, images, buttons, navigation
5. Perform end-user interactions found on the page

### Step 6 — Test Interactive Elements

For each interactive element found on a page:

- **Spinners/Loaders**: Verify the spinner appears during loading and disappears once content loads
- **Infinite Scroll**: Scroll down to trigger infinite scroll, verify new content loads
- **Form Submissions**: Fill out forms with test data and submit, verify the form behaves correctly
- **Buttons/Links**: Click buttons and links, verify they perform their expected action
- **Navigation**: Verify internal navigation works between pages
- **Any other interactive UI elements**: Test them as a real user would

### Step 7 — Run `.test.tsx` Specific Test Cases

Execute any specific test scenarios defined in `.test.tsx` files using the browser via chrome-devtools, verifying the expected outcomes.

### Step 8 — Handle Issues

When an issue is found:

1. Take a screenshot of the issue
2. Save the screenshot to: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
3. Log the issue details (page, viewport, description, screenshot filename) for the report

### Step 9 — Generate Report

1. Always generate a report at: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.html`
2. The report should include:
   - Date and time of the test run
   - Summary of all pages tested
   - All viewports checked per page
   - All interactions performed
   - Issues found (with references to screenshots)
   - Pass/fail status for each check
3. If the report file already exists, **update it** by appending the new run results (building a history of QA runs over time)
4. If **no issues** were found, delete the `{YYYY-MM-DD}` folder (since no screenshots or failure reports are needed)
   - Note: If the report already has history from previous runs with issues, do NOT delete — only delete if the current run's folder was freshly created and has no issues

### Step 10 — Stop the Dev Server

1. Stop the `npm run dev` process
2. Confirm the server has been terminated

## Rules & Constraints

- **Must use MCP chrome-devtools** for all browser interactions — do NOT use Playwright or any other browser automation tool
- All file operations must stay within the project directory
- Screenshots path: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/`
- Report path: `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.html`
- The report is always generated (even when all tests pass) to maintain a testing history
- The date folder is only deleted when there are zero issues AND no prior history in that folder
- Dev server must be stopped after testing completes, regardless of success or failure

## Inputs

- No user input required beyond invoking the skill
- The skill auto-discovers routes and test files

## Outputs

- **Screenshots**: Saved in `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/screenshots/` for any issues found
- **QA Report**: HTML file at `chrome-dev-tools/qa-ai/{YYYY-MM-DD}/qa-report.html` with full test summary
- **Console output**: Progress updates during testing (which page/viewport is being tested)

## Edge Cases

- **Dev server fails to start**: Report the error to the user and abort
- **Port detection fails**: Try common ports (3000, 3001, 5173) as fallback
- **Page fails to load**: Screenshot the error, log it, continue to next page
- **Interactive element not found**: Log as a warning, continue testing
- **Infinite scroll has no more content**: Verify "end of list" or similar indicator is shown
- **Form requires specific data**: Use reasonable test data (e.g., "Test User", "test@example.com")
- **Auth-protected routes**: Log that the route requires authentication, skip or note in report
- **Dev server crashes mid-test**: Attempt to restart, if fails report to user and save partial results

## Frontmatter Settings

- `name`: qa-visual-tester
- `description`: Opens browser and tests all pages like a QA tester using chrome-devtools — verifies rendering, interactions, spinners, infinite scroll, forms across desktop/tablet/mobile viewports
- `user-invocable`: true (default, can omit)
- `disable-model-invocation`: true (user-only)
