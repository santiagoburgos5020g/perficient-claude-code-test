When multiple violations are found across skills, follow this combined refactoring order. Each step creates the preconditions for the next.

## Combined Refactoring Priority

### Backend (from backend-best-practices)
1. Security (Rule 6)
2. Centralized error handling (Rule 5)
3. Input validation with Zod (Rule 4)
4. Standard API response envelope (Rule 1)
5. Database optimization (Rule 7)
6. REST conventions (Rule 2)
7. Pagination (Rule 3)
8. API testing (Rule 8)
9. Naming (Rule 9)
10. Environment variables (Rule 10)

### Frontend (from nextjs-react-best-practices)
1. TypeScript Strictness (Cat 5)
2. Folder Structure (Cat 2)
3. Container-Presentational (Cat 1)
4. useSWR (Cat 7)
5. Naming Conventions (Cat 3)
6. React 18 Hooks (Cat 6)
7. Error Handling (Cat 8)
8. Testing (Cat 9)
9. Tailwind CSS (Cat 10)
10. Performance (Cat 12)
11. Accessibility (Cat 13)

### SOLID (from solid-principles-reference)
1. SRP — Split responsibilities first
2. ISP — Narrow the interfaces
3. DIP — Invert dependencies toward abstractions
4. OCP — Design for extension
5. LSP — Verify inheritance contracts

### Design Patterns (from design-patterns-reference)
- Apply after SOLID refactoring, only when a pattern genuinely fits
- Never force a pattern where the problem is too simple to warrant one

## Cross-Skill Priority

When backend and frontend violations coexist, fix backend first (security and data integrity take precedence), then frontend.
