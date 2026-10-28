-- Behaviour tests: shared processing of identical PDFs (copy_shared_lesson). Run after 10_behaviour.sql's setup
-- in a fresh database (own data); every line must say PASS.
\set ON_ERROR_STOP 1
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3@x', '{"app_lang":"tr"}');
-- Student 1: a finished lesson with data, plus personal data.
insert into public.materials (id, user_id, kind, title, status, language, page_count, content_hash, processed_at) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 'pdf', 'Source', 'ready', 'tr', 2, 'abc', now());
insert into public.material_content (material_id, user_id, reader_doc, stats) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '{"sections":[]}', '{"pages":2}');
insert into public.material_terms (material_id, user_id, term_key, surface, page) values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 't1', 'aspirin', 1);
insert into public.material_topics (id, material_id, user_id, title, page_from, page_to) values ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 'Topic', 1, 2);
insert into public.material_chunks (material_id, user_id, page, topic_id, text) values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', 1, '40000000-0000-0000-0000-000000000001', 'hello');
insert into public.card_decks (id, user_id, material_id, lang, title) values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-000000000001', 'tr', 'Deck');
insert into public.flashcards (deck_id, user_id, topic_id, question, answer, reps, from_mistake) values
  ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '40000000-0000-0000-0000-000000000001', 'q', 'a', 5, false),
  ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', null, 'mistake card', 'a', 0, true);
insert into public.quizzes (id, user_id, material_id, kind, lang) values ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-000000000001', 'lesson_end', 'tr');
insert into public.quiz_questions (quiz_id, user_id, topic_id, text, options, answer_index) values ('60000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1', '40000000-0000-0000-0000-000000000001', 'Q?', '["a","b"]', 0);
insert into public.summaries (user_id, material_id, lang, kind, content) values
  ('00000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-000000000001', 'tr', 'lesson', '{"points":[],"weakKey":""}');
insert into public.reading_progress (user_id, material_id, last_page) values ('00000000-0000-0000-0000-0000000000c1', '30000000-0000-0000-0000-000000000001', 2);

-- Student 2: same file, still "uploaded".
insert into public.materials (id, user_id, kind, title, status, content_hash) values ('30000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000c2', 'pdf', 'Copy', 'uploaded', 'abc');
select pg_temp.ok(public.copy_shared_lesson('30000000-0000-0000-0000-000000000002'), 'identical file: lesson copied');
select pg_temp.ok((select status from public.materials where id = '30000000-0000-0000-0000-000000000002') = 'ready' and (select page_count from public.materials where id = '30000000-0000-0000-0000-000000000002') = 2, 'copy is ready with page count');
select pg_temp.ok((select count(*) from public.material_terms where material_id = '30000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.material_chunks where material_id = '30000000-0000-0000-0000-000000000002' and topic_id is not null) = 1
  and (select count(*) from public.quiz_questions q join public.quizzes z on z.id = q.quiz_id where z.material_id = '30000000-0000-0000-0000-000000000002' and q.topic_id is not null) = 1, 'terms, chunks, questions copied with topics remapped');
select pg_temp.ok((select count(*) from public.flashcards f join public.card_decks d on d.id = f.deck_id where d.material_id = '30000000-0000-0000-0000-000000000002') = 1
  and (select reps from public.flashcards f join public.card_decks d on d.id = f.deck_id where d.material_id = '30000000-0000-0000-0000-000000000002') = 0, 'cards copied with fresh state; mistake card not copied');
select pg_temp.ok((select count(*) from public.summaries where material_id = '30000000-0000-0000-0000-000000000002') = 1, 'generic summary copied');
select pg_temp.ok((select count(*) from public.reading_progress where user_id = '00000000-0000-0000-0000-0000000000c2') = 0
  and not exists (select 1 from public.material_topics t where t.material_id = '30000000-0000-0000-0000-000000000002' and t.id = '40000000-0000-0000-0000-000000000001'), 'no personal data, new ids');
-- Source student 1 deletes the lesson: the copy stays intact.
delete from public.materials where id = '30000000-0000-0000-0000-000000000001';
select pg_temp.ok((select count(*) from public.material_content where material_id = '30000000-0000-0000-0000-000000000002') = 1
  and (select count(*) from public.quiz_questions where user_id = '00000000-0000-0000-0000-0000000000c2') = 1
  and (select count(*) from public.material_chunks where material_id = '30000000-0000-0000-0000-000000000002') = 1, 'source deleted: copy intact');
-- Student 3 has the same file; the only ready lesson is student 2's: matches. A different file or an unfinished source does not.
insert into public.materials (id, user_id, kind, title, status, content_hash) values
  ('30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000c3', 'pdf', 'Other file', 'uploaded', 'different'),
  ('30000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000c3', 'pdf', 'Same file', 'uploaded', 'abc');
select pg_temp.ok(not public.copy_shared_lesson('30000000-0000-0000-0000-000000000003'), 'different file: no match');
update public.materials set status = 'processing' where id = '30000000-0000-0000-0000-000000000002';
select pg_temp.ok(not public.copy_shared_lesson('30000000-0000-0000-0000-000000000004'), 'source still processing: no match');
update public.materials set status = 'failed' where id = '30000000-0000-0000-0000-000000000002';
select pg_temp.ok(not public.copy_shared_lesson('30000000-0000-0000-0000-000000000004'), 'source failed: no match');
-- Students cannot call it or set the fingerprint.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c3';
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;
select pg_temp.fails($$select public.copy_shared_lesson('30000000-0000-0000-0000-000000000004')$$) as "student cannot call copy_shared_lesson";
select pg_temp.fails($$update public.materials set content_hash = 'abc' where id = '30000000-0000-0000-0000-000000000003'$$) as "student cannot set content_hash";
reset role;
