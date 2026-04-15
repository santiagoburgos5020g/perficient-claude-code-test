# Backend Best Practices — Skill Specification

## Overview

A background reference skill that agents automatically consult during code creation, modification, and review. It enforces backend best practices strictly in this project. The skill applies rules relevant to what currently exists in the codebase and gradually applies more as the backend grows.

## Project Context

- **Framework:** Next.js 14 (Pages Router) with API Routes (`pages/api/`)
- **Language:** TypeScript
- **Database:** SQLite via Prisma ORM
- **Validation:** Zod (enforced)
- **Testing:** Jest + React Testing Library, Playwright (e2e)
- **Current state:** Early-stage backend — single `GET /api/products` endpoint, no auth, no caching, no logging/monitoring, no Docker/CI-CD

## Trigger Conditions

Claude should automatically consult this skill when:

- Creating or modifying files in `pages/api/`
- Creating or modifying backend utility/service files
- Working with Prisma schema, migrations, or database queries
- Creating or modifying middleware
- Reviewing backend code

## Enforcement Mode

**Strict** — These are hard rules, not suggestions. Claude must follow all applicable practices and flag violations during code review.

## Core Rules & Practices

### 1. API Response Envelope

All API routes MUST return responses using the standard JSON envelope structure:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "meta": { "page": 1, "limit": 30, "total": 100 }
}
```

- `success`: boolean indicating whether the request succeeded
- `data`: the response payload (object, array, or null on error)
- `error`: null on success, error message/object on failure
- `meta`: optional metadata (pagination info, etc.)

### 2. RESTful API Design

- Use standard HTTP methods: GET (read), POST (create), PUT (update), DELETE (remove)
- Use correct status codes: 200 (OK), 201 (Created), 400 (Bad Request), 404 (Not Found), 405 (Method Not Allowed), 500 (Internal Server Error)
- Keep APIs "chunky" not "chatty" — reduce network round trips by combining related data in single responses
- Every API route MUST explicitly handle only the methods it supports and return 405 for all unsupported methods

### 3. Pagination Standard

All paginated endpoints MUST use the following pattern:

- Query parameters: `page` (default 1) and `limit` (default 30, max 100)
- Response includes `hasMore` flag in meta
- Example meta: `{ "page": 1, "limit": 30, "total": 1000, "hasMore": true }`

### 4. Input Validation with Zod

- **Zod is required** for all input validation in API routes
- All user input (query params, request body, path params) MUST be validated before processing
- Zod schemas should be used to infer TypeScript types (single source of truth)
- Validation errors must return 400 with the standard error envelope

### 5. Centralized Error Handling

- All API routes MUST use a centralized error handler/wrapper utility
- No individual try-catch blocks scattered in route handlers — use a shared wrapper
- The error handler must return the standard envelope with proper status codes
- Unhandled errors must return 500 with a generic error message (no internal details leaked)

### 6. Security (Contextual Enforcement)

Enforce based on what currently exists in the codebase:

- **Always enforce:**
  - Never trust user input — validate all data with Zod
  - Use parameterized queries (Prisma handles this, but enforce when raw SQL is used)
  - Never hardcode sensitive values — use `.env` files
  - Separate `.env` files for different environments (dev, production)

- **Enforce when auth is added:**
  - Use OAuth or JWT for authentication
  - Implement rate limiting
  - Lock accounts after failed login attempts

- **Enforce when applicable:**
  - Prevent SQL injection (parameterized queries)
  - Validate and sanitize all input at system boundaries

### 7. Database Optimization (Prisma)

- Use proper indexing on frequently queried fields
- Flag potential N+1 query problems
- Enforce use of `include`/`select` for efficient relation loading when relationships exist
- Avoid fetching unnecessary fields — use `select` to pick only needed columns
- Understand the underlying SQL — don't blindly rely on ORM abstractions

### 8. Logging (When Added)

When logging is implemented in the project:

- Use structured JSON logging
- Enforce log levels: info, warn, error
- Use asynchronous logging to minimize overhead

### 9. Caching (When Added)

When caching is implemented:

- Implement caching strategies (e.g., Redis) to reduce database load
- Use asynchronous processing for long-running tasks to prevent blocking API responses

### 10. Testing API Routes

Every API route MUST have corresponding tests covering:

- **Happy path** — successful request with valid input
- **Error cases** — invalid input, missing data, server errors
- **Input validation** — ensure Zod validation rejects invalid input correctly
- **HTTP method enforcement** — unsupported methods return 405

### 11. Naming Conventions

- **File names:** kebab-case for API route files (e.g., `user-profiles.ts`)
- **Functions:** camelCase for handlers (e.g., `getProducts`, `createOrder`)
- **Types/Interfaces:** PascalCase (e.g., `ApiResponse`, `ProductInput`, `PaginationMeta`)

### 12. Environment Variables & Configuration

- Sensitive values (database URLs, API keys, secrets) MUST never be hardcoded
- Always load from `.env` files
- Maintain separate `.env` files per environment (`.env.development`, `.env.production`)
- Use `NEXT_PUBLIC_` prefix only for values that need client-side access

## Edge Cases & Guardrails

- If a practice is not yet relevant (e.g., rate limiting when there's no auth), the skill should not enforce it but should note it as a future consideration when the feature is added
- The skill should flag violations during code review, not silently ignore them
- When creating new API routes, all applicable rules must be applied from the start
- When modifying existing routes, flag existing violations and require fixes

## Outputs

- Compliant backend code that follows all applicable practices
- Flagged violations with explanations during code review
- Suggestions for future improvements when new features are added that trigger additional rules
