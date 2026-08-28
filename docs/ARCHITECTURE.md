# Architecture Decision Record: CBSE Class 12 MCQ Platform

## 1. Goal and constraints

This project validates a student examination experience with the smallest secure architecture that can become production quality. It must deploy from GitHub to Cloudflare Pages and Supabase, and work from a cloud development environment.

The system is a static React application communicating directly with Supabase through its public client configuration. PostgreSQL, Auth, Row Level Security (RLS), and a small set of database RPCs form the backend. There is no custom application server, container platform, cache, queue, microservice fleet, or Kubernetes cluster in this phase.

## 2. System shape

```text
Student browser
  └─ Cloudflare Pages: React + TypeScript + Vite application
       └─ Supabase Auth: session identity
       └─ Supabase PostgREST/RPC: RLS-protected reads and writes
            └─ PostgreSQL: curriculum, exam, attempt, and analytics data

Administrator browser
  └─ Same application, role-gated admin routes
       └─ Supabase RLS and admin-only policies/RPCs
```

Cloudflare Pages serves only the compiled frontend. Supabase is the system of record. Security does not depend on hiding a route or disabling a UI control: it is enforced in PostgreSQL.

## 3. Frontend boundaries

- `app/`: router, authentication bootstrap, providers, and global error handling.
- `features/auth`: sign-up, sign-in, sign-out, and profile loading.
- `features/catalog`: subject, chapter, and published-exam discovery.
- `features/exam`: active attempt state, timer, navigation, review marks, autosave, and submission UX.
- `features/results`: score, answer review, explanations, and prior attempts.
- `features/progress`: overall, subject, and chapter progress views.
- `features/admin`: later-only protected administration workflow.
- `integrations/supabase`: typed Supabase client and explicitly named RPC/data-access functions.

Feature components may call feature hooks; hooks call the integration boundary. UI components must not embed authorization assumptions or service credentials.

## 4. Examination workflow

1. Authenticated student selects a published exam.
2. Client calls a security-definer `start_exam` RPC. The database verifies availability, creates/resumes one active attempt, and returns a question projection that excludes `correct_option`.
3. The client keeps transient UI state locally and debounces answer/review changes to narrow RPCs or RLS-protected writes. The database remains authoritative.
4. A client-side timer is only a display aid. Submission compares the database timestamps against the exam duration.
5. Client calls `submit_attempt`. The database locks the attempt, scores against protected question data, and writes final totals.
6. Client fetches an attempt-review projection only after submission; it can then include the correct answer and explanation.

The initial UX will favor idempotent actions: retrying `start_exam`, autosave, or `submit_attempt` must not create duplicate attempts or lose selected answers.

## 5. Database model

The initial migration proposal defines:

| Entity | Responsibility |
| --- | --- |
| `profiles` | Auth-linked student profile and application role |
| `subjects` | Class 12 subject catalog |
| `chapters` | Subject-owned chapter catalog |
| `questions` | Reusable MCQs, choices, protected answer, explanation, difficulty |
| `exams` | Published/free state, duration, marks, validity window |
| `exam_questions` | Ordered question reuse and per-exam marks |
| `attempts` | Student lifecycle, timing, score, submission state |
| `attempt_answers` | Chosen option and review state for each attempt question |

Question options are stored as a JSONB array to keep a version-one MCQ simple. Each question belongs to one chapter. A later question-version table is the right migration if published exams must retain historical wording after editors revise a question.

## 6. Security model

- The frontend uses only `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
- RLS is enabled on every application table.
- Students can read only published catalog data and their own attempts/answers.
- Students do not receive direct `questions` or `exam_questions` table access.
- `start_exam` returns a safe question projection; the protected answer is never selected.
- `submit_attempt` performs scoring inside PostgreSQL after validating the caller owns an open attempt.
- The review projection is available only to the attempt owner after submission.
- Role checks occur in database policies/functions via `profiles.role`, not only in the client.
- Profile role changes are guarded by a trigger so a student cannot promote themself.
- Service-role credentials remain server-side only. If privileged automation is later needed, use a Supabase Edge Function or restricted CI secret; do not expose a server key to Cloudflare Pages.
- All user-provided text, IDs, JSON imports, and option choices are validated at the data boundary. UI validation is for usability, not authorization.

## 7. MVP delivery boundary

Implement next, in order:

1. Vite/React/TypeScript/Tailwind scaffold and lint/test baseline.
2. Supabase project configuration, migration application, and generated database types.
3. Authentication and profile bootstrap.
4. Published subject/chapter/exam catalog.
5. Start/resume exam, answer autosave, review flag, timer, and server-enforced submission.
6. Score/review and attempt history.
7. Lightweight progress aggregations (overall, subject, chapter).
8. RLS/RPC integration tests and browser-level happy-path smoke test.

MVP administration can be managed through reviewed Supabase SQL/Studio while the student flow is validated. A role-protected admin UI and JSON question import are phase two.

## 8. Later phases

- Admin UI, audit trail, and JSON import with strict schema validation.
- Premium entitlements/payment integration.
- Negative marking and richer per-exam scoring rules.
- Question media, question versions, bulk authoring workflow, and approval/publishing workflow.
- Analytics dashboards and export.
- Rate limiting/abuse controls if public usage materially increases.
- Email verification, password reset UX, and notification workflows as product needs justify them.

## 9. Technical risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Correct answers leak before submission | No student SELECT policy on questions; use safe RPC projection and test response shapes. |
| Client clock manipulation | Database timestamps/duration decide expiry; client timer is presentation only. |
| Autosave races or duplicate submits | One active attempt constraint; idempotent RPC design and transactional submission. |
| Editing questions changes old reviews | Freeze published questions initially; add question versioning before unrestricted editing. |
| RLS becomes hard to reason about | Keep policies small, use explicit RPCs for multi-table operations, and test with student/admin JWTs. |
| Unauthorized role escalation | Guard role field with trigger and admin-only policy/function. |
| Static-host SPA routing breaks refresh | Configure Cloudflare Pages SPA fallback during implementation. |
| Cost grows with broad reads | Paginate catalogs/history; return only fields required by each screen; avoid realtime until needed. |

## 10. Explicit non-decisions

The following are intentionally out of scope until evidence requires them: a custom API server, Docker, Redis, microservices, background jobs, Kubernetes, event streaming, and native mobile applications.
