-- Secure student examination RPCs.
-- These functions are the only student-facing path to question content, attempt
-- mutations, scoring, and post-submission review.

create or replace function public.finalize_attempt(
  p_attempt_id uuid,
  p_submitted_at timestamptz
)
returns public.attempts
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempt public.attempts%rowtype;
  v_score numeric(8,2);
  v_max_score numeric(8,2);
begin
  select *
  into v_attempt
  from public.attempts
  where id = p_attempt_id
  for update;

  if not found then
    raise exception 'Attempt not found' using errcode = 'P0002';
  end if;

  if v_attempt.status = 'submitted' then
    return v_attempt;
  end if;

  select
    coalesce(sum(
      case when answer.selected_option = question.correct_option
        then exam_question.marks
        else 0
      end
    ), 0),
    coalesce(sum(exam_question.marks), 0)
  into v_score, v_max_score
  from public.exam_questions as exam_question
  join public.questions as question on question.id = exam_question.question_id
  left join public.attempt_answers as answer
    on answer.attempt_id = v_attempt.id
   and answer.question_id = exam_question.question_id
  where exam_question.exam_id = v_attempt.exam_id;

  update public.attempts
  set
    status = 'submitted',
    submitted_at = least(p_submitted_at, expires_at),
    score = v_score,
    max_score = v_max_score
  where id = v_attempt.id
  returning * into v_attempt;

  return v_attempt;
end;
$$;

create or replace function public.start_exam(p_exam_id uuid)
returns table (
  attempt_id uuid,
  exam_id uuid,
  title text,
  duration_seconds integer,
  expires_at timestamptz,
  questions jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_exam public.exams%rowtype;
  v_attempt public.attempts%rowtype;
  v_questions jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_exam
  from public.exams
  where id = p_exam_id
    and is_published
    and not is_premium
    and (available_from is null or available_from <= now())
    and (available_until is null or available_until > now());

  if not found then
    raise exception 'Exam is unavailable' using errcode = 'P0002';
  end if;

  -- Serialise start/resume for a student and exam, including across tabs.
  perform pg_advisory_xact_lock(hashtext(auth.uid()::text || ':' || p_exam_id::text));

  select *
  into v_attempt
  from public.attempts
  where student_id = auth.uid()
    and exam_id = p_exam_id
    and status = 'in_progress'
  order by started_at desc
  limit 1
  for update;

  if found and v_attempt.expires_at <= now() then
    perform public.finalize_attempt(v_attempt.id, v_attempt.expires_at);
    v_attempt := null;
  end if;

  if v_attempt.id is null then
    insert into public.attempts (student_id, exam_id, expires_at)
    values (
      auth.uid(),
      p_exam_id,
      now() + make_interval(secs => v_exam.duration_seconds)
    )
    returning * into v_attempt;
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', question.id,
      'position', exam_question.position,
      'prompt', question.prompt,
      'options', question.options,
      'marks', exam_question.marks
    )
    order by exam_question.position
  )
  into v_questions
  from public.exam_questions as exam_question
  join public.questions as question
    on question.id = exam_question.question_id
   and question.is_active
  where exam_question.exam_id = p_exam_id;

  if v_questions is null then
    raise exception 'Exam has no active questions' using errcode = 'P0001';
  end if;

  return query
  select
    v_attempt.id,
    v_exam.id,
    v_exam.title,
    v_exam.duration_seconds,
    v_attempt.expires_at,
    v_questions;
end;
$$;

create or replace function public.save_attempt_answer(
  p_attempt_id uuid,
  p_question_id uuid,
  p_selected_option smallint,
  p_is_marked_for_review boolean
)
returns table (
  question_id uuid,
  selected_option smallint,
  is_marked_for_review boolean,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempt public.attempts%rowtype;
  v_option_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_attempt
  from public.attempts
  where id = p_attempt_id
    and student_id = auth.uid()
  for update;

  if not found then
    raise exception 'Attempt not found' using errcode = 'P0002';
  end if;

  if v_attempt.status <> 'in_progress' then
    raise exception 'Attempt is no longer editable' using errcode = 'P0001';
  end if;

  if v_attempt.expires_at <= now() then
    raise exception 'Exam time has expired' using errcode = 'P0001';
  end if;

  select jsonb_array_length(question.options)
  into v_option_count
  from public.exam_questions as exam_question
  join public.questions as question on question.id = exam_question.question_id
  where exam_question.exam_id = v_attempt.exam_id
    and exam_question.question_id = p_question_id;

  if not found then
    raise exception 'Question is not part of this exam' using errcode = 'P0002';
  end if;

  if p_selected_option is not null
     and (p_selected_option < 0 or p_selected_option >= v_option_count) then
    raise exception 'Selected option is invalid' using errcode = '22023';
  end if;

  return query
  insert into public.attempt_answers as answer (
    attempt_id,
    question_id,
    selected_option,
    is_marked_for_review,
    answered_at
  )
  values (
    v_attempt.id,
    p_question_id,
    p_selected_option,
    coalesce(p_is_marked_for_review, false),
    case when p_selected_option is null then null else now() end
  )
  on conflict (attempt_id, question_id) do update
  set
    selected_option = excluded.selected_option,
    is_marked_for_review = excluded.is_marked_for_review,
    answered_at = case
      when excluded.selected_option is distinct from answer.selected_option
        then excluded.answered_at
      else answer.answered_at
    end
  returning
    answer.question_id,
    answer.selected_option,
    answer.is_marked_for_review,
    answer.updated_at;
end;
$$;

create or replace function public.submit_attempt(p_attempt_id uuid)
returns table (
  attempt_id uuid,
  status public.attempt_status,
  score numeric,
  max_score numeric,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempt public.attempts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_attempt
  from public.attempts
  where id = p_attempt_id
    and student_id = auth.uid()
  for update;

  if not found then
    raise exception 'Attempt not found' using errcode = 'P0002';
  end if;

  v_attempt := public.finalize_attempt(v_attempt.id, now());

  return query
  select
    v_attempt.id,
    v_attempt.status,
    v_attempt.score,
    v_attempt.max_score,
    v_attempt.submitted_at;
end;
$$;

create or replace function public.get_attempt_review(p_attempt_id uuid)
returns table (
  question_id uuid,
  position integer,
  prompt text,
  options jsonb,
  selected_option smallint,
  correct_option smallint,
  is_correct boolean,
  explanation text,
  marks numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_attempt public.attempts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  select *
  into v_attempt
  from public.attempts
  where id = p_attempt_id
    and student_id = auth.uid();

  if not found then
    raise exception 'Attempt not found' using errcode = 'P0002';
  end if;

  if v_attempt.status <> 'submitted' then
    raise exception 'Attempt has not been submitted' using errcode = 'P0001';
  end if;

  return query
  select
    question.id,
    exam_question.position,
    question.prompt,
    question.options,
    answer.selected_option,
    question.correct_option,
    answer.selected_option = question.correct_option,
    question.explanation,
    exam_question.marks
  from public.exam_questions as exam_question
  join public.questions as question on question.id = exam_question.question_id
  left join public.attempt_answers as answer
    on answer.attempt_id = v_attempt.id
   and answer.question_id = question.id
  where exam_question.exam_id = v_attempt.exam_id
  order by exam_question.position;
end;
$$;

revoke all on function public.finalize_attempt(uuid, timestamptz) from public;
revoke all on function public.start_exam(uuid) from public;
revoke all on function public.save_attempt_answer(uuid, uuid, smallint, boolean) from public;
revoke all on function public.submit_attempt(uuid) from public;
revoke all on function public.get_attempt_review(uuid) from public;

grant execute on function public.start_exam(uuid) to authenticated;
grant execute on function public.save_attempt_answer(uuid, uuid, smallint, boolean) to authenticated;
grant execute on function public.submit_attempt(uuid) to authenticated;
grant execute on function public.get_attempt_review(uuid) to authenticated;
