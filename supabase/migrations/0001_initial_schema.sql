-- Initial schema proposal for CBSE Class 12 MCQ Platform.
-- Apply only after review in a Supabase project. This migration establishes the
-- data model and RLS baseline; production RPCs are specified below and should be
-- added with integration tests before the frontend examination flow is enabled.

create extension if not exists pgcrypto;

create type public.app_role as enum ('student', 'admin');
create type public.question_difficulty as enum ('easy', 'medium', 'hard');
create type public.attempt_status as enum ('in_progress', 'submitted', 'expired');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.app_role not null default 'student',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subjects_name_not_blank check (length(trim(name)) > 0),
  constraint subjects_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

create table public.chapters (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete restrict,
  name text not null,
  slug text not null,
  sort_order integer not null default 0,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subject_id, slug),
  constraint chapters_name_not_blank check (length(trim(name)) > 0)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters(id) on delete restrict,
  prompt text not null,
  options jsonb not null,
  correct_option smallint not null,
  explanation text,
  difficulty public.question_difficulty not null default 'medium',
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint questions_prompt_not_blank check (length(trim(prompt)) > 0),
  constraint questions_options_array check (
    jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 6
  ),
  constraint questions_correct_option_in_range check (
    correct_option >= 0 and correct_option < jsonb_array_length(options)
  )
);

create table public.exams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  duration_seconds integer not null,
  is_published boolean not null default false,
  is_premium boolean not null default false,
  available_from timestamptz,
  available_until timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exams_title_not_blank check (length(trim(title)) > 0),
  constraint exams_duration_positive check (duration_seconds between 60 and 21600),
  constraint exams_availability_order check (
    available_until is null or available_from is null or available_until > available_from
  )
);

create table public.exam_questions (
  exam_id uuid not null references public.exams(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  position integer not null,
  marks numeric(6,2) not null default 1,
  primary key (exam_id, question_id),
  unique (exam_id, position),
  constraint exam_questions_position_positive check (position > 0),
  constraint exam_questions_marks_positive check (marks > 0)
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  exam_id uuid not null references public.exams(id) on delete restrict,
  status public.attempt_status not null default 'in_progress',
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  submitted_at timestamptz,
  score numeric(8,2),
  max_score numeric(8,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attempts_expiry_after_start check (expires_at > started_at),
  constraint attempts_submission_fields check (
    (status = 'in_progress' and submitted_at is null and score is null and max_score is null)
    or (status in ('submitted', 'expired') and submitted_at is not null and score is not null and max_score is not null)
  )
);

-- Prevent an accidental second active attempt for the same student/exam.
create unique index attempts_one_open_attempt_per_exam
  on public.attempts (student_id, exam_id)
  where status = 'in_progress';

create table public.attempt_answers (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  selected_option smallint,
  is_marked_for_review boolean not null default false,
  answered_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (attempt_id, question_id),
  constraint attempt_answers_selected_option_nonnegative check (
    selected_option is null or selected_option >= 0
  )
);

create index chapters_subject_id_idx on public.chapters(subject_id);
create index questions_chapter_active_idx on public.questions(chapter_id) where is_active;
create index exam_questions_exam_position_idx on public.exam_questions(exam_id, position);
create index attempts_student_created_idx on public.attempts(student_id, created_at desc);
create index attempt_answers_attempt_idx on public.attempt_answers(attempt_id);

-- Generic timestamp trigger.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger subjects_set_updated_at before update on public.subjects
  for each row execute function public.set_updated_at();
create trigger chapters_set_updated_at before update on public.chapters
  for each row execute function public.set_updated_at();
create trigger questions_set_updated_at before update on public.questions
  for each row execute function public.set_updated_at();
create trigger exams_set_updated_at before update on public.exams
  for each row execute function public.set_updated_at();
create trigger attempts_set_updated_at before update on public.attempts
  for each row execute function public.set_updated_at();
create trigger attempt_answers_set_updated_at before update on public.attempt_answers
  for each row execute function public.set_updated_at();

-- Create a profile automatically. The role is always student at signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'student');
  return new;
end;
$$;

create trigger auth_user_profile_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- A user may edit their name but may never self-promote.
create or replace function public.prevent_self_role_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() = old.id and new.role is distinct from old.role then
    raise exception 'Role changes require administrator action';
  end if;
  return new;
end;
$$;

create trigger profiles_prevent_self_role_change
  before update on public.profiles
  for each row execute function public.prevent_self_role_change();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- RLS is the authorization boundary. The client receives no direct question bank
-- access and has no direct write policy for attempts or answers.
alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.chapters enable row level security;
alter table public.questions enable row level security;
alter table public.exams enable row level security;
alter table public.exam_questions enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;

create policy "profiles_select_self" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles_update_self" on public.profiles
  for update to authenticated using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy "subjects_select_published" on public.subjects
  for select to authenticated using (is_published or public.is_admin());
create policy "subjects_admin_manage" on public.subjects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "chapters_select_published" on public.chapters
  for select to authenticated using (is_published or public.is_admin());
create policy "chapters_admin_manage" on public.chapters
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "questions_admin_only" on public.questions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "exam_questions_admin_only" on public.exam_questions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "exams_select_available" on public.exams
  for select to authenticated using (
    public.is_admin()
    or (is_published and (available_from is null or available_from <= now())
        and (available_until is null or available_until > now()))
  );
create policy "exams_admin_manage" on public.exams
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "attempts_select_own" on public.attempts
  for select to authenticated using (student_id = auth.uid() or public.is_admin());
create policy "attempts_admin_manage" on public.attempts
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "attempt_answers_select_own" on public.attempt_answers
  for select to authenticated using (
    public.is_admin() or exists (
      select 1 from public.attempts
      where attempts.id = attempt_answers.attempt_id
        and attempts.student_id = auth.uid()
    )
  );
create policy "attempt_answers_admin_manage" on public.attempt_answers
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Required RPC contract (implement before exposing the student exam UI):
-- start_exam(exam_id uuid): validates publication/availability, creates or
-- resumes one attempt, and returns only id, prompt, options, position, marks.
-- save_attempt_answer(attempt_id uuid, question_id uuid, selected_option smallint,
--   is_marked_for_review boolean): validates ownership, in-progress state,
--   unexpired attempt, question membership, and option range.
-- submit_attempt(attempt_id uuid): locks the attempt, computes marks from
-- questions.correct_option, sets submitted_at/status/score/max_score atomically.
-- get_attempt_review(attempt_id uuid): owner-only; returns correct option and
-- explanation only after the attempt has been submitted.
--
-- Each RPC must be SECURITY DEFINER with an explicit search_path, verify auth.uid(),
-- expose only necessary columns, and receive RLS/RPC integration tests.
