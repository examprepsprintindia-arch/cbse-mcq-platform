# Database integration testing

This repository uses pgTAP SQL tests under `supabase/tests`. They validate the database security boundary directly: authentication context, RLS, ownership, answer visibility, timer expiry, and scoring.

**Never run these commands against production.** The tests insert fixture records into `auth.users` and application tables. Each test file opens a transaction and rolls it back, but the required migrations and extensions still change a target database. Use only a local Supabase stack or a separately created disposable test project/database.

## What the existing suite covers

`supabase/tests/exam_rpcs.test.sql` has 15 pgTAP assertions:

1. A signed-in student can read published subjects.
2. A student cannot directly read `questions`.
3. A student can start a published free exam.
4. `start_exam` excludes correct answers and explanations.
5. The attempt owner can save an answer.
6. A student cannot bypass the RPC with a direct answer-table write.
7. The attempt owner can submit.
8. Submission calculates the score from protected answer data.
9. Correct answers become available through review only after submission.
10. Another student cannot list the first student's attempts.
11. Another student cannot retrieve the first student's review by a known ID.
12. A new attempt can start after a prior submission.
13. Saving after database expiry fails.
14. An expired attempt can still be finalized.
15. Finalization caps submission time at expiry and does not score a post-expiry answer.

## Prerequisites

- Supabase CLI v1.11.4 or newer.
- Either:
  - the local Supabase development stack, which the CLI starts; or
  - a **disposable** Supabase/PostgreSQL test database with the Supabase `auth` schema available.
- Permission to create the `pgtap` extension in that test database.
- The two repository migrations applied in order:
  - `supabase/migrations/0001_initial_schema.sql`
  - `supabase/migrations/0002_exam_rpcs.sql`

The application environment variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are not used by these database-only tests.

## Path A: local disposable stack

This is the safest default. It does not use a Supabase cloud project or production credentials. It requires Docker only to run the CLI's ephemeral local Supabase services; Docker is not part of the product deployment.

From the repository root:

```powershell
supabase init
supabase start
supabase db reset
supabase test db supabase/tests/exam_rpcs.test.sql
supabase stop
```

`supabase db reset` recreates the local database and applies the migrations. `supabase test db` runs the SQL tests in transactions; each test file rolls back its fixture data.

If `supabase init` has already been run and `supabase/config.toml` is present, omit that command. Do not commit machine-specific test secrets.

## Path B: a disposable remote test database

Use this only for a project/database created exclusively for testing—never a shared staging or production project.

1. Create a dedicated test database and install pgTAP there.
2. Store its percent-encoded connection URL in your shell only.
3. Apply local migrations to that test database.
4. Run the suite using the explicit URL.

PowerShell:

```powershell
$env:SUPABASE_TEST_DB_URL = 'postgresql://postgres:REDACTED@db.TEST-REF.supabase.co:5432/postgres'
supabase db push --db-url "$env:SUPABASE_TEST_DB_URL"
supabase test db supabase/tests/exam_rpcs.test.sql --db-url "$env:SUPABASE_TEST_DB_URL"
supabase db lint --db-url "$env:SUPABASE_TEST_DB_URL" --level error
Remove-Item Env:SUPABASE_TEST_DB_URL
```

The connection string is a secret. Do not place it in `.env.example`, a tracked `.env` file, CI logs, GitHub issues, or frontend variables. Destroy or reset the disposable database after testing.

## Environment variables

| Variable | Needed for | Secret? | Commit? |
| --- | --- | --- | --- |
| `VITE_SUPABASE_URL` | Future frontend runtime; not database tests | No, public configuration | Use `.env.local`, never hardcode |
| `VITE_SUPABASE_ANON_KEY` | Future frontend runtime; not database tests | No, public configuration | Use `.env.local`, never hardcode |
| `SUPABASE_TEST_DB_URL` | Path B database migration/test/lint commands | Yes | Never |
| `SUPABASE_ACCESS_TOKEN` | Only if choosing CLI login/link workflow instead of `--db-url` | Yes | Never |
| `SUPABASE_DB_PASSWORD` | Only if a CLI command prompts for the disposable database password | Yes | Never |

See `.env.example` for variable names without values.

## Expected result

A successful run reports the test file as `ok` and `Result: PASS`. If a test fails, do not loosen RLS, grant student access to `questions`, or expose `correct_option` merely to satisfy it. Fix the migration/RPC behavior or the test fixture while preserving the documented security boundary.

## Current Codex limitation

This repository's current Codex environment does not have the Supabase CLI, Docker/local stack, or a user-provided disposable database connection. Consequently, it can review test structure but cannot execute this suite here. No production connection has been attempted.
