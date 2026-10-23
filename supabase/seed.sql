-- Kavis Study — example data for development (NOT for production users).
-- Fills one existing account with a realistic pharmacy term so every connected web page shows real rows
-- from the database. Same courses and numbers as the old mock data in web/src/api/mock/courses.ts.
--
-- Re-runnable: it first DELETES that account's courses, lessons, exams, timetable and study sessions,
-- then inserts everything again. Dates are relative to today, so the exams are always "next week".
-- Run it with the service role (Supabase SQL editor or the Supabase MCP connector), never from an app.
--
-- Areas still on mock data (cards, quiz, plan, progress details, notifications, assistant) get their
-- example rows here when they are connected.

do $$
declare
  seed_email constant text := 'kiannazari36@gmail.com';
  uid   uuid;
  c     record;
  m     record;
  cid   uuid;
  mid   uuid;
  n     int;
  i     int;
begin
  select id into uid from auth.users where email = seed_email;
  if uid is null then raise exception 'No account with email %', seed_email; end if;

  -- ── Clean the previous example data of this account ──
  delete from public.study_sessions    where user_id = uid;
  delete from public.timetable_entries where user_id = uid;
  delete from public.exam_periods      where user_id = uid;
  delete from public.courses           where user_id = uid;  -- cascades: course_exams; materials keep course_id null …
  delete from public.materials         where user_id = uid;  -- … so delete them too (cascades: reading_progress, content, …)

  -- ── Profile and settings ──
  update public.profiles
     set school = 'Ankara Üniversitesi', department = 'Eczacılık', class_year = 4, onboarding_done = true
   where id = uid;
  update public.user_settings
     set study_days = 5, study_hours = 2, plan_mode = 'aim', content_lang = 'pdf', reader_paper = 'sepia'
   where user_id = uid;

  -- ── Midterm week: starts in 4 days ──
  insert into public.exam_periods (user_id, kind, start_date, end_date)
  values (uid, 'midterm', current_date + 4, current_date + 8);

  -- ── Courses (sort order = exam order), one midterm each ──
  for c in
    select * from (values
      (0, 'Farmakoterapi',            null,             'red'::public.course_color),
      (1, 'Toksikoloji',              null,             'amb'),
      (2, 'Farmasötik Teknoloji III', 'Farm. Tek. III', 'vio'),
      (3, 'Farmakognozi',             null,             'grn'),
      (4, 'Farmasötik Kimya II',      null,             'teal')
    ) as v(ord, name, short_name, color)
  loop
    insert into public.courses (user_id, name, short_name, color, language, term, sort_order)
    values (uid, c.name, c.short_name, c.color, 'tr', '2026–2027 Güz', c.ord)
    returning id into cid;

    insert into public.course_exams (user_id, course_id, kind, exam_date, label)
    values (uid, cid, 'midterm', current_date + 4 + c.ord, null);

    -- Lessons (teacher PDFs) of this course: title, pages, % read, minutes studied.
    for m in
      select * from (values
        (0, 'Hipertansiyon',              48,  62, 160),
        (0, 'Diyabet',                    36,   8,  25),
        (0, 'Kalp Yetmezliği',            40, 100, 190),
        (0, 'Astım ve KOAH',              30,  45,  90),
        (1, 'Organofosfat zehirlenmesi',  28,  80, 120),
        (1, 'Parasetamol toksisitesi',    18, 100,  80),
        (1, 'Ağır metaller',              34,  20,  35),
        (2, 'Tablet formülasyonu',        52, 100, 180),
        (2, 'Film kaplama',               26,  55,  70),
        (2, 'Kapsüller',                  22,   0,   0),
        (3, 'Alkaloitler',                44,  70, 110),
        (3, 'Glikozitler',                30,  30,  40),
        (4, 'Beta-laktam antibiyotikler', 38,  15,  30)
      ) as v(course_ord, title, pages, pct, minutes)
      where v.course_ord = c.ord
    loop
      insert into public.materials (user_id, course_id, kind, title, language, page_count, status, processed_at)
      values (uid, cid, 'pdf', m.title, 'tr', m.pages, 'ready', now() - interval '10 days')
      returning id into mid;

      if m.pct > 0 then
        -- updated_at = last time read: Farmakoterapi most recently, then the others.
        insert into public.reading_progress (user_id, material_id, last_page, pages_read, percent_read, finished_at, updated_at)
        values (uid, mid, greatest(1, round(m.pages * m.pct / 100.0)::int),
                array(select generate_series(1, round(m.pages * m.pct / 100.0)::int)),
                m.pct, case when m.pct = 100 then now() - interval '2 days' end,
                now() - make_interval(hours => c.ord * 6 + length(m.title) % 5));
      end if;

      -- Study time: sessions of about 30 minutes, spread over the last 14 evenings.
      n := ceil(m.minutes / 30.0)::int;
      for i in 1..n loop
        insert into public.study_sessions (user_id, course_id, material_id, activity, started_at, ended_at)
        values (uid, cid, mid, 'read',
                (current_date - ((i * 3 + c.ord + length(m.title)) % 14))::timestamp + time '19:00' + make_interval(mins => (i * 17) % 120),
                (current_date - ((i * 3 + c.ord + length(m.title)) % 14))::timestamp + time '19:00' + make_interval(mins => (i * 17) % 120)
                  + make_interval(mins => (m.minutes / n)));
      end loop;
    end loop;
  end loop;

  -- ── School timetable (Monday = 1) ──
  insert into public.timetable_entries (user_id, course_id, title, weekday, start_time, end_time, room, teacher)
  select uid, co.id, t.title, t.weekday, t.start_time, t.end_time, t.room, t.teacher
  from (values
    ('Farmakoterapi',            'Farmakoterapi',            1, time '09:00', time '10:50', 'Amfi 3',  'Prof. Dr. S. Aydın'),
    ('Toksikoloji',              'Toksikoloji',              2, time '10:00', time '11:50', 'Amfi 1',  'Doç. Dr. M. Kaya'),
    ('Farmasötik Teknoloji III', 'Farm. Tek. III Lab',       3, time '13:00', time '16:50', 'Lab 2',   'Dr. Öğr. Üyesi A. Demir'),
    ('Farmakognozi',             'Farmakognozi',             4, time '09:00', time '10:50', 'Amfi 2',  'Prof. Dr. N. Şahin'),
    ('Farmasötik Kimya II',      'Farmasötik Kimya II',      5, time '11:00', time '12:50', 'Amfi 3',  'Doç. Dr. E. Yılmaz')
  ) as t(course_name, title, weekday, start_time, end_time, room, teacher)
  join public.courses co on co.user_id = uid and co.name = t.course_name;

  -- Inserting 13 lessons raised the trial and monthly counters (database triggers). Example data should not
  -- use up the trial: count one lesson, like a student who uploaded one PDF so far.
  update public.materials set counted_in_trial = false where user_id = uid;
  insert into public.trial_usage (user_id, lessons) values (uid, 1)
    on conflict (user_id) do update set lessons = 1;
  delete from public.usage_monthly where user_id = uid;
end $$;
