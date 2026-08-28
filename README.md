# CBSE Class 12 MCQ Platform

A low-cost, production-minded examination platform for CBSE Class 12 students. It is intentionally being designed as a single React application backed by Supabase, with Cloudflare Pages for delivery.

## Status

Architecture and data-model planning only. No application features have been implemented yet.

## Product scope

Students will be able to sign up, take timed MCQ exams, resume safely after interruptions, receive a scored review with explanations, and track progress by chapter, subject, and overall.

Administrators will manage the curriculum, question bank, exams, publishing, and basic attempt analytics. The first release keeps administration deliberately small; a dedicated admin UI comes after the student examination flow is proven.

## Planned stack

- React, TypeScript, Vite, Tailwind CSS
- Supabase: PostgreSQL, Auth, Row Level Security, and narrowly scoped database functions
- Cloudflare Pages for the static frontend
- Vitest and React Testing Library

The browser client uses the Supabase anonymous/publishable key only. Service-role credentials are never part of frontend builds.

## Architecture and schema

- [Architecture](docs/ARCHITECTURE.md)
- [Initial database proposal](supabase/migrations/0001_initial_schema.sql)
- [Secure exam RPCs](supabase/migrations/0002_exam_rpcs.sql)
- [Database integration tests](supabase/tests/exam_rpcs.test.sql)
- [Project conventions](AGENTS.md)

## Intended directory layout

```text
src/
  app/              # routing, providers, application shell
  components/       # reusable presentational UI
  features/         # feature-owned UI, hooks, types, and tests
    auth/
    dashboard/
    catalog/
    exam/
    results/
    progress/
    admin/          # later; access-guarded
  integrations/
    supabase/       # browser client and typed data/RPC boundary
  lib/              # framework-agnostic utilities
  styles/
  test/
supabase/
  migrations/
  seed/             # development-only sample data, never production data
docs/
public/
```

## Getting started

Once the app scaffold is added, development should require only a cloud environment with Node.js and a Supabase project:

1. Copy `.env.example` to `.env.local`.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
3. Apply the reviewed SQL migration using Supabase CLI or the Supabase dashboard.
4. Run `npm install`, `npm run dev`, and `npm test`.

Database integration tests live in `supabase/tests`. Run them only against an isolated, disposable Supabase test database using the Supabase CLI; they create fixture users and curriculum data inside their transaction and roll it back. The platform itself does not require Docker or a custom backend.

Do not place service-role keys, database passwords, or production tokens in `.env.local` files that may be committed.

## Deployment

Cloudflare Pages builds the Vite application and serves its static output. Supabase hosts the database and authentication. No custom server, containers, Redis, or microservices are planned for the MVP.

Required Cloudflare Pages build configuration (after scaffolding):

- Build command: `npm run build`
- Build output directory: `dist`
- Node version: a currently supported LTS release
- Environment variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

## Phased delivery

**MVP:** authentication, published catalog, one timed exam flow, autosaved answers, submission/scoring, review, and attempt history.

**Later:** protected admin UI and JSON import, premium entitlements, negative marking, richer analytics, question media, adaptive recommendations, and notifications.

See the architecture document for security decisions, technical risks, and acceptance boundaries.
