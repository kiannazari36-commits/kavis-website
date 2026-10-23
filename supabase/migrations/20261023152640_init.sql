-- Kavis Study — initial database schema (Supabase, Postgres 15+)
-- Source of truth for features: the final design canvas (Kavis Study) + CLAUDE.md.
-- docs/BACKEND.md explains every table and which screen / API uses it.
--
-- Rules this schema enforces:
--  * Every row belongs to one student (user_id). Row Level Security: a student sees only their own rows.
--  * The teacher's material is never changed: original files stay in Storage; the reading page is derived.
--  * Free trial: 3 days, 2 lessons, 60 assistant questions, 100 pages per lesson.
--    Premium comes only from a verified store purchase (Apple now, Google later) written by the server.
--  * Fair use: Premium, 40 lessons per subscription month; after that lessons are still prepared, just slower.
--  * Max 2 active devices per account; the web counts as one.
--  * Sharing (Premium): only app-made content (summary, cards, quiz), never the original PDF.
--  * AI output, usage counters, subscriptions and shares are written only by the server (service role).

create extension if not exists pgcrypto;

-- ───────────────────────────── Types ─────────────────────────────
create type public.app_lang          as enum ('tr', 'en', 'fa', 'ar');
create type public.content_lang      as enum ('pdf', 'app', 'tr', 'en', 'fa', 'ar');
create type public.app_theme         as enum ('system', 'light', 'dark');
create type public.course_color      as enum ('red', 'amb', 'vio', 'grn', 'teal');
create type public.material_kind     as enum ('pdf', 'photo', 'audio');
create type public.material_status   as enum ('uploaded', 'processing', 'ready', 'needs_ocr', 'too_long', 'failed');
create type public.plan_mode         as enum ('aim', 'own', 'none');
create type public.reader_paper      as enum ('light', 'sepia', 'dark');
create type public.translation_style as enum ('literal', 'natural');
create type public.device_kind       as enum ('iphone', 'ipad', 'android', 'mac', 'web');
create type public.card_rating       as enum ('again', 'hard', 'good');
create type public.quiz_kind         as enum ('section_check', 'lesson_end', 'exam_prep', 'combined', 'placement', 'review', 'style');
create type public.question_kind     as enum ('multiple_choice', 'written');
create type public.confidence        as enum ('sure', 'unsure', 'guess');
create type public.topic_state       as enum ('unknown', 'known', 'weak', 'todo');
create type public.task_status       as enum ('todo', 'done', 'missed', 'moved', 'removed');
create type public.store_provider    as enum ('apple', 'google', 'web');
create type public.sub_status        as enum ('active', 'grace', 'billing_retry', 'expired', 'revoked', 'refunded');
create type public.share_item        as enum ('summary', 'cards', 'quiz');
create type public.annotation_kind   as enum ('highlight', 'note', 'ink');
create type public.exam_kind         as enum ('midterm', 'final', 'makeup', 'quiz', 'other');

create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ═════════════════════════════ ACCOUNTS ═════════════════════════════

-- One row per student, created automatically with the auth user.
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  full_name         text not null default '',
  school            text,
  department        text,                               -- "Eczacılık", "Tıp", …
  class_year        smallint check (class_year between 1 and 8),
  avatar_path       text,                               -- "avatars" bucket
  app_lang          public.app_lang not null default 'tr',
  onboarding_done   boolean not null default false,
  terms_version     text,                               -- accepted terms of use + KVKK notice version
  terms_accepted_at timestamptz,
  trial_started_at  timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Settings saved in the account (web Settings, iOS Settings, Settings design).
create table public.user_settings (
  user_id               uuid primary key references public.profiles(id) on delete cascade,
  app_theme             public.app_theme not null default 'system',
  content_lang          public.content_lang not null default 'pdf',
  translation_langs     public.app_lang[] not null default '{en}',
  translation_style     public.translation_style not null default 'natural',
  plan_mode             public.plan_mode not null default 'aim',
  study_days            smallint not null default 4 check (study_days between 1 and 7),
  study_hours           numeric(3,1) not null default 1.5 check (study_hours between 0.5 and 8),
  time_zone             text not null default 'Europe/Istanbul',
  reader_paper          public.reader_paper not null default 'sepia',
  reader_paper_chosen   boolean not null default false,
  reader_font_size      smallint not null default 20 check (reader_font_size between 12 and 32),
  tts_voice             text not null default 'female' check (tts_voice in ('female', 'male')),
  tts_rate              numeric(3,2) not null default 1.0 check (tts_rate between 0.5 and 2.0),
  push_notifications    boolean not null default true,
  review_reminder       boolean not null default true,     -- "Tekrar günlerinde bildirim gönder"
  notify_time           time not null default '09:00',     -- study / review reminder time
  cheer_notifications   boolean not null default true,
  weekly_report         boolean not null default true,
  -- school timetable reminders (NewSchedule)
  class_remind_day_before  boolean not null default true,
  class_remind_time        time not null default '20:00',
  class_remind_morning     boolean not null default false,
  class_remind_first_class boolean not null default false, -- 1 h before the first class
  class_prep_tip           boolean not null default true,
  offline_mode          boolean not null default false,
  auto_download         boolean not null default true,
  sync                  boolean not null default true,
  updated_at            timestamptz not null default now()
);
create trigger user_settings_touch before update on public.user_settings
  for each row execute function public.touch_updated_at();

-- New auth user → profile + settings. Name/language come from sign-up metadata or Apple/Google.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  lang public.app_lang := 'tr';
begin
  if new.raw_user_meta_data->>'app_lang' in ('tr', 'en', 'fa', 'ar') then
    lang := (new.raw_user_meta_data->>'app_lang')::public.app_lang;
  end if;
  insert into public.profiles (id, full_name, app_lang)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''), lang);
  insert into public.user_settings (user_id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Devices signed in to the account (max 2 active; the web is one device).
create table public.user_devices (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  install_id     text not null,                    -- random id the app keeps per install / browser
  kind           public.device_kind not null,
  name           text not null,                    -- "iPhone 15", "Web · Chrome · macOS"
  session_id     uuid,                             -- auth session, so "sign out" can end it
  app_version    text,
  last_seen_at   timestamptz not null default now(),
  signed_out_at  timestamptz,
  created_at     timestamptz not null default now(),
  unique (user_id, install_id)
);
create index user_devices_active on public.user_devices (user_id) where signed_out_at is null;

create table public.push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  device_id   uuid references public.user_devices(id) on delete cascade,
  platform    text not null check (platform in ('apns', 'fcm', 'webpush')),
  token       text not null unique,
  created_at  timestamptz not null default now()
);
create index push_tokens_user on public.push_tokens (user_id);

-- ═════════════════════════════ COURSES, TERM, TIMETABLE ═════════════════════════════

-- Read-only list for onboarding suggestions ("Bu dönem hangi dersleri alıyorsun?").
create table public.course_catalog (
  id          serial primary key,
  department  text not null,
  name        text not null,
  lang        public.app_lang not null default 'tr',
  sort_order  int not null default 0,
  unique (department, name, lang)
);

create table public.courses (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  name                  text not null,
  short_name            text,
  color                 public.course_color not null default 'red',
  language              public.app_lang,                -- language of the teacher's material
  content_lang_override public.content_lang,            -- per-course; null = general setting
  term                  text,                           -- "2026–2027 Güz"
  started_before        boolean not null default false, -- "Başladı, bazılarını çalıştım" → placement test
  sort_order            int not null default 0,
  archived_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index courses_user on public.courses (user_id);
create trigger courses_touch before update on public.courses
  for each row execute function public.touch_updated_at();

-- Exam week of the term ("Sınav haftanı gir": Vize / Bütünleme, from–to).
create table public.exam_periods (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        public.exam_kind not null default 'midterm',
  start_date  date not null,
  end_date    date not null,
  created_at  timestamptz not null default now(),
  check (end_date >= start_date)
);
create index exam_periods_user on public.exam_periods (user_id, start_date);

-- One exam of one course ("Vize · 19 Ekim").
create table public.course_exams (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  course_id   uuid not null references public.courses(id) on delete cascade,
  kind        public.exam_kind not null default 'midterm',
  exam_date   date not null,
  label       text,
  created_at  timestamptz not null default now()
);
create index course_exams_user_date on public.course_exams (user_id, exam_date);
create index course_exams_course on public.course_exams (course_id);

-- School timetable ("Okul programı"): typed in, or read from a photo / PDF by the server.
create table public.timetable_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  course_id   uuid references public.courses(id) on delete set null,
  title       text not null,                        -- "Farmakoterapi", "Farm. Tek. III Lab"
  weekday     smallint not null check (weekday between 1 and 7),   -- 1 = Monday
  start_time  time not null,
  end_time    time,
  room        text,                                 -- "Amfi 3"
  teacher     text,                                 -- "Prof. Dr. S. Aydın"
  remind      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index timetable_user_day on public.timetable_entries (user_id, weekday, start_time);

-- ═════════════════════════════ MATERIAL (lessons) ═════════════════════════════

-- A lesson the student added: teacher PDF, slide photos or a lecture recording.
create table public.materials (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade,
  course_id           uuid references public.courses(id) on delete set null,
  parent_id           uuid references public.materials(id) on delete cascade, -- part of a long PDF split into chapters
  linked_material_id  uuid references public.materials(id) on delete set null, -- audio recording → its PDF lesson
  kind                public.material_kind not null,
  title               text not null,
  language            public.app_lang,                 -- detected language of the teacher's text
  page_count          int,
  page_from           int,                             -- part chosen when the file is longer than 100 pages
  page_to             int,
  duration_sec        int,                             -- audio length
  status              public.material_status not null default 'uploaded',
  error               text,
  slow_lane           boolean not null default false,  -- fair use: prepared, but after other lessons
  counted_in_trial    boolean not null default false,
  processed_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (page_from is null or page_to is null or (page_to >= page_from and page_to - page_from < 100))
);
create index materials_user_course on public.materials (user_id, course_id);
create index materials_parent on public.materials (parent_id);
create index materials_linked on public.materials (linked_material_id);
create trigger materials_touch before update on public.materials
  for each row execute function public.touch_updated_at();

-- Original files of a lesson (one PDF, several photos, or one audio file) in the "materials" bucket.
create table public.material_files (
  id            uuid primary key default gen_random_uuid(),
  material_id   uuid not null references public.materials(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  storage_path  text not null,                       -- "<user id>/<material id>/<file>"
  mime_type     text,
  size_bytes    bigint,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
create index material_files_material on public.material_files (material_id, sort_order);

-- The interactive reading page (sections → blocks → paragraphs/segments, same shape as ReaderDoc in the apps).
-- The teacher's sentences are copied, never rewritten.
create table public.material_content (
  material_id  uuid primary key references public.materials(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  version      int not null default 1,
  reader_doc   jsonb not null,
  lecture      jsonb,       -- audio: transcript with timestamps, parts matched to PDF pages, "on the exam" hints
  stats        jsonb not null default '{}'::jsonb,   -- { "pages": 36, "terms": 88, "questions": 52, "cards": 30 }
  created_at   timestamptz not null default now()
);
create index material_content_user on public.material_content (user_id);

-- Topics of a lesson with their pages and how much the lecturer stressed them.
create table public.material_topics (
  id                uuid primary key default gen_random_uuid(),
  material_id       uuid not null references public.materials(id) on delete cascade,
  user_id           uuid not null references public.profiles(id) on delete cascade,
  title             text not null,
  page_from         int,
  page_to           int,
  importance        smallint not null default 1 check (importance between 0 and 3),
  teacher_minutes   numeric(5,1),                     -- time the lecturer spent on it (recording)
  teacher_repeats   smallint,
  teacher_said_exam boolean not null default false,   -- "sınavda soruyorum"
  sort_order        int not null default 0
);
create index material_topics_material on public.material_topics (material_id, sort_order);
create index material_topics_user on public.material_topics (user_id);

-- Page text in small pieces, so the assistant can find where to answer from.
create table public.material_chunks (
  id           bigint generated always as identity primary key,
  material_id  uuid not null references public.materials(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  page         int,
  topic_id     uuid references public.material_topics(id) on delete set null,
  source       text not null default 'pdf' check (source in ('pdf', 'ocr', 'transcript')),
  text         text not null,
  search       tsvector generated always as (to_tsvector('simple', text)) stored
);
create index material_chunks_search on public.material_chunks using gin (search);
create index material_chunks_material on public.material_chunks (material_id, page);
create index material_chunks_user on public.material_chunks (user_id);

-- Hard words in the reading page; explanations are made on demand per language.
create table public.material_terms (
  id           uuid primary key default gen_random_uuid(),
  material_id  uuid not null references public.materials(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  term_key     text not null,
  surface      text not null,
  page         int,
  explanation  jsonb not null default '{}'::jsonb,   -- { "tr": "…", "en": "…" }
  molecule     jsonb,                                -- structure for the molecule viewer, if any
  unique (material_id, term_key)
);
create index material_terms_user on public.material_terms (user_id);

-- Words the student tapped ("Dokunduğun kelimeler").
create table public.term_lookups (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  term_id      uuid not null references public.material_terms(id) on delete cascade,
  taps         int not null default 1,
  last_at      timestamptz not null default now(),
  primary key (user_id, term_id)
);
create index term_lookups_term on public.term_lookups (term_id);

-- Saved sentence translations (the same sentence is not paid for twice).
create table public.translations (
  id           uuid primary key default gen_random_uuid(),
  material_id  uuid not null references public.materials(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  source_hash  text not null,
  target_lang  public.app_lang not null,
  style        public.translation_style not null,
  text         text not null,
  created_at   timestamptz not null default now(),
  unique (material_id, source_hash, target_lang, style)
);
create index translations_user on public.translations (user_id);

-- ═════════════════════════════ STUDYING ═════════════════════════════

create table public.reading_progress (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  material_id      uuid not null references public.materials(id) on delete cascade,
  last_page        int not null default 1,
  pages_read       int[] not null default '{}',
  pages_understood int[] not null default '{}',      -- "anladım" in the assistant
  percent_read     smallint not null default 0 check (percent_read between 0 and 100),
  finished_at      timestamptz,
  updated_at       timestamptz not null default now(),
  primary key (user_id, material_id)
);
create index reading_progress_material on public.reading_progress (material_id);
create trigger reading_progress_touch before update on public.reading_progress
  for each row execute function public.touch_updated_at();

-- What the student knows per topic (placement test, quizzes, reviews) and when to review it next.
create table public.topic_progress (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  topic_id         uuid not null references public.material_topics(id) on delete cascade,
  state            public.topic_state not null default 'unknown',
  mastery          smallint check (mastery between 0 and 100),
  next_review_at   date,
  review_count     int not null default 0,
  updated_at       timestamptz not null default now(),
  primary key (user_id, topic_id)
);
create index topic_progress_due on public.topic_progress (user_id, next_review_at);
create index topic_progress_topic on public.topic_progress (topic_id);
create trigger topic_progress_touch before update on public.topic_progress
  for each row execute function public.touch_updated_at();

-- Timer sessions → minutes per day, streak, best hours, weekly chart.
create table public.study_sessions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete set null,
  material_id  uuid references public.materials(id) on delete set null,
  device_id    uuid references public.user_devices(id) on delete set null,
  activity     text not null default 'read'
               check (activity in ('read', 'cards', 'quiz', 'review', 'assistant', 'audio')),
  started_at   timestamptz not null,
  ended_at     timestamptz not null,
  minutes      numeric(6,1) generated always as (round((extract(epoch from (ended_at - started_at)) / 60.0)::numeric, 1)) stored,
  check (ended_at >= started_at and ended_at - started_at < interval '12 hours')
);
create index study_sessions_user_time on public.study_sessions (user_id, started_at);
create index study_sessions_course on public.study_sessions (course_id);
create index study_sessions_material on public.study_sessions (material_id);
create index study_sessions_device on public.study_sessions (device_id);

-- Highlights, notes and pen strokes (the original PDF is never changed).
create table public.annotations (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  material_id  uuid not null references public.materials(id) on delete cascade,
  page         int not null,
  kind         public.annotation_kind not null,
  anchor       jsonb not null default '{}'::jsonb,
  color        text,
  text         text,
  ink_path     text,                                  -- "ink" bucket
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index annotations_material on public.annotations (user_id, material_id, page);
create index annotations_material_fk on public.annotations (material_id);
create trigger annotations_touch before update on public.annotations
  for each row execute function public.touch_updated_at();

-- ═════════════════════════════ GENERATED CONTENT (server writes) ═════════════════════════════

create table public.summaries (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete cascade,
  material_id  uuid references public.materials(id) on delete cascade,
  lang         public.app_lang not null,
  kind         text not null default 'lesson' check (kind in ('lesson', 'exam_prep', 'overall', 'weak')),
  content      jsonb not null,           -- topics by importance, points, page sources, reasons
  created_at   timestamptz not null default now()
);
create index summaries_user on public.summaries (user_id, material_id);
create index summaries_course on public.summaries (course_id);
create index summaries_material on public.summaries (material_id);

create table public.card_decks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  course_id    uuid references public.courses(id) on delete cascade,
  material_id  uuid references public.materials(id) on delete cascade,
  lang         public.app_lang not null,
  title        text,
  created_at   timestamptz not null default now()
);
create index card_decks_user on public.card_decks (user_id);
create index card_decks_course on public.card_decks (course_id);
create index card_decks_material on public.card_decks (material_id);

create table public.flashcards (
  id               uuid primary key default gen_random_uuid(),
  deck_id          uuid not null references public.card_decks(id) on delete cascade,
  user_id          uuid not null references public.profiles(id) on delete cascade,
  topic_id         uuid references public.material_topics(id) on delete set null,
  question         text not null,
  answer           text not null,
  note             text,
  page             int,
  sort_order       int not null default 0,
  from_mistake     boolean not null default false,     -- "Hataları kartlara ekle"
  due_at           timestamptz not null default now(),
  interval_days    numeric(6,2) not null default 0,
  ease             numeric(4,2) not null default 2.5,
  reps             int not null default 0,
  again_count      int not null default 0,
  last_rating      public.card_rating,
  last_reviewed_at timestamptz
);
create index flashcards_due on public.flashcards (user_id, due_at);
create index flashcards_deck on public.flashcards (deck_id, sort_order);
create index flashcards_topic on public.flashcards (topic_id);

-- The lecturer's question style, from samples the student adds ("Soru örneklerim").
create table public.question_samples (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  course_id      uuid not null references public.courses(id) on delete cascade,
  kind           text not null check (kind in ('photo', 'pdf', 'text')),
  title          text,
  storage_path   text,                                 -- "question-samples" bucket
  text           text,
  question_count int,
  created_at     timestamptz not null default now()
);
create index question_samples_user on public.question_samples (user_id);
create index question_samples_course on public.question_samples (course_id);

create table public.teacher_styles (
  course_id        uuid primary key references public.courses(id) on delete cascade,
  user_id          uuid not null references public.profiles(id) on delete cascade,
  distribution     jsonb not null,     -- { "case": 40, "mechanism": 25, "dose": 20, "side_effects": 15 }
  top_topics       jsonb not null default '[]'::jsonb,
  use_in_quizzes   boolean not null default true,
  use_in_cards     boolean not null default true,
  use_in_summaries boolean not null default true,
  analyzed_at      timestamptz not null default now()
);
create index teacher_styles_user on public.teacher_styles (user_id);

create table public.quizzes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  course_id     uuid references public.courses(id) on delete cascade,    -- null = combined exam over all courses
  material_id   uuid references public.materials(id) on delete cascade,
  kind          public.quiz_kind not null,
  lang          public.app_lang not null,
  teacher_style boolean not null default false,
  options       jsonb not null default '{}'::jsonb,   -- { "count": 20, "weak_focus": true }
  created_at    timestamptz not null default now()
);
create index quizzes_user on public.quizzes (user_id, created_at desc);
create index quizzes_course on public.quizzes (course_id);
create index quizzes_material on public.quizzes (material_id);

create table public.quiz_questions (
  id            uuid primary key default gen_random_uuid(),
  quiz_id       uuid not null references public.quizzes(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  topic_id      uuid references public.material_topics(id) on delete set null,
  sort_order    int not null default 0,
  kind          public.question_kind not null default 'multiple_choice',
  style_tag     text,                    -- "case", "mechanism", "dose", "side_effects", "structure"
  text          text not null,
  options       jsonb,                   -- ["…", "…"]
  answer_index  smallint,
  model_answer  text,
  explanation   text,
  source_page   int,
  hints         jsonb not null default '[]'::jsonb,
  molecule      jsonb
);
create index quiz_questions_quiz on public.quiz_questions (quiz_id, sort_order);
create index quiz_questions_user on public.quiz_questions (user_id);
create index quiz_questions_topic on public.quiz_questions (topic_id);

-- Attempts and answers are written by the app; the score is computed by the server.
create table public.quiz_attempts (
  id           uuid primary key default gen_random_uuid(),
  quiz_id      uuid not null references public.quizzes(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  score        numeric(5,2),
  level        text                     -- "Başlangıç" | "Gelişiyor" | "Çok iyi" | "Uzman" (key)
);
create index quiz_attempts_user on public.quiz_attempts (user_id, started_at desc);
create index quiz_attempts_quiz on public.quiz_attempts (quiz_id);

create table public.quiz_answers (
  attempt_id     uuid not null references public.quiz_attempts(id) on delete cascade,
  question_id    uuid not null references public.quiz_questions(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  chosen_index   smallint,
  written_answer text,
  dont_know      boolean not null default false,     -- "Bilmiyorum" (placement)
  hints_used     smallint not null default 0,        -- any hint = half point
  confidence     public.confidence,
  correct        boolean,                            -- set by the server
  ai_feedback    text,                               -- written questions, set by the server
  answered_at    timestamptz not null default now(),
  primary key (attempt_id, question_id)
);
create index quiz_answers_user on public.quiz_answers (user_id);
create index quiz_answers_question on public.quiz_answers (question_id);

-- "Bugünün tekrarı": a short review (summary + cards + questions) on a review day.
create table public.review_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  course_id      uuid references public.courses(id) on delete cascade,
  material_id    uuid references public.materials(id) on delete cascade,
  scheduled_for  date not null,
  minutes        smallint not null default 8,
  content        jsonb not null,          -- topic ids with reasons (exam mistake, lecturer stressed, weak, forgetting), card ids, quiz id
  status         public.task_status not null default 'todo',
  done_at        timestamptz,
  created_at     timestamptz not null default now()
);
create index review_sessions_user_day on public.review_sessions (user_id, scheduled_for);
create index review_sessions_course on public.review_sessions (course_id);
create index review_sessions_material on public.review_sessions (material_id);

-- ═════════════════════════════ ASSISTANT ═════════════════════════════

create table public.assistant_threads (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  course_id   uuid references public.courses(id) on delete set null,     -- null = all my courses
  material_id uuid references public.materials(id) on delete set null,
  mode        text not null default 'chat' check (mode in ('chat', 'teach_back', 'solve_photo', 'voice', 'socratic')),
  title       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index assistant_threads_user on public.assistant_threads (user_id, updated_at desc);
create index assistant_threads_course on public.assistant_threads (course_id);
create index assistant_threads_material on public.assistant_threads (material_id);

create table public.assistant_messages (
  id           uuid primary key default gen_random_uuid(),
  thread_id    uuid not null references public.assistant_threads(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  role         text not null check (role in ('user', 'assistant')),
  content      text not null,
  source_mode  text not null default 'pdf' check (source_mode in ('pdf', 'ai')),
  sources      jsonb not null default '[]'::jsonb,   -- [{ "material_id": "…", "page": 14 }] or recording minute
  outside_pdf  boolean not null default false,
  score        smallint check (score between 0 and 10), -- "Ben anlatayım" grade
  created_at   timestamptz not null default now()
);
create index assistant_messages_thread on public.assistant_messages (thread_id, created_at);
create index assistant_messages_user on public.assistant_messages (user_id);

-- ═════════════════════════════ STUDY PLAN ═════════════════════════════

create table public.study_plans (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  week_start   date not null,           -- Monday
  stage        text not null default 'basic' check (stage in ('basic', 'smart')),
  reasons      jsonb not null default '[]'::jsonb,   -- why the plan looks like this (shown on the plan page)
  generated_at timestamptz not null default now(),
  unique (user_id, week_start)
);

create table public.plan_items (
  id           uuid primary key default gen_random_uuid(),
  plan_id      uuid not null references public.study_plans(id) on delete cascade,
  user_id      uuid not null references public.profiles(id) on delete cascade,
  day          date not null,
  course_id    uuid references public.courses(id) on delete cascade,
  material_id  uuid references public.materials(id) on delete set null,
  kind         text not null check (kind in ('read', 'review', 'quiz', 'cards', 'exam_prep', 'mistakes', 'placement')),
  title        text not null,
  minutes      smallint not null,
  why          text,
  target       text not null default 'reader' check (target in ('reader', 'quiz', 'cards', 'review', 'exam_prep')),
  status       public.task_status not null default 'todo',
  sort_order   int not null default 0,
  done_at      timestamptz
);
create index plan_items_user_day on public.plan_items (user_id, day);
create index plan_items_plan on public.plan_items (plan_id);
create index plan_items_course on public.plan_items (course_id);
create index plan_items_material on public.plan_items (material_id);

-- ═════════════════════════════ NOTIFICATIONS ═════════════════════════════

create table public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  kind           text not null,      -- 'study_1h_before', 'start_now', 'review_day', 'streak', 'lesson_ready',
                                     -- 'exam_result', 'weekly_report', 'class_tomorrow', 'cheer', 'trial_ending', 'share_received'
  title          text not null,
  body           text,
  data           jsonb not null default '{}'::jsonb,   -- deep link target
  send_at        timestamptz not null default now(),
  sent_at        timestamptz,
  snoozed_until  timestamptz,
  read_at        timestamptz,
  created_at     timestamptz not null default now()
);
create index notifications_user on public.notifications (user_id, created_at desc);
create index notifications_due on public.notifications (send_at) where sent_at is null;

-- ═════════════════════════════ PREMIUM, TRIAL, USAGE ═════════════════════════════

-- Store subscriptions, written ONLY by the server after checking Apple (and later Google).
create table public.subscriptions (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.profiles(id) on delete cascade,
  provider                 public.store_provider not null,
  product_id               text not null,          -- 'study.kavis.premium.year' | '.term' | '.month'
  original_transaction_id  text not null,
  status                   public.sub_status not null,
  started_at               timestamptz not null default now(),   -- fair-use month starts on this day
  expires_at               timestamptz,
  environment              text not null default 'production' check (environment in ('production', 'sandbox')),
  raw                      jsonb,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (provider, original_transaction_id)
);
create index subscriptions_user on public.subscriptions (user_id);
create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();

-- Lifetime trial counters (the trial happens once per account).
create table public.trial_usage (
  user_id              uuid primary key references public.profiles(id) on delete cascade,
  lessons              int not null default 0,
  assistant_questions  int not null default 0
);

-- AI cost and use per month, for cost limits. Written ONLY by the server.
create table public.usage_monthly (
  user_id              uuid not null references public.profiles(id) on delete cascade,
  month                date not null,          -- first day of the month
  lessons              int not null default 0,
  assistant_questions  int not null default 0,
  generations          int not null default 0,
  input_tokens         bigint not null default 0,
  output_tokens        bigint not null default 0,
  cost_usd             numeric(10,4) not null default 0,
  primary key (user_id, month)
);

-- ═════════════════════════════ SHARING ═════════════════════════════

create table public.shares (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  material_id  uuid not null references public.materials(id) on delete cascade,
  items        public.share_item[] not null check (cardinality(items) > 0),
  opens        int not null default 0,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);
create index shares_user on public.shares (user_id);
create index shares_material on public.shares (material_id);

-- The receiver's inbox ("Ders gelen kutunda bekliyor · Premium olunca açılır").
create table public.share_receipts (
  share_id         uuid not null references public.shares(id) on delete cascade,
  receiver_id      uuid not null references public.profiles(id) on delete cascade,
  received_at      timestamptz not null default now(),
  opened_at        timestamptz,
  copied_material_id uuid references public.materials(id) on delete set null,  -- copy added to the receiver's courses
  primary key (share_id, receiver_id)
);
create index share_receipts_receiver on public.share_receipts (receiver_id);
create index share_receipts_material on public.share_receipts (copied_material_id);

-- ═════════════════════════════ SUPPORT AND PRIVACY ═════════════════════════════

create table public.support_tickets (
  id           uuid primary key default gen_random_uuid(),
  number       bigint generated always as identity (start with 4800) unique,  -- "#4821"
  user_id      uuid not null references public.profiles(id) on delete cascade,
  category     text not null check (category in ('app_bug', 'pdf_upload', 'assistant_wrong', 'account_payment', 'other')),
  status       text not null default 'open' check (status in ('open', 'answered', 'closed')),
  app_version  text,
  device       text,
  last_screen  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index support_tickets_user on public.support_tickets (user_id, created_at desc);
create trigger support_tickets_touch before update on public.support_tickets
  for each row execute function public.touch_updated_at();

create table public.support_messages (
  id              uuid primary key default gen_random_uuid(),
  ticket_id       uuid not null references public.support_tickets(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,  -- ticket owner
  from_staff      boolean not null default false,
  body            text not null,
  attachment_path text,                                -- "support" bucket (screenshot)
  created_at      timestamptz not null default now()
);
create index support_messages_ticket on public.support_messages (ticket_id, created_at);
create index support_messages_user on public.support_messages (user_id);

-- "Hesap bilgilerimi iste" and "Hesabı sil" (email confirmation; deletion after 30 days).
create table public.account_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  kind          text not null check (kind in ('export', 'delete')),
  status        text not null default 'pending' check (status in ('pending', 'confirmed', 'done', 'cancelled')),
  scheduled_for timestamptz,
  created_at    timestamptz not null default now(),
  done_at       timestamptz
);
create index account_requests_user on public.account_requests (user_id);

-- ═════════════════════════════ ACCESS FUNCTIONS ═════════════════════════════

create or replace function public.is_premium(uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = uid
      and s.status in ('active', 'grace', 'billing_retry')
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

-- Premium fair use: lessons added in the current subscription month (starts on the purchase day).
create or replace function public.fair_use(uid uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  anchor  timestamptz;
  d       int;
  pstart  date;
  used    int;
  today   date := current_date;
begin
  select min(started_at) into anchor from public.subscriptions s
   where s.user_id = uid and s.status in ('active', 'grace', 'billing_retry')
     and (s.expires_at is null or s.expires_at > now());
  if anchor is null then return null; end if;
  d := extract(day from anchor)::int;
  pstart := make_date(extract(year from today)::int, extract(month from today)::int,
                      least(d, extract(day from (date_trunc('month', today) + interval '1 month - 1 day'))::int));
  if pstart > today then
    pstart := (date_trunc('month', today) - interval '1 month')::date;
    pstart := make_date(extract(year from pstart)::int, extract(month from pstart)::int,
                        least(d, extract(day from (date_trunc('month', pstart) + interval '1 month - 1 day'))::int));
  end if;
  select count(*) into used from public.materials m
   where m.user_id = uid and m.parent_id is null and m.kind in ('pdf', 'photo') and m.created_at >= pstart;
  return jsonb_build_object('used', used, 'limit', 40, 'slow', used >= 40,
                            'period_start', pstart, 'resets_on', (pstart + interval '1 month')::date);
end $$;

-- Everything the apps need for the trial card, locks and fair-use notice.
create or replace function public.access_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid     uuid := auth.uid();
  started timestamptz;
  t       record;
  prem    boolean;
begin
  if uid is null then return null; end if;
  select trial_started_at into started from public.profiles where id = uid;
  select coalesce(max(lessons), 0) as lessons, coalesce(max(assistant_questions), 0) as qs
    into t from public.trial_usage where user_id = uid;
  prem := public.is_premium(uid);
  return jsonb_build_object(
    'premium',        prem,
    'trial_ends_at',  started + interval '3 days',
    'trial_ended',    now() >= started + interval '3 days',
    'days_left',      greatest(0, ceil(extract(epoch from (started + interval '3 days' - now())) / 86400))::int,
    'lessons_used',   t.lessons,
    'questions_used', t.qs,
    'limits',         jsonb_build_object('days', 3, 'lessons', 2, 'questions', 60, 'pages_per_lesson', 100),
    'fair_use',       case when prem then public.fair_use(uid) end
  );
end $$;

-- Can this student do this now? feature: upload | ask | generate | share
create or replace function public.can_use(feature text, uid uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  started timestamptz;
  t record;
begin
  if uid is null then return false; end if;
  if public.is_premium(uid) then return true; end if;
  if feature = 'share' then return false; end if;
  select trial_started_at into started from public.profiles where id = uid;
  if started is null or now() >= started + interval '3 days' then return false; end if;
  select coalesce(max(lessons), 0) as lessons, coalesce(max(assistant_questions), 0) as qs
    into t from public.trial_usage where user_id = uid;
  return case feature
    when 'upload'   then t.lessons < 2
    when 'ask'      then t.qs < 60
    when 'generate' then true
    else false
  end;
end $$;

-- Wrapper the apps call (uses the signed-in student).
create or replace function public.can_i(feature text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.can_use(feature, auth.uid());
$$;

-- When a lesson is added: mark the fair-use slow lane (before insert, counts not yet raised) …
create or replace function public.on_material_flags() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.parent_id is null and new.kind in ('pdf', 'photo') then
    if public.is_premium(new.user_id) then
      new.slow_lane := coalesce((public.fair_use(new.user_id)->>'used')::int, 0) >= 40;
      new.counted_in_trial := false;
    else
      new.slow_lane := false;
      new.counted_in_trial := true;
    end if;
  end if;
  return new;
end $$;
create trigger materials_flags before insert on public.materials
  for each row execute function public.on_material_flags();

-- … then count it for the trial and the month (after the access check has passed).
create or replace function public.on_material_count() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.parent_id is null and new.kind in ('pdf', 'photo') then
    insert into public.usage_monthly (user_id, month, lessons)
    values (new.user_id, date_trunc('month', now())::date, 1)
    on conflict (user_id, month) do update set lessons = public.usage_monthly.lessons + 1;
    if new.counted_in_trial then
      insert into public.trial_usage (user_id, lessons) values (new.user_id, 1)
      on conflict (user_id) do update set lessons = public.trial_usage.lessons + 1;
    end if;
  end if;
  return new;
end $$;
create trigger materials_count after insert on public.materials
  for each row execute function public.on_material_count();

-- Called after sign-in. Registers this device; if 2 other devices are active, returns them
-- so the student can choose one to sign out (this device is not registered yet).
create or replace function public.register_device(p_install_id text, p_kind public.device_kind, p_name text, p_app_version text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  others jsonb;
  dev uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select id into dev from public.user_devices
   where user_id = uid and install_id = p_install_id and signed_out_at is null;
  if dev is null then
    select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'kind', kind, 'last_seen_at', last_seen_at)
                              order by last_seen_at desc), '[]'::jsonb)
      into others
      from public.user_devices where user_id = uid and signed_out_at is null;
    if jsonb_array_length(others) >= 2 then
      return jsonb_build_object('ok', false, 'devices', others);
    end if;
  end if;
  insert into public.user_devices (user_id, install_id, kind, name, app_version, last_seen_at, signed_out_at)
  values (uid, p_install_id, p_kind, left(p_name, 80), p_app_version, now(), null)
  on conflict (user_id, install_id)
    do update set kind = excluded.kind, name = excluded.name, app_version = excluded.app_version,
                  last_seen_at = now(), signed_out_at = null
  returning id into dev;
  return jsonb_build_object('ok', true, 'device_id', dev);
end $$;

-- Signs out one of the student's devices (the edge function "sign-out-device" also ends its auth session).
create or replace function public.sign_out_device(p_device_id uuid) returns boolean
language sql security definer set search_path = '' as $$
  with u as (
    update public.user_devices set signed_out_at = now()
     where id = p_device_id and user_id = auth.uid() and signed_out_at is null
    returning 1)
  select exists (select 1 from u);
$$;

-- Content language for a course: course setting wins, then the general setting.
create or replace function public.content_lang_for(p_course_id uuid) returns public.app_lang
language sql stable security definer set search_path = '' as $$
  select case coalesce(c.content_lang_override, s.content_lang)
           when 'pdf' then coalesce(c.language, p.app_lang)
           when 'app' then p.app_lang
           else (coalesce(c.content_lang_override, s.content_lang))::text::public.app_lang
         end
  from public.courses c
  join public.profiles p on p.id = c.user_id
  join public.user_settings s on s.user_id = c.user_id
  where c.id = p_course_id and c.user_id = auth.uid();
$$;

-- Records a tap on a hard word.
create or replace function public.tap_term(p_term_id uuid) returns void
language sql security definer set search_path = '' as $$
  insert into public.term_lookups (user_id, term_id)
  select auth.uid(), t.id from public.material_terms t where t.id = p_term_id and t.user_id = auth.uid()
  on conflict (user_id, term_id) do update set taps = public.term_lookups.taps + 1, last_at = now();
$$;

-- Days in a row with at least 5 minutes of study, ending today or yesterday (student's time zone).
create or replace function public.study_streak() returns int
language plpgsql stable security definer set search_path = '' as $$
declare
  tz text;
  d date;
  n int := 0;
begin
  select time_zone into tz from public.user_settings where user_id = auth.uid();
  tz := coalesce(tz, 'Europe/Istanbul');
  d := (now() at time zone tz)::date;
  if not exists (select 1 from public.study_sessions s where s.user_id = auth.uid()
                 and (s.started_at at time zone tz)::date = d
                 group by 1 having sum(s.minutes) >= 5) then
    d := d - 1;
  end if;
  loop
    exit when not exists (select 1 from public.study_sessions s where s.user_id = auth.uid()
                          and (s.started_at at time zone tz)::date = d
                          group by 1 having sum(s.minutes) >= 5);
    n := n + 1;
    d := d - 1;
  end loop;
  return n;
end $$;

-- ═════════════════════════════ VIEWS FOR THE SCREENS ═════════════════════════════
-- security_invoker: views follow the caller's Row Level Security.

-- Course card / folder header: lessons, pages, % read, minutes, next exam.
create or replace view public.course_overview with (security_invoker = true) as
select c.id, c.user_id, c.name, c.short_name, c.color, c.language, c.sort_order,
       (select count(*) from public.materials m where m.course_id = c.id and m.parent_id is null and m.kind in ('pdf', 'photo')) as lesson_count,
       (select coalesce(sum(coalesce(m.page_to - m.page_from + 1, m.page_count)), 0) from public.materials m
         where m.course_id = c.id and m.kind in ('pdf', 'photo')) as pages,
       (select coalesce(round(avg(coalesce(rp.percent_read, 0))), 0)::int from public.materials m
          left join public.reading_progress rp on rp.material_id = m.id and rp.user_id = c.user_id
         where m.course_id = c.id and m.kind in ('pdf', 'photo')) as percent_read,
       (select coalesce(sum(ss.minutes), 0) from public.study_sessions ss where ss.course_id = c.id) as minutes,
       (select min(e.exam_date) from public.course_exams e where e.course_id = c.id and e.exam_date >= current_date) as next_exam
from public.courses c
where c.archived_at is null;

-- Minutes per day (weekly chart, calendar).
create or replace view public.daily_minutes with (security_invoker = true) as
select user_id, (started_at at time zone 'Europe/Istanbul')::date as day, sum(minutes) as minutes
from public.study_sessions
group by user_id, (started_at at time zone 'Europe/Istanbul')::date;

-- Weak topics and confident mistakes from quiz answers.
create or replace view public.topic_mastery with (security_invoker = true) as
select a.user_id, t.material_id, qq.topic_id, t.title,
       count(*)                                                        as answered,
       round(100.0 * avg(case when a.correct then case when a.hints_used > 0 then 0.5 else 1 end else 0 end))::int as mastery,
       count(*) filter (where a.confidence = 'sure' and a.correct = false) as sure_but_wrong
from public.quiz_answers a
join public.quiz_questions qq on qq.id = a.question_id
join public.material_topics t on t.id = qq.topic_id
group by a.user_id, t.material_id, qq.topic_id, t.title;

-- ═════════════════════════════ ROW LEVEL SECURITY ═════════════════════════════

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_settings','user_devices','push_tokens','course_catalog','courses','exam_periods','course_exams',
    'timetable_entries','materials','material_files','material_content','material_topics','material_chunks',
    'material_terms','term_lookups','translations','reading_progress','topic_progress','study_sessions','annotations',
    'summaries','card_decks','flashcards','question_samples','teacher_styles','quizzes','quiz_questions',
    'quiz_attempts','quiz_answers','review_sessions','assistant_threads','assistant_messages','study_plans',
    'plan_items','notifications','subscriptions','trial_usage','usage_monthly','shares','share_receipts',
    'support_tickets','support_messages','account_requests']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- profiles (key is id). trial_started_at and terms_* are set by the server.
create policy "own profile read"   on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name, school, department, class_year, avatar_path, app_lang, onboarding_done) on public.profiles to authenticated;

-- Read-only for students (written by the server).
do $$
declare t text;
begin
  foreach t in array array[
    'user_devices','material_content','material_topics','material_chunks','material_terms','translations',
    'summaries','card_decks','quizzes','quiz_questions','assistant_threads','assistant_messages','study_plans',
    'subscriptions','trial_usage','usage_monthly','shares','account_requests','term_lookups']
  loop
    execute format('create policy "own rows read" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('revoke insert, update, delete on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- Full access to own rows.
do $$
declare t text;
begin
  foreach t in array array[
    'user_settings','push_tokens','courses','exam_periods','course_exams','timetable_entries','reading_progress',
    'study_sessions','annotations','question_samples','quiz_attempts']
  loop
    execute format('create policy "own rows read" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy "own rows insert" on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t);
    execute format('create policy "own rows update" on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
    execute format('create policy "own rows delete" on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t);
  end loop;
end $$;
revoke insert, delete on public.user_settings from authenticated;      -- created with the profile
-- quiz attempts: the app starts and finishes them; score and level are computed by the server.
revoke insert, update on public.quiz_attempts from authenticated;
grant insert (id, quiz_id, user_id, started_at) on public.quiz_attempts to authenticated;
grant update (finished_at) on public.quiz_attempts to authenticated;

-- Child rows must point to the student's own parent rows.
create or replace function public.owns_course(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cid is null or exists (select 1 from public.courses where id = cid and user_id = auth.uid());
$$;
create or replace function public.owns_material(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select mid is null or exists (select 1 from public.materials where id = mid and user_id = auth.uid());
$$;
create or replace function public.owns_quiz(qid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.quizzes where id = qid and user_id = auth.uid());
$$;
create policy "own parents" on public.course_exams      as restrictive for all to authenticated using (true) with check (public.owns_course(course_id));
create policy "own parents" on public.timetable_entries as restrictive for all to authenticated using (true) with check (public.owns_course(course_id));
create policy "own parents" on public.question_samples  as restrictive for all to authenticated using (true) with check (public.owns_course(course_id));
create policy "own parents" on public.reading_progress  as restrictive for all to authenticated using (true) with check (public.owns_material(material_id));
create policy "own parents" on public.annotations       as restrictive for all to authenticated using (true) with check (public.owns_material(material_id));
create policy "own parents" on public.study_sessions    as restrictive for all to authenticated using (true)
  with check (public.owns_course(course_id) and public.owns_material(material_id));
create policy "own parents" on public.quiz_attempts     as restrictive for all to authenticated using (true) with check (public.owns_quiz(quiz_id));

-- materials: the app creates the lesson when it uploads (only if allowed); status/content are the server's.
create policy "own rows read"   on public.materials for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.materials for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'uploaded' and parent_id is null
              and public.owns_course(course_id) and public.owns_material(linked_material_id)
              and (kind = 'audio' or public.can_i('upload')));
create policy "own rows update" on public.materials for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and public.owns_course(course_id));
create policy "own rows delete" on public.materials for delete to authenticated using (user_id = (select auth.uid()));
revoke insert, update on public.materials from authenticated;
grant insert (id, user_id, course_id, linked_material_id, kind, title, page_from, page_to) on public.materials to authenticated;
grant update (title, course_id, page_from, page_to) on public.materials to authenticated;

create policy "own rows read"   on public.material_files for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.material_files for insert to authenticated
  with check (user_id = (select auth.uid()) and public.owns_material(material_id)
              and split_part(storage_path, '/', 1) = (select auth.uid())::text);
revoke update, delete on public.material_files from authenticated;

-- topic_progress: the app updates state / review date (placement, "biliyorum"); mastery is the server's.
create policy "own rows read"   on public.topic_progress for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.topic_progress for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.material_topics t where t.id = topic_id and t.user_id = (select auth.uid())));
create policy "own rows update" on public.topic_progress for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.topic_progress from authenticated;
grant insert (user_id, topic_id, state, next_review_at) on public.topic_progress to authenticated;
grant update (state, next_review_at) on public.topic_progress to authenticated;

-- quiz answers: the app writes the choice; correctness and AI feedback are the server's.
create policy "own rows read"   on public.quiz_answers for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.quiz_answers for insert to authenticated
  with check (user_id = (select auth.uid())
              and exists (select 1 from public.quiz_attempts a where a.id = attempt_id and a.user_id = (select auth.uid()) and a.finished_at is null));
revoke insert, update, delete on public.quiz_answers from authenticated;
grant insert (attempt_id, question_id, user_id, chosen_index, written_answer, dont_know, hints_used, confidence) on public.quiz_answers to authenticated;

-- flashcards: the app updates only the review state.
create policy "own rows read"   on public.flashcards for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows update" on public.flashcards for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.flashcards from authenticated;
grant update (due_at, interval_days, ease, reps, again_count, last_rating, last_reviewed_at) on public.flashcards to authenticated;

-- teacher style switches.
create policy "own rows read"   on public.teacher_styles for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows update" on public.teacher_styles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.teacher_styles from authenticated;
grant update (use_in_quizzes, use_in_cards, use_in_summaries) on public.teacher_styles to authenticated;

-- plan items and review sessions: done / postponed / removed.
create policy "own rows read"   on public.plan_items for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows update" on public.plan_items for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.plan_items from authenticated;
grant update (status, done_at, day) on public.plan_items to authenticated;

create policy "own rows read"   on public.review_sessions for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows update" on public.review_sessions for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.review_sessions from authenticated;
grant update (status, done_at, scheduled_for) on public.review_sessions to authenticated;

-- notifications: read, mark as read, snooze.
create policy "own rows read"   on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows update" on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.notifications from authenticated;
grant update (read_at, snoozed_until) on public.notifications to authenticated;

-- share inbox: the receiver reads their receipts.
create policy "own receipts read" on public.share_receipts for select to authenticated using (receiver_id = (select auth.uid()));
revoke insert, update, delete on public.share_receipts from anon, authenticated;

-- support: the student opens tickets and writes messages; staff replies come from the server.
create policy "own rows read"   on public.support_tickets for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.support_tickets for insert to authenticated with check (user_id = (select auth.uid()) and status = 'open');
revoke insert, update, delete on public.support_tickets from authenticated;
grant insert (id, user_id, category, app_version, device, last_screen) on public.support_tickets to authenticated;
create policy "own rows read"   on public.support_messages for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.support_messages for insert to authenticated
  with check (user_id = (select auth.uid()) and from_staff = false
              and exists (select 1 from public.support_tickets t where t.id = ticket_id and t.user_id = (select auth.uid())));
revoke insert, update, delete on public.support_messages from authenticated;
grant insert (id, ticket_id, user_id, body, attachment_path) on public.support_messages to authenticated;

-- catalog: readable by everyone.
create policy "catalog read" on public.course_catalog for select to anon, authenticated using (true);
revoke insert, update, delete on public.course_catalog from anon, authenticated;

-- Nothing for anonymous users except the catalog.
revoke all on all tables in schema public from anon;
grant select on public.course_catalog to anon;

-- Functions: only signed-in students may call the public ones.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.access_status() to authenticated;
grant execute on function public.can_i(text) to authenticated;
grant execute on function public.register_device(text, public.device_kind, text, text) to authenticated;
grant execute on function public.sign_out_device(uuid) to authenticated;
grant execute on function public.content_lang_for(uuid) to authenticated;
grant execute on function public.tap_term(uuid) to authenticated;
grant execute on function public.study_streak() to authenticated;
-- used inside policies, so the student's role needs them too (they only answer about the caller)
grant execute on function public.owns_course(uuid), public.owns_material(uuid), public.owns_quiz(uuid) to authenticated;
-- can_use / is_premium / fair_use take any user id, so only the server (service role) may call them directly.
grant execute on all functions in schema public to service_role;

-- ═════════════════════════════ STORAGE (private buckets) ═════════════════════════════
-- Files live under "<user id>/..." so a student reaches only their own folder.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('materials', 'materials', false, 104857600,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/webp',
              'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/mpeg', 'audio/wav', 'audio/aac']),
       ('avatars', 'avatars', false, 5242880, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
       ('question-samples', 'question-samples', false, 20971520,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/webp']),
       ('ink', 'ink', false, 5242880, array['application/json', 'image/png']),
       ('support', 'support', false, 10485760, array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do nothing;

create policy "own files read" on storage.objects for select to authenticated
  using (bucket_id in ('materials', 'avatars', 'question-samples', 'ink', 'support')
         and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own files insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('materials', 'avatars', 'question-samples', 'ink', 'support')
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own files update" on storage.objects for update to authenticated
  using (bucket_id in ('avatars', 'ink') and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own files delete" on storage.objects for delete to authenticated
  using (bucket_id in ('materials', 'avatars', 'question-samples', 'ink')
         and (storage.foldername(name))[1] = (select auth.uid())::text);
