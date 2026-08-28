# AGENTS.md

## Product and architecture

This repository is a low-cost CBSE Class 12 MCQ examination platform. Prefer a single React/Vite frontend deployed to Cloudflare Pages and Supabase for Auth, PostgreSQL, RLS, and narrowly scoped RPCs.

Do not introduce a custom backend server, microservices, Docker, Kubernetes, Redis, background-worker infrastructure, or paid third-party services unless a documented requirement proves the existing stack cannot satisfy it.

Keep changes within the currently approved phase. Do not build later-phase capabilities simply because the data model anticipates them.

## Technology conventions

- Use React, TypeScript, Vite, and Tailwind CSS.
- Use feature-oriented directories under `src/features`; shared presentational components belong in `src/components`.
- Keep Supabase calls behind `src/integrations/supabase` or feature-local data modules. Components should not contain raw table names or policy assumptions.
- Prefer explicit TypeScript types generated from the approved Supabase schema.
- Use Vitest for unit tests and React Testing Library for component behavior.
- Test behavior visible to users; avoid brittle implementation-detail tests.
- Keep dependencies few. Before adding one, prefer the browser, React, TypeScript, Supabase, or a small local utility.

## Security rules (non-negotiable)

- Never commit secrets, tokens, database passwords, or `.env.local`.
- Frontend code may use only public `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` configuration.
- Never expose the Supabase service-role key to frontend code, Cloudflare Pages public variables, logs, or test fixtures.
- Treat all browser input, route parameters, JSON imports, and URL data as untrusted.
- Do not rely on hidden UI, client route guards, or client validation for authorization.
- Enable RLS for every application table and write a policy/RPC test for every new access path.
- Students must not receive `questions.correct_option` before submitting an attempt.
- Keep scoring, duration enforcement, attempt ownership checks, and answer-review authorization in PostgreSQL RPCs/queries, not in the browser.
- Make privileged RPCs `SECURITY DEFINER`, set an explicit safe `search_path`, check `auth.uid()`, and return the minimum safe projection.
- Protect the admin role at the database level. A user must never be able to promote their own profile.
- Validate imported question data transactionally and report precise row errors without persisting partial unsafe imports.

## Data and examination rules

- Questions are reusable; associate them with exams through `exam_questions`.
- Published attempts must remain reviewable. Do not change a question used by a live/published exam without a versioning decision.
- The database is authoritative for attempt timing and score. Browser timers and cached answers are only UX aids.
- Autosave and submit operations must be idempotent or safely retryable.
- Never fetch a whole question bank to the browser for an exam.
- Implement negative marking and premium entitlements only when their product rules are explicitly specified.

## Quality gate

Before declaring a change complete:

1. Run formatting, type checking, linting, and relevant Vitest tests when the corresponding tooling exists.
2. For SQL changes, apply to an isolated Supabase database or validate with the Supabase CLI before production use.
3. Manually inspect RLS policies and every exposed RPC response for answer/key leakage.
4. Review the diff for accidental secrets, unrelated edits, and documentation drift.
5. Summarize changed files, validation results, risks, and anything intentionally deferred.

If the repository is only documentation/schema planning, validate internal links, SQL syntax where possible, and consistency across README, architecture, schema, and this file. Do not fabricate successful test results.
