begin;

create extension if not exists pgtap;

select plan(14);

-- Fixed UUIDs keep this fixture self-contained. Supabase CLI runs database tests
-- against an isolated local database, so these test users never reach production.
insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '10000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'student-a@example.test', 'not-used', now(),
    '{"provider":"email","providers":["email"]}', '{"full_name":"Student A"}', now(), now()
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'student-b@example.test', 'not-used', now(),
    '{"provider":"email","providers":["email"]}', '{"full_name":"Student B"}', now(), now()
  );

insert into public.subjects (id, name, slug, is_published)
values ('20000000-0000-0000-0000-000000000001', 'Physics', 'physics', true);

insert into public.chapters (id, subject_id, name, slug, is_published)
values (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Electrostatics',
  'electrostatics',
  true
);

insert into public.questions (
  id, chapter_id, prompt, options, correct_option, explanation, difficulty
) values (
  '40000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'What is the SI unit of electric charge?',
  '["Coulomb", "Volt", "Ohm", "Tesla"]'::jsonb,
  0,
  'Electric charge is measured in coulombs.',
  'easy'
);

insert into public.exams (id, title, duration_seconds, is_published)
values (
  '50000000-0000-0000-0000-000000000001',
  'Electrostatics checkpoint',
  1800,
  true
);

insert into public.exam_questions (exam_id, question_id, position, marks)
values (
  '50000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  1,
  2
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select count(*)::integer from public.subjects),
  1,
  'an authenticated student can read published catalog data'
);

select is(
  (select count(*)::integer from public.questions),
  0,
  'a student cannot directly read the question bank'
);

select is(
  (select count(*)::integer from public.start_exam('50000000-0000-0000-0000-000000000001')),
  1,
  'an authenticated student can start a published free exam'
);

select ok(
  not exists (
    select 1
    from public.start_exam('50000000-0000-0000-0000-000000000001') as started,
         lateral jsonb_array_elements(started.questions) as question
    where question ? 'correct_option'
       or question ? 'explanation'
  ),
  'start_exam never returns answers or explanations'
);

select lives_ok(
  $$
    select *
    from public.save_attempt_answer(
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and exam_id = '50000000-0000-0000-0000-000000000001'
         and status = 'in_progress'),
      '40000000-0000-0000-0000-000000000001',
      0,
      true
    )
  $$,
  'the attempt owner can persist an in-range answer'
);

select throws_ok(
  $$
    insert into public.attempt_answers (
      attempt_id, question_id, selected_option, is_marked_for_review
    ) values (
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and status = 'in_progress'),
      '40000000-0000-0000-0000-000000000001',
      0,
      false
    )
  $$,
  '42501',
  null,
  'students cannot bypass save_attempt_answer with a direct write'
);

select lives_ok(
  $$
    select *
    from public.submit_attempt(
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and exam_id = '50000000-0000-0000-0000-000000000001')
    )
  $$,
  'the attempt owner can submit an attempt'
);

select is(
  (
    select score
    from public.attempts
    where student_id = '10000000-0000-0000-0000-000000000001'
      and exam_id = '50000000-0000-0000-0000-000000000001'
  ),
  2::numeric,
  'submit_attempt calculates marks from the protected correct option'
);

select is(
  (
    select correct_option
    from public.get_attempt_review(
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and exam_id = '50000000-0000-0000-0000-000000000001')
    )
  ),
  0::smallint,
  'correct option is available only through the post-submission review RPC'
);

select set_config(
  'test.attempt_a_id',
  (
    select id::text
    from public.attempts
    where student_id = '10000000-0000-0000-0000-000000000001'
      and exam_id = '50000000-0000-0000-0000-000000000001'
  ),
  true
);
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);

select is(
  (select count(*)::integer from public.attempts),
  0,
  'a different student cannot read another student''s attempt'
);

select throws_ok(
  format(
    'select * from public.get_attempt_review(%L::uuid)',
    current_setting('test.attempt_a_id')
  ),
  'P0002',
  'Attempt not found',
  'a different student cannot retrieve another student''s review by a known identifier'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select is(
  (select count(*)::integer from public.start_exam('50000000-0000-0000-0000-000000000001')),
  1,
  'starting after a submission creates a fresh active attempt'
);

reset role;
update public.attempts
set expires_at = now() - interval '1 second'
where student_id = '10000000-0000-0000-0000-000000000001'
  and exam_id = '50000000-0000-0000-0000-000000000001'
  and status = 'in_progress';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$
    select *
    from public.save_attempt_answer(
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and exam_id = '50000000-0000-0000-0000-000000000001'
         and status = 'in_progress'),
      '40000000-0000-0000-0000-000000000001',
      0,
      false
    )
  $$,
  'P0001',
  'Exam time has expired',
  'answers cannot be saved after the database expiry time'
);

select lives_ok(
  $$
    select *
    from public.submit_attempt(
      (select id from public.attempts
       where student_id = '10000000-0000-0000-0000-000000000001'
         and exam_id = '50000000-0000-0000-0000-000000000001'
         and status = 'in_progress')
    )
  $$,
  'an expired attempt can still be safely finalized'
);

select ok(
  (
    select submitted_at <= expires_at and score = 0
    from public.attempts
    where student_id = '10000000-0000-0000-0000-000000000001'
      and exam_id = '50000000-0000-0000-0000-000000000001'
      and submitted_at is not null
    order by started_at desc
    limit 1
  ),
  'submission time is capped at expiry and post-expiry answers do not score'
);

select * from finish();
rollback;
