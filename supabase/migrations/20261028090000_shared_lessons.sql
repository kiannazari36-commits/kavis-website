-- Shared processing of identical PDFs: the AI cost of preparing a PDF is paid once.
-- process-material (service role) computes the SHA-256 of the uploaded file on the server and keeps it in
-- materials.content_hash. If another student's lesson with the same hash is "ready", copy_shared_lesson() makes
-- a deep copy of the lesson-derived data (new ids, no link to the source) and the AI is not called.
-- Never copied: reading progress, tapped words, highlights, notes, topic progress, quiz attempts/answers,
-- assistant chats, translations, summaries, shares, subscriptions, the PDF file itself.

alter table public.materials add column content_hash text;
create index materials_hash_ready on public.materials (content_hash) where status = 'ready' and content_hash is not null;

-- Students must not set or change the fingerprint themselves (only the service role writes it).
revoke update (content_hash) on public.materials from authenticated, anon;
revoke insert (content_hash) on public.materials from authenticated, anon;

-- Copies the lesson of another student with the same file into dst. Returns true when it copied (dst is then
-- "ready"), false when there is no match (nothing is changed). Only the service role may call it.
create or replace function public.copy_shared_lesson(dst uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  d public.materials;
  s public.materials;
  uid uuid;
  choice text;
  app text;
  want public.app_lang;
  doc_lang public.app_lang;
  cstats jsonb;
  new_deck uuid;
  new_quiz uuid;
  rec record;
  tmap jsonb := '{}';
  nid uuid;
begin
  select * into d from public.materials where id = dst for update;
  if not found or d.content_hash is null or d.kind <> 'pdf' or d.status not in ('uploaded', 'failed', 'processing') then
    return false;
  end if;
  uid := d.user_id;
  -- The newest finished lesson of another student with the same file (a source that is not ready is no match).
  select m.* into s from public.materials m
   where m.content_hash = d.content_hash and m.status = 'ready' and m.user_id <> uid and m.kind = 'pdf' and m.id <> dst
     and exists (select 1 from public.material_content c where c.material_id = m.id)
   order by m.processed_at desc nulls last limit 1;
  if not found then return false; end if;

  -- The content language of the new student must be the one the lesson was written in.
  select coalesce((select content_lang_override::text from public.courses where id = d.course_id), us.content_lang::text, 'pdf'), p.app_lang::text
    into choice, app from public.user_settings us join public.profiles p on p.id = us.user_id where us.user_id = uid;
  doc_lang := s.language;
  want := case coalesce(choice, 'pdf') when 'pdf' then doc_lang when 'app' then coalesce(app, 'tr')::public.app_lang else choice::public.app_lang end;
  if exists (select 1 from public.quizzes where material_id = s.id and lang <> want)
     or exists (select 1 from public.card_decks where material_id = s.id and lang <> want) then
    return false;
  end if;

  delete from public.material_content where material_id = dst;
  delete from public.material_terms where material_id = dst;
  delete from public.material_chunks where material_id = dst;
  delete from public.card_decks where material_id = dst;
  delete from public.quizzes where material_id = dst;
  delete from public.material_topics where material_id = dst;

  select stats into cstats from public.material_content where material_id = s.id;
  insert into public.material_content (material_id, user_id, version, reader_doc, lecture, stats)
    select dst, uid, version, reader_doc, lecture, stats from public.material_content where material_id = s.id;

  insert into public.material_terms (material_id, user_id, term_key, surface, page, explanation, molecule)
    select dst, uid, term_key, surface, page, explanation, molecule from public.material_terms where material_id = s.id;

  for rec in select * from public.material_topics where material_id = s.id loop
    insert into public.material_topics (material_id, user_id, title, page_from, page_to, importance, teacher_minutes, teacher_repeats, teacher_said_exam, sort_order)
      values (dst, uid, rec.title, rec.page_from, rec.page_to, rec.importance, rec.teacher_minutes, rec.teacher_repeats, rec.teacher_said_exam, rec.sort_order)
      returning id into nid;
    tmap := tmap || jsonb_build_object(rec.id::text, nid::text);
  end loop;

  insert into public.material_chunks (material_id, user_id, page, topic_id, source, text)
    select dst, uid, page, (tmap->>topic_id::text)::uuid, source, text from public.material_chunks where material_id = s.id;

  for rec in select * from public.card_decks where material_id = s.id loop
    insert into public.card_decks (user_id, course_id, material_id, lang, title) values (uid, d.course_id, dst, rec.lang, rec.title) returning id into new_deck;
    -- Only the cards the lesson made, with fresh study state (never the source student's reviews or mistakes).
    insert into public.flashcards (deck_id, user_id, topic_id, question, answer, note, page, sort_order)
      select new_deck, uid, (tmap->>topic_id::text)::uuid, question, answer, note, page, sort_order
        from public.flashcards where deck_id = rec.id and not from_mistake;
  end loop;

  for rec in select * from public.quizzes where material_id = s.id and kind = 'lesson_end' loop
    insert into public.quizzes (user_id, course_id, material_id, kind, lang, teacher_style, options) values (uid, d.course_id, dst, rec.kind, rec.lang, rec.teacher_style, rec.options) returning id into new_quiz;
    insert into public.quiz_questions (quiz_id, user_id, topic_id, sort_order, kind, style_tag, text, options, answer_index, model_answer, explanation, source_page, hints, molecule)
      select new_quiz, uid, (tmap->>topic_id::text)::uuid, sort_order, kind, style_tag, text, options, answer_index, model_answer, explanation, source_page, hints, molecule
        from public.quiz_questions where quiz_id = rec.id;
  end loop;

  -- A summary that was not tied to the source student's weak topics.
  insert into public.summaries (user_id, course_id, material_id, lang, kind, content)
    select uid, d.course_id, dst, lang, kind, content from public.summaries
     where material_id = s.id and kind = 'lesson' and coalesce(content->>'weakKey', '') = ''
     order by created_at desc limit 1;

  update public.materials set status = 'ready', error = null, language = s.language, page_count = s.page_count, processed_at = now() where id = dst;
  return true;
end $$;
revoke all on function public.copy_shared_lesson(uuid) from public, anon, authenticated;
grant execute on function public.copy_shared_lesson(uuid) to service_role;
