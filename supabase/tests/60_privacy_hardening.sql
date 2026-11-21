-- Behaviour tests: privacy hardening (migration 20261121120000). Run in a fresh database after 10..50.
\set ON_ERROR_STOP 1
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', 'f1@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000f2', 'f2@x', '{"app_lang":"tr"}');
insert into public.courses (id, user_id, name) values
  ('f0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'c1');

-- ── #1 audio lessons need the right to record (trial running: yes; trial over: no) ──
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
insert into public.materials (user_id, course_id, kind, title) values ('00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'audio', 'rec during trial');
select pg_temp.ok(true, 'audio lesson allowed while the trial runs');
reset role;
update public.profiles set trial_started_at = now() - interval '10 days' where id = '00000000-0000-0000-0000-0000000000f1';
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
select pg_temp.fails($$insert into public.materials (user_id, course_id, kind, title) values ('00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'audio', 'spam')$$) as "audio lesson refused after the trial";
reset role;

-- ── #1 storage quota ──
insert into storage.objects (bucket_id, name, owner, metadata) values
  ('materials', '00000000-0000-0000-0000-0000000000f1/big.pdf', null, '{"size": 600000000}');
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
select pg_temp.fails($$insert into storage.objects (bucket_id, name, owner) values ('ink', '00000000-0000-0000-0000-0000000000f1/p.json', null)$$) as "upload refused over the 500 MB quota (not premium)";
reset role;
insert into public.subscriptions (user_id, provider, product_id, original_transaction_id, status, expires_at)
  values ('00000000-0000-0000-0000-0000000000f1', 'apple', 'study.kavis.premium.year', 'tx-f1', 'active', now() + interval '200 days');
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
insert into storage.objects (bucket_id, name, owner) values ('ink', '00000000-0000-0000-0000-0000000000f1/p.json', null);
select pg_temp.ok(true, 'Premium has a 5 GB quota: the same upload passes');
select pg_temp.fails($$insert into storage.objects (bucket_id, name, owner) values ('ink', '00000000-0000-0000-0000-0000000000f2/p.json', null)$$) as "cannot upload into another student's folder";
reset role;
-- small bucket count limit
insert into storage.objects (bucket_id, name, metadata) select 'avatars', '00000000-0000-0000-0000-0000000000f1/a' || g, '{"size": 10}' from generate_series(1, 10) g;
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f1';
select pg_temp.fails($$insert into storage.objects (bucket_id, name, owner) values ('avatars', '00000000-0000-0000-0000-0000000000f1/a11', null)$$) as "avatars bucket holds at most 10 files";
reset role;

-- ── #8 paths ──
insert into public.materials (id, user_id, course_id, kind, title) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'pdf', 'p');
select pg_temp.fails($$insert into public.material_files (material_id, user_id, storage_path) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f1/../00000000-0000-0000-0000-0000000000f2/x.pdf')$$) as "material_files: .. refused";
select pg_temp.fails($$insert into public.material_files (material_id, user_id, storage_path) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f2/x.pdf')$$) as "material_files: other student's folder refused";
insert into public.material_files (material_id, user_id, storage_path) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f1/f1000000-0000-0000-0000-000000000001/Ders notu (1).pdf');
select pg_temp.ok(true, 'material_files: a normal path with spaces passes');
select pg_temp.fails($$insert into public.question_samples (user_id, course_id, kind, storage_path) values ('00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'pdf', '00000000-0000-0000-0000-0000000000f2/x.pdf')$$) as "question_samples: other folder refused";
select pg_temp.fails($$insert into public.question_samples (user_id, course_id, kind, storage_path) values ('00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'pdf', 'x/../y.pdf')$$) as "question_samples: .. refused";
insert into public.question_samples (user_id, course_id, kind, storage_path) values ('00000000-0000-0000-0000-0000000000f1', 'f0000000-0000-0000-0000-000000000001', 'pdf', '00000000-0000-0000-0000-0000000000f1/s1.pdf');
select pg_temp.ok(true, 'question_samples: own path passes');
insert into public.support_tickets (id, user_id, category) values ('f2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'other');
select pg_temp.fails($$insert into public.support_messages (ticket_id, user_id, body, attachment_path) values ('f2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'hi', '00000000-0000-0000-0000-0000000000f2/shot.png')$$) as "support_messages: other folder refused";
select pg_temp.fails($$update public.profiles set avatar_path = '../x.png' where id = '00000000-0000-0000-0000-0000000000f1'$$) as "profiles.avatar_path: bad path refused";

-- ── #4 record_consent ──
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f2';
select pg_temp.fails($$select public.record_consent('2026-11', false, true)$$) as "record_consent: adult=false refused";
select pg_temp.fails($$select public.record_consent('', true, true)$$) as "record_consent: empty version refused";
select public.record_consent('2026-11', true, false);
select pg_temp.ok((select terms_version = '2026-11' and terms_accepted_at is not null and adult_confirmed_at is not null and ai_consent_at is null from public.profiles where id = '00000000-0000-0000-0000-0000000000f2'), 'record_consent writes terms + age, no AI consent when false');
select public.record_consent('2026-11', true, true);
select pg_temp.ok((select ai_consent_at is not null from public.profiles where id = '00000000-0000-0000-0000-0000000000f2'), 'record_consent writes the AI consent');
select public.record_consent('2026-12', true, false);
select pg_temp.ok((select ai_consent_at is not null and terms_version = '2026-12' from public.profiles where id = '00000000-0000-0000-0000-0000000000f2'), 'p_ai=false keeps an earlier AI consent');
select pg_temp.fails($$update public.profiles set adult_confirmed_at = now() where id = auth.uid()$$) as "student cannot write adult_confirmed_at directly";
reset role;
set role anon;
select pg_temp.fails($$select public.record_consent('x', true, true)$$) as "anon cannot call record_consent";
reset role;
select pg_temp.ok((select terms_version is null and adult_confirmed_at is null from public.profiles where id = '00000000-0000-0000-0000-0000000000f1'), 'the other student was not changed');

-- ── #3 audit log purge ──
insert into auth.audit_log_entries (payload) values
  ('{"action":"login","actor_id":"00000000-0000-0000-0000-0000000000f2","actor_username":"f2@x"}'),
  ('{"action":"user_deleted","traits":{"user_id":"00000000-0000-0000-0000-0000000000f2","user_email":"f2@x"}}'),
  ('{"action":"login","actor_id":"00000000-0000-0000-0000-0000000000f1","actor_username":"f1@x"}');
select pg_temp.ok(public.purge_auth_audit('00000000-0000-0000-0000-0000000000f2', 'f2@x') = 2, 'purge_auth_audit removes the deleted student''s rows');
select pg_temp.ok((select count(*) from auth.audit_log_entries) = 1, 'other students'' audit rows stay');
set role authenticated;
select pg_temp.fails($$select public.purge_auth_audit(auth.uid(), null)$$) as "student cannot call purge_auth_audit";
reset role;

-- ── #10 copy_shared_lesson resets teacher_* ──
update public.materials set content_hash = 'h1', status = 'ready', processed_at = now() where id = 'f1000000-0000-0000-0000-000000000001';
insert into public.material_content (material_id, user_id, version, reader_doc) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 1, '{}');
insert into public.material_topics (material_id, user_id, title, teacher_minutes, teacher_repeats, teacher_said_exam) values ('f1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f1', 'T', 12.5, 3, true);
insert into public.courses (id, user_id, name) values ('f0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000f2', 'c2');
insert into public.materials (id, user_id, course_id, kind, title, content_hash) values ('f1000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000f2', 'f0000000-0000-0000-0000-000000000002', 'pdf', 'p2', 'h1');
select pg_temp.ok(public.copy_shared_lesson('f1000000-0000-0000-0000-000000000002'), 'copy_shared_lesson still copies');
select pg_temp.ok((select teacher_minutes is null and teacher_repeats is null and not teacher_said_exam from public.material_topics where material_id = 'f1000000-0000-0000-0000-000000000002'), 'lecturer emphasis is not copied');

-- ── #11 register_device limits ──
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000f2';
select pg_temp.fails($$select public.register_device(repeat('x', 101), 'web', 'Web', '1')$$) as "register_device: 101-char install id refused";
select pg_temp.ok((public.register_device('inst-1', 'web', 'Web', repeat('v', 500))->>'ok')::boolean, 'register_device works');
select pg_temp.ok((select length(app_version) = 40 from public.user_devices where install_id = 'inst-1'), 'app_version cut to 40');
reset role;
