-- Behaviour tests: run as superuser; each check prints PASS or FAIL.
\set ON_ERROR_STOP 1
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'a@x', '{"full_name":"Elif","app_lang":"tr"}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@x', '{"name":"Ayşe","app_lang":"zz"}');
select pg_temp.ok((select count(*) from public.profiles) = 2 and (select count(*) from public.user_settings) = 2, 'profile + settings created');
select pg_temp.ok((select app_lang from public.profiles where full_name = 'Ayşe') = 'tr', 'bad app_lang falls back to tr');

-- ── Student A ──
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into public.courses (id, user_id, name, language) values ('10000000-0000-0000-0000-000000000001', auth.uid(), 'Farmakoterapi', 'tr');
insert into public.courses (id, user_id, name) values ('10000000-0000-0000-0000-000000000002', auth.uid(), 'Toksikoloji');
insert into public.materials (id, user_id, course_id, kind, title) values ('20000000-0000-0000-0000-000000000001', auth.uid(), '10000000-0000-0000-0000-000000000001', 'pdf', 'Hipertansiyon');
insert into public.materials (id, user_id, course_id, kind, title) values ('20000000-0000-0000-0000-000000000002', auth.uid(), '10000000-0000-0000-0000-000000000001', 'photo', 'Slaytlar');
select pg_temp.fails($$insert into public.materials (user_id, course_id, kind, title) values (auth.uid(), null, 'pdf', 'Third lesson')$$) as "trial: 3rd lesson blocked";
insert into public.materials (user_id, course_id, linked_material_id, kind, title) values (auth.uid(), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'audio', 'Ders kaydı');
select pg_temp.ok(true, 'audio recording allowed during trial (does not count as lesson)');
select pg_temp.ok((public.access_status()->>'lessons_used')::int = 2 and (public.access_status()->>'premium')::boolean = false, 'access_status: 2 lessons used, not premium');
select pg_temp.fails($$update public.materials set status = 'ready' where id = '20000000-0000-0000-0000-000000000001'$$) as "app cannot set status";
select pg_temp.fails($$insert into public.materials (user_id, kind, title, slow_lane) values (auth.uid(), 'audio', 'x', true)$$) as "app cannot set slow_lane";
select pg_temp.fails($$update public.profiles set trial_started_at = now() + interval '1 year'$$) as "app cannot extend trial";
update public.profiles set full_name = 'Elif Yıldız', department = 'Eczacılık' where id = auth.uid();
select pg_temp.ok((select department from public.profiles) = 'Eczacılık', 'profile edit works');
select pg_temp.ok(public.content_lang_for('10000000-0000-0000-0000-000000000002') = 'tr', 'content lang: pdf default → app lang when course language unknown');
update public.courses set content_lang_override = 'en' where id = '10000000-0000-0000-0000-000000000001';
select pg_temp.ok(public.content_lang_for('10000000-0000-0000-0000-000000000001') = 'en', 'content lang: course override wins');
update public.user_settings set content_lang = 'fa';
select pg_temp.ok(public.content_lang_for('10000000-0000-0000-0000-000000000002') = 'fa', 'content lang: general setting');
select pg_temp.fails($$select public.can_use('upload', '00000000-0000-0000-0000-00000000000b')$$) as "students cannot query other users' access";
select pg_temp.ok(public.can_i('ask') and not public.can_i('share'), 'trial: can ask, cannot share');

-- devices
select pg_temp.ok((public.register_device('iphone-1', 'iphone', 'iPhone 15')->>'ok')::boolean, 'device 1 ok');
select pg_temp.ok((public.register_device('web-1', 'web', 'Web · Chrome')->>'ok')::boolean, 'device 2 ok');
select pg_temp.ok((public.register_device('iphone-1', 'iphone', 'iPhone 15')->>'ok')::boolean, 'same device again ok');
select pg_temp.ok(not (public.register_device('ipad-1', 'ipad', 'iPad Air')->>'ok')::boolean
                  and jsonb_array_length(public.register_device('ipad-1', 'ipad', 'iPad Air')->'devices') = 2, '3rd device refused with list of 2');
select public.sign_out_device((select id from public.user_devices where install_id = 'web-1'));
select pg_temp.ok((public.register_device('ipad-1', 'ipad', 'iPad Air')->>'ok')::boolean, 'after signing one out, 3rd device ok');

-- study data
insert into public.reading_progress (user_id, material_id, last_page, percent_read) values (auth.uid(), '20000000-0000-0000-0000-000000000001', 12, 62);
insert into public.study_sessions (user_id, course_id, material_id, started_at, ended_at) values
  (auth.uid(), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', now() - interval '40 min', now()),
  (auth.uid(), '10000000-0000-0000-0000-000000000001', null, now() - interval '1 day 30 min', now() - interval '1 day'),
  (auth.uid(), null, null, now() - interval '2 days 10 min', now() - interval '2 days');
select pg_temp.ok(public.study_streak() = 3, 'streak = 3 days');
select pg_temp.ok((select minutes from public.course_overview where name = 'Farmakoterapi') = 70
                  and (select lesson_count from public.course_overview where name = 'Farmakoterapi') = 2, 'course_overview minutes + lessons');
insert into public.timetable_entries (user_id, course_id, title, weekday, start_time, room) values (auth.uid(), '10000000-0000-0000-0000-000000000001', 'Farmakoterapi', 1, '09:00', 'Amfi 3');
insert into public.exam_periods (user_id, kind, start_date, end_date) values (auth.uid(), 'midterm', '2026-10-19', '2026-10-23');
insert into storage.objects (bucket_id, name) values ('materials', '00000000-0000-0000-0000-00000000000a/20000000-0000-0000-0000-000000000001/h.pdf');
select pg_temp.fails($$insert into storage.objects (bucket_id, name) values ('materials', '00000000-0000-0000-0000-00000000000b/x/h.pdf')$$) as "storage: other student's folder blocked";
insert into public.material_files (material_id, user_id, storage_path) values ('20000000-0000-0000-0000-000000000001', auth.uid(), '00000000-0000-0000-0000-00000000000a/20000000-0000-0000-0000-000000000001/h.pdf');
insert into public.support_tickets (user_id, category, app_version) values (auth.uid(), 'pdf_upload', '1.0');
select pg_temp.fails($$insert into public.support_messages (ticket_id, user_id, body, from_staff) select id, auth.uid(), 'hi', true from public.support_tickets$$) as "student cannot post as staff";
insert into public.support_messages (ticket_id, user_id, body) select id, auth.uid(), 'PDF yüklenmiyor' from public.support_tickets;
select pg_temp.ok((select number from public.support_tickets) >= 4800, 'support ticket number');

-- ── Student B ──
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select pg_temp.ok((select count(*) from public.courses) = 0 and (select count(*) from public.materials) = 0
                  and (select count(*) from public.course_overview) = 0 and (select count(*) from storage.objects) = 0, 'B sees none of A''s data');
select pg_temp.fails($$insert into public.materials (user_id, course_id, kind, title) values (auth.uid(), '10000000-0000-0000-0000-000000000001', 'pdf', 'x')$$) as "B cannot use A's course";
select pg_temp.fails($$insert into public.reading_progress (user_id, material_id) values (auth.uid(), '20000000-0000-0000-0000-000000000001')$$) as "B cannot attach to A's material";
select pg_temp.fails($$insert into public.courses (user_id, name) values ('00000000-0000-0000-0000-00000000000a', 'x')$$) as "B cannot write as A";
update public.courses set name = 'hacked';  -- affects 0 rows
reset role;
select pg_temp.ok((select count(*) from public.courses where name = 'hacked') = 0, 'B cannot change A''s rows');

-- ── Server side: AI content, premium, trial end ──
set role service_role;
insert into public.material_topics (id, material_id, user_id, title, page_from, page_to, teacher_said_exam)
  values ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'Tiyazid kontrendikasyonları', 14, 14, true);
insert into public.quizzes (id, user_id, course_id, material_id, kind, lang) values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'exam_prep', 'tr');
insert into public.quiz_questions (id, quiz_id, user_id, topic_id, text, options, answer_index) values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-000000000001', 'Gut?', '["a","b"]', 0);
reset role;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into public.quiz_attempts (id, quiz_id, user_id) values ('60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', auth.uid());
select pg_temp.fails($$insert into public.quiz_answers (attempt_id, question_id, user_id, chosen_index, correct) values ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', auth.uid(), 0, true)$$) as "app cannot mark its own answer correct";
insert into public.quiz_answers (attempt_id, question_id, user_id, chosen_index, confidence, hints_used) values ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', auth.uid(), 1, 'sure', 0);
select pg_temp.fails($$update public.quiz_attempts set score = 100$$) as "app cannot set its score";
insert into public.topic_progress (user_id, topic_id, state) values (auth.uid(), '30000000-0000-0000-0000-000000000001', 'weak');
select pg_temp.fails($$update public.topic_progress set mastery = 100$$) as "app cannot set mastery";
reset role;
update public.quiz_answers set correct = false;
set role authenticated;
select pg_temp.ok((select sure_but_wrong from public.topic_mastery) = 1, 'topic_mastery counts confident mistake');
reset role;

-- premium + fair use
set role service_role;
insert into public.subscriptions (user_id, provider, product_id, original_transaction_id, status, started_at, expires_at)
  values ('00000000-0000-0000-0000-00000000000a', 'apple', 'study.kavis.premium.month', 'tx1', 'active', now() - interval '3 days', now() + interval '27 days');
insert into public.materials (user_id, kind, title, created_at)
  select '00000000-0000-0000-0000-00000000000a', 'pdf', 'L' || g, now() from generate_series(1, 39) g;
reset role;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
select pg_temp.ok((public.access_status()->>'premium')::boolean and public.can_i('share'), 'premium: can share');
select pg_temp.ok((public.access_status()->'fair_use'->>'used')::int >= 40, 'fair use counts lessons this period');
insert into public.materials (id, user_id, kind, title) values ('20000000-0000-0000-0000-000000000099', auth.uid(), 'pdf', 'Lesson 42');
select pg_temp.ok((select slow_lane from public.materials where id = '20000000-0000-0000-0000-000000000099'), 'over 40 lessons: still allowed, slow lane');
reset role;

-- trial ended, no premium
update public.profiles set trial_started_at = now() - interval '4 days' where id = '00000000-0000-0000-0000-00000000000b';
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select pg_temp.ok(not public.can_i('upload') and not public.can_i('ask') and not public.can_i('generate')
                  and (public.access_status()->>'trial_ended')::boolean, 'trial ended: upload/ask/generate locked');
select pg_temp.fails($$insert into public.materials (user_id, kind, title) values (auth.uid(), 'pdf', 'x')$$) as "trial ended: upload blocked";
reset role;

-- anon
set role anon;
select pg_temp.fails($$select * from public.profiles$$) as "anon cannot read profiles";
select pg_temp.ok((select count(*) from public.course_catalog) = 0, 'anon can read catalog');
reset role;
