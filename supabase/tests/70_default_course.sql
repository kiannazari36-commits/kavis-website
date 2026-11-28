-- Behaviour tests: lessons without a course (migration 20261128093000). Run in a fresh database after 10..60.
\set ON_ERROR_STOP 1
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000071', 'g1@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-000000000072', 'g2@x', '{"app_lang":"en"}');

-- A new student with no folder uploads, exactly like the apps (signed in, RLS on).
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-000000000071';
insert into public.materials (id, user_id, course_id, kind, title) values
  ('71000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000071', null, 'pdf', 'first');
insert into public.materials (id, user_id, course_id, kind, title) values
  ('71000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000071', null, 'photo', 'second');
select pg_temp.ok((select count(*) from public.courses) = 1, 'one general folder for two uploads');
select pg_temp.ok((select name from public.courses) = 'Genel', 'folder named in the app language (tr)');
select pg_temp.ok((select term ~ '^\d{4}–\d{4} (Güz|Bahar)$' from public.courses), 'folder has a term');
select pg_temp.ok((select count(*) from public.materials m join public.courses c on c.id = m.course_id) = 2, 'both lessons are in the folder');
-- the trial limit still counts and still refuses a third lesson, without leaving a stray folder behind
select pg_temp.ok((select lessons from public.trial_usage) = 2, 'trial counted 2 lessons');
select pg_temp.fails($$insert into public.materials (user_id, course_id, kind, title) values ('00000000-0000-0000-0000-000000000071', null, 'pdf', 'third')$$) as "third trial lesson still refused";
select pg_temp.fails($$select private.general_course('00000000-0000-0000-0000-000000000072')$$) as "a student cannot call the folder function";
-- someone else's id: refused, nothing made for them
select pg_temp.fails($$insert into public.materials (user_id, course_id, kind, title) values ('00000000-0000-0000-0000-000000000072', null, 'pdf', 'x')$$) as "cannot upload for another student";
reset role;
select pg_temp.ok(not exists (select 1 from public.courses where user_id = '00000000-0000-0000-0000-000000000072'), 'no folder left for the other student');

-- The server adds a shared lesson and its content without a course (open-share).
insert into public.materials (id, user_id, kind, title, status) values
  ('72000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000072', 'pdf', 'shared', 'ready');
insert into public.card_decks (user_id, material_id, lang, title) values
  ('00000000-0000-0000-0000-000000000072', '72000000-0000-0000-0000-000000000001', 'en', 'd');
select pg_temp.ok((select c.name from public.materials m join public.courses c on c.id = m.course_id where m.id = '72000000-0000-0000-0000-000000000001') = 'General', 'shared lesson goes into "General"');
select pg_temp.ok((select d.course_id = m.course_id from public.card_decks d join public.materials m on m.id = d.material_id where m.id = '72000000-0000-0000-0000-000000000001'), 'its cards take the same folder');

-- A chosen folder is left alone; a recording is not moved.
insert into public.courses (id, user_id, name) values ('72000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000072', 'Pharma');
insert into public.materials (id, user_id, course_id, kind, title) values
  ('72000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000072', '72000000-0000-0000-0000-0000000000c1', 'pdf', 'chosen');
select pg_temp.ok((select course_id from public.materials where id = '72000000-0000-0000-0000-000000000002') = '72000000-0000-0000-0000-0000000000c1', 'chosen folder kept');
insert into public.materials (id, user_id, kind, title) values ('72000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000072', 'audio', 'rec');
select pg_temp.ok((select course_id is null from public.materials where id = '72000000-0000-0000-0000-000000000003'), 'a recording alone is not moved');

-- Deleting the account still works (cascades).
delete from auth.users where id = '00000000-0000-0000-0000-000000000072';
select pg_temp.ok(not exists (select 1 from public.courses where user_id = '00000000-0000-0000-0000-000000000072'), 'account deletion removes folder and lessons');
