-- Development-only fictional data for local/disposable test databases.
-- These questions are original examples, not CBSE examination content.
-- Supabase CLI applies this file after migrations when running a database reset.

insert into public.subjects (id, name, slug, sort_order, is_published)
values (
  '90000000-0000-0000-0000-000000000001',
  'Demo Physics',
  'demo-physics',
  1,
  true
)
on conflict (id) do update set
  name = excluded.name,
  slug = excluded.slug,
  sort_order = excluded.sort_order,
  is_published = excluded.is_published;

insert into public.chapters (id, subject_id, name, slug, sort_order, is_published)
values (
  '90000000-0000-0000-0000-000000000002',
  '90000000-0000-0000-0000-000000000001',
  'Measurement and Units',
  'measurement-and-units',
  1,
  true
)
on conflict (id) do update set
  subject_id = excluded.subject_id,
  name = excluded.name,
  slug = excluded.slug,
  sort_order = excluded.sort_order,
  is_published = excluded.is_published;

insert into public.questions (
  id, chapter_id, prompt, options, correct_option, explanation, difficulty, is_active
) values
  (
    '90000000-0000-0000-0000-000000000011',
    '90000000-0000-0000-0000-000000000002',
    'A classroom clock measures a lesson as 45. What is the appropriate unit?',
    '["seconds", "minutes", "kilograms", "metres"]'::jsonb,
    1,
    'A lesson duration is conventionally measured in minutes.',
    'easy',
    true
  ),
  (
    '90000000-0000-0000-0000-000000000012',
    '90000000-0000-0000-0000-000000000002',
    'Which instrument is most suitable for measuring the length of a pencil?',
    '["Thermometer", "Ruler", "Balance", "Stopwatch"]'::jsonb,
    1,
    'A ruler is designed to measure short lengths.',
    'easy',
    true
  ),
  (
    '90000000-0000-0000-0000-000000000013',
    '90000000-0000-0000-0000-000000000002',
    'Which value is written in scientific notation?',
    '["4200", "4.2 × 10³", "42/10", "0.0042"]'::jsonb,
    1,
    'Scientific notation writes a number as a coefficient multiplied by a power of ten.',
    'medium',
    true
  ),
  (
    '90000000-0000-0000-0000-000000000014',
    '90000000-0000-0000-0000-000000000002',
    'If a scale has smallest divisions of 1 millimetre, which reading is most precise?',
    '["12 m", "12.3 cm", "12.30 cm", "12.3000 cm"]'::jsonb,
    2,
    'One millimetre is 0.1 centimetre, so 12.30 cm reflects that precision.',
    'medium',
    true
  ),
  (
    '90000000-0000-0000-0000-000000000015',
    '90000000-0000-0000-0000-000000000002',
    'Which is an SI base unit?',
    '["newton", "joule", "second", "watt"]'::jsonb,
    2,
    'The second is an SI base unit; the others are derived units.',
    'easy',
    true
  )
on conflict (id) do update set
  chapter_id = excluded.chapter_id,
  prompt = excluded.prompt,
  options = excluded.options,
  correct_option = excluded.correct_option,
  explanation = excluded.explanation,
  difficulty = excluded.difficulty,
  is_active = excluded.is_active;

insert into public.exams (
  id, title, description, duration_seconds, is_published, is_premium
) values (
  '90000000-0000-0000-0000-000000000021',
  'Measurement Practice Exam',
  'A fictional five-question development seed exam.',
  900,
  true,
  false
)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  duration_seconds = excluded.duration_seconds,
  is_published = excluded.is_published,
  is_premium = excluded.is_premium;

insert into public.exam_questions (exam_id, question_id, position, marks)
values
  ('90000000-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000011', 1, 1),
  ('90000000-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000012', 2, 1),
  ('90000000-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000013', 3, 1),
  ('90000000-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000014', 4, 1),
  ('90000000-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000015', 5, 1)
on conflict (exam_id, question_id) do update set
  position = excluded.position,
  marks = excluded.marks;
