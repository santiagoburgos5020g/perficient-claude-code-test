# Next.js E-commerce

A Next.js e-commerce application featuring an infinite-scroll product listing with 1,000 products, styled with Perficient's corporate design system.

## Prerequisites

- Node.js >= 18
- npm

## Setup

1. `npm install` — Install all dependencies
2. `npx prisma generate` — Generate Prisma Client
3. `npx prisma migrate dev --name init` — Create database and apply schema
4. `npx prisma db seed` — Seed 1,000 products
5. `npm run dev` — Start development server
6. Open `http://localhost:3000`

## Scripts

| Script | Description |
|---|---|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm run format` | Format code with Prettier |
| `npm run prisma:generate` | Generate Prisma Client |
| `npm run prisma:migrate` | Run Prisma migrations |
| `npm run prisma:seed` | Seed the database |
| `npm run prisma:studio` | Open Prisma Studio |

## Tech Stack

- **Framework:** Next.js 14 (Pages Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS with Perficient brand tokens
- **Database:** SQLite via Prisma ORM
- **Font:** Inter (Google Fonts)
