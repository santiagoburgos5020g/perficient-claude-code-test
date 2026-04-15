---
name: backend-best-practices
description: Strict backend best practices reference — agents consult this during API route, database, and backend code creation, modification, and review to enforce security, REST conventions, Zod validation, Prisma optimization, and testing standards
user-invocable: true
---

# Backend Best Practices Reference

Strict reference for backend best practices in this project (Next.js 14 Pages Router, TypeScript, Prisma/SQLite). Agents and subagents consult this as the authoritative source of truth during any backend code creation, modification, or review.

## Workflow Overview

1. **Identify** — Determine if the task involves backend code (API routes, database, middleware, services)
2. **Check tier** — Which rules apply given the current codebase state? (see Progressive Enforcement)
3. **Apply** — Follow all applicable rules when creating or modifying code
4. **Audit** — When reviewing, flag violations with severity level and rule number

---

## Agent Decision Process

When agents encounter a backend task, follow this process:

1. **Identify the scope** — Is this an API route, database operation, middleware, or backend utility?
2. **Check applicability** — Which rules apply given the current codebase state? (see Progressive Enforcement)
3. **Apply rules** — Follow all applicable rules when creating/modifying code
4. **Audit** — When reviewing code, flag violations with severity and the specific rule number

### Severity Levels for Audits

When reviewing backend code, categorize findings as:

- **Critical** — A rule is clearly violated and causes security, correctness, or maintainability problems. Must be fixed.
- **Recommended** — A rule is violated but the current approach is functional. Should be fixed.
- **Future** — A rule will apply when a relevant feature is added. Note for awareness, do not enforce.

### Progressive Enforcement

Rules are grouped into tiers based on when they apply:

| Tier | When It Applies | Rules |
|---|---|---|
| **Always** | Every backend task | 1-10 |
| **When Auth Exists** | Auth middleware, JWT, or OAuth is present | 11 |
| **When Logging Exists** | A logging library or utility is present | 12 |
| **When Caching Exists** | A caching layer (Redis, etc.) is present | 13 |
| **When CI/CD Exists** | CI/CD pipeline config is present | 14 |
| **When Containerized** | Docker config is present | 15 |

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

**Code Smells:**
- API responses that return raw arrays or objects without the envelope
- Inconsistent response shapes across routes
- Error responses missing `success: false`
- Pagination data in `data` instead of `meta`

---

### Rule 2 — RESTful API Design

**HTTP Methods:**
- `GET` — Read/retrieve (idempotent, no side effects)
- `POST` — Create new resources
- `PUT` — Update/replace existing resources
- `PATCH` — Partial update
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
| 405 | Method Not Allowed | HTTP method not supported |
| 409 | Conflict | Resource conflict (e.g., duplicate) |
| 422 | Unprocessable Entity | Valid syntax but business logic rejects it |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unhandled server error |

**Rules:**
- Every API route MUST explicitly declare which HTTP methods it supports
- Every API route MUST return 405 for unsupported methods with an `Allow` header
- Use correct status codes — never 200 for errors or 500 for client mistakes
- Keep APIs "chunky" not "chatty" — combine related data in single responses
- Resource URLs use nouns: `/api/products` not `/api/getProducts`

**Code Smells:**
- Routes that don't check `req.method`
- Returning 200 for all responses
- Missing `Allow` header on 405
- Verb-based route naming

---

### Rule 3 — Pagination Standard

All paginated endpoints MUST use this exact pattern:

**Query Parameters:**
- `page` — default `1`, min `1`, positive integer
- `limit` — default `30`, min `1`, max `100`, positive integer

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
- Always include `hasMore` in meta
- Validate `page` and `limit` with Zod before use
- Use `skip`/`take` with Prisma for offset-based pagination
- Execute count query in parallel with data query using `Promise.all`

**Code Smells:**
- List endpoints returning all records without pagination
- Missing `hasMore`
- Sequential count + data queries
- Hardcoded pagination without client override

---

### Rule 4 — Input Validation with Zod

**Zod is required** — no alternative validation libraries allowed.

**Rules:**
- All user input MUST be validated with Zod before processing: query params, request body, path params, headers (when used as input)
- Define Zod schemas for every input shape
- Use `z.infer<typeof schema>` to derive TypeScript types — single source of truth
- Validation errors return 400 with the standard error envelope
- Use `z.coerce.number()` for query params arriving as strings
- Define schemas close to the route or in a shared schemas file if reused

**Schema Example:**
```typescript
import { z } from 'zod';

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

type PaginationInput = z.infer<typeof paginationSchema>;
```

**Code Smells:**
- Manual `Number()`, `parseInt()`, or type-casting for input
- `if/else` chains validating individual fields instead of Zod
- TypeScript types defined separately from Zod schemas (dual source of truth)
- Any validation library other than Zod
- Missing validation on any input field

---

### Rule 5 — Centralized Error Handling

All API routes MUST use a centralized error handler wrapper — **no try-catch in route handlers**.

**Rules:**
- Create a shared wrapper (e.g., `withApiHandler`) that:
  - Wraps the handler in try-catch
  - Returns the standard error envelope
  - Returns 500 for unhandled errors with a generic message — **never leak internal details**
  - Handles Zod validation errors and returns 400
  - Handles known application errors with appropriate status codes
  - Handles HTTP method validation (405)
- Route handlers focus only on business logic — no try-catch, no error formatting

**Wrapper Pattern:**
```typescript
function withApiHandler(
  handler: (req, res) => Promise<void>,
  options: { allowedMethods: string[] }
) {
  return async (req, res) => {
    // 1. Method validation -> 405
    // 2. try { await handler(req, res) }
    // 3. catch -> Zod error -> 400 | known error -> code | unknown -> 500
  };
}
```

**Code Smells:**
- try-catch blocks inside individual route handlers
- Error formatting logic duplicated across routes
- Stack traces in API responses
- Inconsistent error response shapes

---

### Rule 6 — Security (Always Enforced)

**6a. Never Trust User Input:**
- All input MUST be validated with Zod (Rule 4)
- Never use raw `req.query`, `req.body`, or `req.params` without validation

**6b. Parameterized Queries:**
- Always use Prisma's query builder — never concatenate user input into queries
- If raw SQL is used (`$queryRaw`, `$executeRaw`), MUST use `Prisma.sql` template literal
- Never use string interpolation in raw SQL

**6c. No Hardcoded Secrets:**
- Database URLs, API keys, tokens MUST never appear in source code
- Load from `process.env`
- `NEXT_PUBLIC_` prefix ONLY for client-safe values
- Never commit `.env` files (verify `.gitignore`)

**6d. Environment Separation:**
- Separate `.env` files per environment: `.env.development`, `.env.production`
- Environment-specific behavior via env vars, not code branches

**Code Smells:**
- Raw `req.query.someField` without Zod validation
- String concatenation in queries
- Hardcoded connection strings or tokens
- `.env` files not in `.gitignore`
- `NEXT_PUBLIC_` on secrets

---

### Rule 7 — Database Optimization (Prisma)

**7a. Efficient Queries:**
- Use `select` for only needed fields — never fetch entire records when a subset suffices
- Use `include` judiciously — only for needed relations
- Execute independent queries in parallel with `Promise.all`
- Use `count()` for totals, not fetch-all-and-count

**7b. N+1 Query Detection:**
- Flag any query inside a loop
- Use `include` or `where: { id: { in: ids } }` for batch loading
- Prefer Prisma relation loading over manual joins

**7c. Indexing:**
- Add `@index` to fields used in `where`, `orderBy`, or `unique` constraints
- Verify indexes when adding new query patterns
- Review schema for missing indexes during modifications

**7d. Connection Management:**
- NEVER instantiate `new PrismaClient()` inside route handlers
- Use a singleton shared across the application in `lib/prisma.ts`:

```typescript
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

**7e. Schema Best Practices:**
- Always include `createdAt` and `updatedAt` timestamps
- Use `Decimal` for monetary values, not `Float` (flag floating-point precision issues)
- Define relations explicitly when models are related

**Code Smells:**
- `new PrismaClient()` inside a route handler
- `findMany()` without `select` when not all fields needed
- Queries inside loops (N+1)
- Missing `@index` on queried fields
- Sequential `await` for independent queries
- `Float` for monetary values

---

### Rule 8 — Testing API Routes

Every API route MUST have test coverage.

**Required Test Cases:**
- **Happy path** — Valid input returns correct data in the envelope
- **Error cases** — Invalid input returns 400; missing resources return 404
- **Input validation** — Zod rejects invalid input with structured errors
- **HTTP method enforcement** — Unsupported methods return 405 with `Allow` header
- **Edge cases** — Empty results, boundary values (page=1, limit=100)

**Rules:**
- Test files co-located with routes or in a mirrored `__tests__` directory
- Descriptive test names: `it('returns 400 when page is negative')`
- Mock Prisma for unit tests — no real database
- Verify envelope structure in every test

**Code Smells:**
- Routes without test files
- Tests covering only the happy path
- Tests not verifying envelope structure
- Tests not verifying status codes

---

### Rule 9 — Naming Conventions

**File Names:** kebab-case
- API routes: `user-profiles.ts`, `order-items.ts`
- Utilities: `api-handler.ts`, `prisma-client.ts`

**Functions:** camelCase
- Handlers: `getProducts`, `createOrder`
- Utilities: `withApiHandler`, `validateInput`

**Types/Interfaces:** PascalCase
- `ApiResponse`, `ProductInput`, `PaginationMeta`
- No `I` prefix (`ProductInput` not `IProductInput`)

**Zod Schemas:** camelCase with `Schema` suffix
- `paginationSchema`, `createProductSchema`

**Constants:** UPPER_SNAKE_CASE
- `DEFAULT_PAGE_SIZE`, `MAX_LIMIT`

**Code Smells:**
- Inconsistent casing
- PascalCase or camelCase file names
- `I` prefix on interfaces
- Schemas without `Schema` suffix

---

### Rule 10 — Environment Variables and Configuration

- Sensitive values MUST be loaded from `.env` via `process.env`
- Separate `.env` files: `.env.development`, `.env.production`
- `NEXT_PUBLIC_` prefix ONLY for client-safe values
- Validate required env vars at startup — fail fast
- Document all env vars in `.env.example` (committed, with placeholders)

**Code Smells:**
- Hardcoded URLs, keys, or secrets
- Missing `.env.example`
- `NEXT_PUBLIC_` on secrets
- No startup validation of required env vars

---

## PROGRESSIVE RULES (Enforced When Feature Exists)

### Rule 11 — Authentication and Authorization

**Enforce when:** Auth middleware, JWT handling, or OAuth is present.

- Use JWT or OAuth 2.0 — no custom session auth without justification
- Rate limiting on auth endpoints
- Account lockout after configurable failed attempts
- Never store plaintext passwords — use bcrypt or argon2
- Validate JWTs on every authenticated request
- Auth checks in middleware, not duplicated per route
- 401 for missing/invalid tokens; 403 for insufficient permissions

---

### Rule 12 — Logging

**Enforce when:** A logging library or utility is present.

- Structured JSON logging — every entry is a JSON object
- Log levels: `info`, `warn`, `error`
- Asynchronous logging to minimize overhead
- Log all API requests: method, path, status code, response time (ms)
- Never log secrets, passwords, tokens, or PII
- Include correlation/request IDs for traceability

---

### Rule 13 — Caching

**Enforce when:** A caching layer is configured.

- Cache frequently read, infrequently changed data
- Clear invalidation strategies — stale data is worse than no cache
- Appropriate TTLs based on data volatility
- Cache at the right layer: response vs. query caching
- Async processing for long-running tasks

---

### Rule 14 — CI/CD

**Enforce when:** CI/CD config files are present.

- All tests must pass before merge
- Lint and type-check in pipeline
- Database migrations in deployment
- Environment-specific configs

---

### Rule 15 — Containerization

**Enforce when:** Docker files are present.

- Multi-stage builds for minimal image size
- No `.env` files or secrets in images
- `.dockerignore` for unnecessary files
- Pinned base image versions — never `latest`
- Non-root user inside container

---

## Refactoring Priority Order

When a file has multiple violations, fix in this order:

1. **Security** (Rule 6)
2. **Error handling** (Rule 5)
3. **Input validation** (Rule 4)
4. **Response envelope** (Rule 1)
5. **Database optimization** (Rule 7)
6. **REST conventions** (Rule 2)
7. **Pagination** (Rule 3)
8. **Testing** (Rule 8)
9. **Naming** (Rule 9)
10. **Environment** (Rule 10)

---

## Rule Selection Quick Reference

| Task | Applicable Rules |
|---|---|
| Creating a new API route | 1, 2, 3 (if list), 4, 5, 6, 7d, 8, 9 |
| Modifying an existing API route | 1, 2, 4, 5, 6, 7, 8, 9 + flag violations |
| Adding a new Prisma model | 7c, 7e, 9 |
| Writing a database query | 7a, 7b, 7c, 7d |
| Adding environment variables | 6c, 6d, 10 |
| Adding authentication | 6, 11 |
| Adding logging | 12 |
| Adding caching | 13 |
| Reviewing backend code | All applicable rules by tier |
| Writing tests for API routes | 8 |

---

## Important Notes

- All core rules (1-10) are **hard requirements**, not suggestions. Violations must be flagged and fixed.
- Progressive rules (11-15) only apply when their prerequisite feature exists in the codebase.
- When reviewing code, always explain **why** a rule applies — never just state the rule number.
- Do not over-engineer — if the current backend is simple, apply rules proportionally. Rules are about correctness and consistency, not ceremony.
- This skill is specific to this project's stack: Next.js 14 Pages Router, TypeScript, Prisma, SQLite, Zod.
