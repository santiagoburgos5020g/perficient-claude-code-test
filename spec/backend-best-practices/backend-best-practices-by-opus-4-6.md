# Backend Best Practices Reference — Skill Specification (Opus 4.6 Reviewed)

## Overview

A strict background reference skill that agents automatically consult during code creation, modification, and review. It enforces backend best practices as hard rules in this project. The skill applies rules relevant to what currently exists in the codebase and progressively enforces additional rules as the backend grows (e.g., auth, caching, logging).

This skill is **not user-invocable**. It is automatically loaded by Claude and its agents whenever backend-related coding tasks are performed.

## Purpose

- Serve as the **single source of truth** for backend best practices across all agents
- Guide agents to follow correct backend patterns during code creation and modification
- Enable agents to **audit backend code** — identify violations, missing practices, and improvement opportunities
- Ensure consistency across all API routes, database operations, middleware, and backend services
- Progressively enforce more rules as the backend grows — do not enforce practices for features that do not yet exist

## Project Context

- **Framework:** Next.js 14 (Pages Router) with API Routes (`pages/api/`)
- **Language:** TypeScript 5
- **Database:** SQLite via Prisma ORM 5.x
- **Validation:** Zod (required — no alternatives)
- **Testing:** Jest 29 + React Testing Library, Playwright (e2e)
- **Current state:** Early-stage backend with a single `GET /api/products` endpoint, no authentication, no caching, no logging/monitoring, no containerization

## Trigger Conditions

- **Auto-invoked by model**: Yes
- **User-invocable**: No
- Agents load this skill whenever they:
  - Create or modify files in `pages/api/`
  - Create or modify backend utility, service, or middleware files
  - Work with Prisma schema (`prisma/schema.prisma`), migrations, or database queries
  - Create or modify middleware or error handling utilities
  - Review or audit backend code written by the user

## Enforcement Mode

**Strict** — All applicable rules are hard requirements, not suggestions. Agents must:
- Follow all rules when creating or modifying backend code
- Flag violations during code review with the specific rule reference
- Require fixes for violations when modifying existing routes

## Agent Decision Process

When agents encounter a backend task, they follow this process:

1. **Identify the scope** — Is this an API route, database operation, middleware, or backend utility?
2. **Check applicability** — Which rules apply given the current codebase state? (see Progressive Enforcement)
3. **Apply rules** — Follow all applicable rules when creating/modifying code
4. **Audit** — When reviewing code, flag violations with severity and the specific rule number

### Severity Levels for Audits

When reviewing backend code, agents categorize findings as:

- **Critical** — A rule is clearly violated and causes security, correctness, or maintainability problems. Must be fixed.
- **Recommended** — A rule is violated but the current approach is functional. Should be fixed.
- **Future** — A rule will apply when a relevant feature is added (e.g., rate limiting when auth is introduced). Note for awareness, do not enforce.

### Progressive Enforcement

Rules are grouped into tiers based on when they apply:

| Tier | When It Applies | Example Rules |
|---|---|---|
| **Always** | Every backend task, regardless of project state | Response envelope, REST conventions, input validation, error handling, naming, env vars, testing, pagination, database optimization |
| **When Auth Exists** | Authentication/authorization code is present in the codebase | JWT/OAuth patterns, rate limiting, account lockout |
| **When Logging Exists** | A logging library or logging utility is present | Structured JSON logging, log levels, async logging |
| **When Caching Exists** | A caching layer (Redis, in-memory, etc.) is present | Cache strategies, invalidation, async processing |
| **When CI/CD Exists** | CI/CD pipeline configuration is present | Automated testing in pipeline, deployment consistency |
| **When Containerized** | Docker or container configuration is present | Dockerfile best practices, environment parity |

---

## CORE RULES (Always Enforced)

### Rule 1 — Standard API Response Envelope

All API routes MUST return responses using this exact JSON envelope structure:

**Success response:**
```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "meta": { "page": 1, "limit": 30, "total": 100 }
}
```

**Error response:**
```json
{
  "success": false,
  "data": null,
  "error": "Description of what went wrong",
  "meta": null
}
```

**Field definitions:**
- `success` (boolean, required): `true` if the request succeeded, `false` otherwise
- `data` (object | array | null, required): The response payload on success; `null` on error
- `error` (string | object | null, required): `null` on success; error description on failure
- `meta` (object | null, required): Optional metadata (pagination, counts, etc.); `null` when not applicable

**Rules:**
- Every API route must use this envelope — no exceptions
- Never return raw data without the envelope
- Never mix envelope fields (e.g., `success: true` with a non-null `error`)
- The `meta` field must be present (even if `null`) for consistent parsing

**Code Smells That Signal a Violation:**
- API responses that return raw arrays or objects without the envelope
- Inconsistent response shapes across different routes
- Error responses that don't include the `success: false` field
- Pagination data mixed into the `data` field instead of `meta`

---

### Rule 2 — RESTful API Design

**HTTP Methods:**
- `GET` — Read/retrieve resources (must be idempotent, no side effects)
- `POST` — Create new resources
- `PUT` — Update/replace existing resources
- `PATCH` — Partial update of existing resources
- `DELETE` — Remove resources

**Status Codes:**

| Code | Meaning | When to Use |
|---|---|---|
| 200 | OK | Successful GET, PUT, PATCH, DELETE |
| 201 | Created | Successful POST that creates a resource |
| 204 | No Content | Successful DELETE with no response body |
| 400 | Bad Request | Invalid input, validation errors |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Authenticated but insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 405 | Method Not Allowed | HTTP method not supported by the endpoint |
| 409 | Conflict | Resource conflict (e.g., duplicate creation) |
| 422 | Unprocessable Entity | Validation passed but business logic rejects the request |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unhandled server error |

**Rules:**
- Every API route MUST explicitly declare which HTTP methods it supports
- Every API route MUST return 405 (Method Not Allowed) for unsupported methods, with an `Allow` header listing supported methods
- Use correct status codes — never return 200 for errors or 500 for client mistakes
- Keep APIs "chunky" not "chatty" — combine related data in single responses to reduce network round trips
- Resource URLs must use nouns, not verbs: `/api/products` not `/api/getProducts`

**Code Smells That Signal a Violation:**
- API routes that don't check `req.method`
- Returning 200 for all responses regardless of outcome
- Missing `Allow` header on 405 responses
- Routes using verb-based naming (e.g., `/api/createUser`)

---

### Rule 3 — Pagination Standard

All paginated endpoints MUST use this exact pattern:

**Query Parameters:**
- `page` — Page number (default: `1`, minimum: `1`, must be a positive integer)
- `limit` — Items per page (default: `30`, minimum: `1`, maximum: `100`, must be a positive integer)

**Response Meta:**
```json
{
  "meta": {
    "page": 1,
    "limit": 30,
    "total": 1000,
    "totalPages": 34,
    "hasMore": true
  }
}
```

**Rules:**
- All list/collection endpoints must support pagination
- Always include `hasMore` in the meta — clients depend on this to know if more pages exist
- Validate `page` and `limit` parameters using Zod before use
- Use `skip`/`take` pattern with Prisma for offset-based pagination
- Always execute the count query in parallel with the data query using `Promise.all`

**Code Smells That Signal a Violation:**
- List endpoints that return all records without pagination
- Missing `hasMore` field in pagination meta
- Sequential count + data queries instead of parallel
- Hardcoded pagination values without allowing client override

---

### Rule 4 — Input Validation with Zod

**Zod is the required and only allowed validation library** for all input validation in API routes.

**Rules:**
- All user input MUST be validated with Zod before any processing: query parameters, request body, path parameters, headers (when used as input)
- Define Zod schemas for every input shape
- Use `z.infer<typeof schema>` to derive TypeScript types from Zod schemas — single source of truth for type + validation
- Validation errors must return 400 with the standard error envelope, including the Zod error details
- Coerce types where appropriate (e.g., `z.coerce.number()` for query params that arrive as strings)
- Define schemas close to the route that uses them, or in a shared schemas file if reused across routes

**Schema Example:**
```typescript
import { z } from 'zod';

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

type PaginationInput = z.infer<typeof paginationSchema>;
```

**Code Smells That Signal a Violation:**
- Manual `Number()`, `parseInt()`, or type-casting for input parsing
- `if/else` chains validating individual fields instead of a Zod schema
- TypeScript types defined separately from validation schemas (dual source of truth)
- Using a validation library other than Zod
- Missing validation on any input field

---

### Rule 5 — Centralized Error Handling

All API routes MUST use a centralized error handler wrapper — **no individual try-catch blocks in route handlers**.

**Rules:**
- Create a shared API handler wrapper utility (e.g., `withApiHandler` or `apiHandler`) that:
  - Wraps the route handler in a try-catch
  - Catches all errors and returns the standard error envelope
  - Returns 500 for unhandled errors with a generic message — **never leak internal error details, stack traces, or database errors to clients**
  - Handles Zod validation errors specifically and returns 400
  - Handles known application errors with appropriate status codes
- Route handlers must focus only on business logic — no try-catch, no error formatting
- The wrapper should also handle HTTP method validation (405 responses)

**Wrapper Pattern:**
```typescript
// Conceptual structure — the wrapper handles cross-cutting concerns
function withApiHandler(
  handler: (req, res) => Promise<void>,
  options: { allowedMethods: string[] }
) {
  return async (req, res) => {
    // 1. Method validation → 405
    // 2. try { await handler(req, res) }
    // 3. catch → Zod error → 400 | known error → appropriate code | unknown → 500
  };
}
```

**Code Smells That Signal a Violation:**
- try-catch blocks inside individual API route handlers
- Error formatting logic duplicated across routes
- Stack traces or internal error messages in API responses
- Inconsistent error response shapes across routes
- Route handlers that handle both business logic and error formatting

---

### Rule 6 — Security (Always Enforced)

These security rules apply at all times, regardless of project state:

**6a. Never Trust User Input:**
- All input MUST be validated with Zod (Rule 4)
- Never use raw `req.query`, `req.body`, or `req.params` values without validation
- Sanitize string inputs where they will be used in HTML contexts

**6b. Parameterized Queries:**
- Always use Prisma's query builder — never concatenate user input into queries
- If raw SQL is ever used (`$queryRaw`, `$executeRaw`), MUST use parameterized queries with `Prisma.sql` template literal
- Never use string interpolation or concatenation in raw SQL

**6c. No Hardcoded Secrets:**
- Database URLs, API keys, tokens, and secrets MUST never appear in source code
- Always load sensitive values from environment variables via `process.env`
- Use `NEXT_PUBLIC_` prefix ONLY for values that are safe to expose on the client side
- Never commit `.env` files to version control (verify `.gitignore` includes them)

**6d. Environment Separation:**
- Maintain separate `.env` files per environment: `.env.development`, `.env.production`
- Environment-specific behavior must be controlled via environment variables, not code branches

**Code Smells That Signal a Violation:**
- Raw `req.query.someField` used without Zod validation
- String concatenation in database queries: `` `SELECT * FROM ${table} WHERE id = ${id}` ``
- Hardcoded connection strings, API keys, or tokens in source files
- `.env` files not listed in `.gitignore`
- `NEXT_PUBLIC_` prefix on values that contain secrets

---

### Rule 7 — Database Optimization (Prisma)

**7a. Efficient Queries:**
- Use `select` to pick only the fields needed — never fetch entire records when only a subset is used
- Use `include` judiciously for relations — only include relations that are needed by the response
- Execute independent queries in parallel using `Promise.all`
- Use `count()` for totals rather than fetching all records and counting in JavaScript

**7b. N+1 Query Detection:**
- Flag any pattern where a query is executed inside a loop
- When loading relations for a list of records, use `include` or a single query with `where: { id: { in: ids } }` instead of looping
- Prefer Prisma's relation loading over manual joins

**7c. Indexing:**
- Add `@index` to fields used in `where`, `orderBy`, or `unique` constraints
- When adding new query patterns, verify that the queried fields are indexed
- Review Prisma schema for missing indexes during schema modifications

**7d. Connection Management:**
- Do NOT instantiate `new PrismaClient()` inside route handlers — this creates a new connection per request
- Use a singleton Prisma client instance shared across the application
- Define the singleton in a dedicated file (e.g., `lib/prisma.ts`) with the standard Next.js dev-mode pattern:

```typescript
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

**7e. Schema Best Practices:**
- Always include `createdAt` and `updatedAt` timestamps on models
- Use meaningful field types (e.g., `Decimal` for prices instead of `Float` to avoid floating-point precision issues — flag when detected)
- Define relations explicitly in the schema when models are related

**Code Smells That Signal a Violation:**
- `new PrismaClient()` inside a route handler or called on every request
- `prisma.model.findMany()` without `select` when not all fields are needed
- Database queries inside `for`/`while`/`map` loops (N+1)
- Missing `@index` on frequently queried fields
- Sequential `await` calls for independent queries instead of `Promise.all`
- Using `Float` for monetary values

---

### Rule 8 — Testing API Routes

Every API route MUST have corresponding test coverage.

**Required Test Cases:**
- **Happy path** — Successful request with valid input returns correct data in the standard envelope
- **Error cases** — Invalid input returns 400 with the error envelope; missing resources return 404
- **Input validation** — Zod validation rejects invalid input and returns structured error messages
- **HTTP method enforcement** — Unsupported methods return 405 with the `Allow` header
- **Edge cases** — Empty results, boundary values (page=1, limit=100), maximum pagination

**Test Structure:**
- Test files should be co-located with the route or in a mirrored `__tests__` directory
- Use descriptive test names: `it('returns 400 when page is negative')`
- Mock the Prisma client for unit tests — do not hit a real database in API route unit tests
- Test the response envelope structure in every test case, not just the data

**Code Smells That Signal a Violation:**
- API routes without corresponding test files
- Tests that only cover the happy path
- Tests that don't verify the envelope structure
- Tests that don't verify status codes

---

### Rule 9 — Naming Conventions

**File Names:**
- API route files: kebab-case (e.g., `user-profiles.ts`, `order-items.ts`)
- Utility/service files: kebab-case (e.g., `api-handler.ts`, `prisma-client.ts`)
- Type definition files: kebab-case (e.g., `product-types.ts`, `api-types.ts`)

**Functions:**
- Route handlers: camelCase (e.g., `getProducts`, `createOrder`, `deleteUser`)
- Utility functions: camelCase (e.g., `withApiHandler`, `validateInput`)

**Types and Interfaces:**
- PascalCase (e.g., `ApiResponse`, `ProductInput`, `PaginationMeta`, `CreateOrderRequest`)
- Prefix interfaces with descriptive nouns, not `I` (e.g., `ProductInput` not `IProductInput`)

**Zod Schemas:**
- camelCase with `Schema` suffix (e.g., `paginationSchema`, `createProductSchema`)

**Constants:**
- UPPER_SNAKE_CASE for true constants (e.g., `DEFAULT_PAGE_SIZE`, `MAX_LIMIT`)

**Code Smells That Signal a Violation:**
- Inconsistent casing within the same file or across routes
- PascalCase or camelCase for file names
- `I` prefix on interfaces
- Zod schemas without the `Schema` suffix

---

### Rule 10 — Environment Variables and Configuration

- Sensitive values MUST never be hardcoded — always loaded from `.env` files via `process.env`
- Maintain separate `.env` files: `.env.development`, `.env.production`, and optionally `.env` as a shared base
- Use `NEXT_PUBLIC_` prefix ONLY for values needed on the client side — never for secrets
- Validate required environment variables at application startup — fail fast if a required variable is missing
- Document all environment variables in `.env.example` (committed to repo, with placeholder values)

**Code Smells That Signal a Violation:**
- Hardcoded URLs, keys, or secrets in source code
- Missing `.env.example` file
- `NEXT_PUBLIC_` prefix on database URLs or API keys
- No validation of required env vars at startup

---

## PROGRESSIVE RULES (Enforced When Feature Exists)

### Rule 11 — Authentication and Authorization (When Auth Exists)

**Enforce when:** Authentication middleware, JWT handling, or OAuth integration is present in the codebase.

- Use JWT or OAuth 2.0 for authentication — no custom session-based auth without justification
- Implement rate limiting on authentication endpoints
- Lock accounts after a configurable number of failed login attempts
- Never store plaintext passwords — use bcrypt or argon2
- Validate and verify JWTs on every authenticated request
- Use middleware for auth checks — do not duplicate auth logic in individual routes
- Return 401 for missing/invalid tokens and 403 for insufficient permissions

---

### Rule 12 — Logging (When Logging Exists)

**Enforce when:** A logging library (e.g., pino, winston) or logging utility is present in the codebase.

- Use structured JSON logging — every log entry must be a JSON object
- Enforce log levels: `info` (normal operations), `warn` (unexpected but handled), `error` (failures requiring attention)
- Use asynchronous logging to minimize request overhead
- Log all API requests with: HTTP method, path, status code, response time (ms)
- Never log sensitive data: passwords, tokens, PII, full request bodies containing secrets
- Include correlation/request IDs in logs for traceability

---

### Rule 13 — Caching (When Caching Exists)

**Enforce when:** A caching layer (Redis, in-memory cache, etc.) is configured in the project.

- Implement caching for frequently read, infrequently changed data
- Define clear cache invalidation strategies — stale data is worse than no cache
- Use appropriate TTLs based on data volatility
- Cache at the right layer: API response caching vs. database query caching
- Use asynchronous processing for long-running tasks to prevent blocking API responses

---

### Rule 14 — CI/CD (When Pipeline Exists)

**Enforce when:** CI/CD configuration files (e.g., `.github/workflows/`, `Jenkinsfile`, etc.) are present.

- All tests must pass in the pipeline before merge
- Lint and type-check in the pipeline
- Run database migrations as part of the deployment process
- Use environment-specific configurations in deployment

---

### Rule 15 — Containerization (When Docker Exists)

**Enforce when:** Docker-related files (`Dockerfile`, `docker-compose.yml`) are present.

- Use multi-stage builds to minimize image size
- Never include `.env` files or secrets in Docker images
- Use `.dockerignore` to exclude unnecessary files
- Pin base image versions — never use `latest` tag
- Run the application as a non-root user inside the container

---

## Refactoring Toward Compliance

When agents identify violations during code review or modification, they should follow this approach:

1. **Assess scope** — How many rules are violated? Is this new code or existing?
2. **Prioritize by impact** — Security rules first (Rule 6), then correctness (Rules 1-5), then quality (Rules 7-10)
3. **Fix in context** — When modifying an existing route, fix violations in the code you're touching. Do not refactor unrelated routes in the same change.
4. **Flag but don't block** — For progressive rules (11-15) that don't yet apply, note them as future considerations but do not require changes.
5. **One concern at a time** — If many violations exist, prioritize and address systematically rather than attempting to fix everything at once.

### Refactoring Priority Order

When a file has multiple violations:

1. **Security** (Rule 6) — Always fix first
2. **Error handling** (Rule 5) — Centralized wrapper must be in place
3. **Input validation** (Rule 4) — Zod schemas before business logic
4. **Response envelope** (Rule 1) — Consistent response format
5. **Database optimization** (Rule 7) — Singleton client, efficient queries
6. **REST conventions** (Rule 2) — Correct methods and status codes
7. **Pagination** (Rule 3) — Standard pattern
8. **Testing** (Rule 8) — Coverage for the route
9. **Naming** (Rule 9) — Consistent conventions
10. **Environment** (Rule 10) — No hardcoded secrets

---

## Rule Selection Quick Reference

When an agent encounters a backend task, use this guide to identify which rules apply:

| Task | Applicable Rules |
|---|---|
| Creating a new API route | 1, 2, 3 (if list), 4, 5, 6, 7d, 8, 9 |
| Modifying an existing API route | 1, 2, 4, 5, 6, 7, 8, 9 + flag existing violations |
| Adding a new Prisma model | 7c, 7e, 9 |
| Writing a database query | 7a, 7b, 7c, 7d |
| Adding environment variables | 6c, 6d, 10 |
| Adding authentication | 6, 11 |
| Adding logging | 12 |
| Adding caching | 13 |
| Reviewing backend code | All applicable rules by tier |
| Writing tests for API routes | 8 |

---

## Frontmatter Settings

```yaml
name: backend-best-practices
description: Strict backend best practices reference — agents consult this during API route, database, and backend code creation, modification, and review to enforce security, REST conventions, Zod validation, Prisma optimization, and testing standards
user-invocable: false
disable-model-invocation: false
```
