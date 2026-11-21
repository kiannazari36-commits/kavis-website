-- Privacy / security fixes from the 21 Nov attacker + KVKK test (docs/TEST2_ATTACKER_KVKK.md). Tested locally only.
--  #1  storage quota per student (+ file count limits for the small buckets); audio lessons need the right to record
--  #3  purge_auth_audit(): the nightly purge also removes the deleted student's rows from auth.audit_log_entries
--  #4  consent and age proof: record_consent() + profiles.adult_confirmed_at / ai_consent_at
--  #8  storage paths: CHECK constraints against ".." and another student's folder (NOT VALID: old rows are not re-checked)
--  #10 copy_shared_lesson: the lecturer-emphasis fields of the source student are not copied
--  #11 register_device: length limits

-- ───────────── #1 audio lessons: "record" right ─────────────
-- 'record' = the free trial is running or the student is Premium (no lesson counter: a recording is not a PDF).
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
    when 'record'   then true
    when 'ask'      then t.qs < 60
    when 'generate' then true
    else false
  end;
end $$;

drop policy "own rows insert" on public.materials;
create policy "own rows insert" on public.materials for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'uploaded' and parent_id is null
              and private.owns_course(course_id) and private.owns_material(linked_material_id)
              and public.can_i(case when kind = 'audio' then 'record' else 'upload' end));

-- ───────────── #1 storage quota ─────────────
-- Total bytes of the student's files (all five buckets) must stay under the plan's limit when a new file is added
-- (the check is made before the upload, so one file can overshoot by its own size: max 100 MB), and the small
-- buckets have a file count limit. Premium: 5 GB. Everyone else (trial / after the trial): 500 MB.
create or replace function public.storage_quota_ok(p_bucket text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  used bigint;
  n bigint;
  cap bigint;
begin
  if uid is null then return false; end if;
  select coalesce(sum(coalesce((o.metadata->>'size')::bigint, 0)), 0), count(*) filter (where o.bucket_id = p_bucket)
    into used, n
    from storage.objects o
   where o.bucket_id in ('materials', 'avatars', 'question-samples', 'ink', 'support')
     and o.name like uid::text || '/%';
  cap := case when public.is_premium(uid) then 5368709120 else 524288000 end;
  if used >= cap then return false; end if;
  return n < case p_bucket when 'ink' then 5000 when 'support' then 100 when 'question-samples' then 300
                           when 'avatars' then 10 else 100000 end;
end $$;
revoke execute on function public.storage_quota_ok(text) from public, anon;
grant execute on function public.storage_quota_ok(text) to authenticated, service_role;

drop policy "own files insert" on storage.objects;
create policy "own files insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('materials', 'avatars', 'question-samples', 'ink', 'support')
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and public.storage_quota_ok(bucket_id));

-- ───────────── #3 audit log purge ─────────────
-- auth.audit_log_entries keeps sign-up / login / delete events with the e-mail and the id. The purge calls this after
-- the account is gone (the delete itself writes one more row). Service role only.
create or replace function public.purge_auth_audit(p_uid uuid, p_email text default null) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from auth.audit_log_entries
   where payload::text like '%' || p_uid::text || '%'
      or (p_email is not null and length(p_email) > 3 and payload::text ilike '%' || replace(replace(p_email, '\', '\\'), '%', '\%') || '%');
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function public.purge_auth_audit(uuid, text) from public, anon, authenticated;
grant execute on function public.purge_auth_audit(uuid, text) to service_role;

-- ───────────── #4 consent and age proof ─────────────
alter table public.profiles add column if not exists adult_confirmed_at timestamptz;
alter table public.profiles add column if not exists ai_consent_at timestamptz;

-- The signed-in student records: accepted terms version, "I am over 18" (required), and the AI-processing consent.
-- Contract shared with the iOS app: record_consent(p_terms_version text, p_adult boolean, p_ai boolean) returns void.
-- p_ai = true sets ai_consent_at to now; p_ai = false leaves it as it was.
create or replace function public.record_consent(p_terms_version text, p_adult boolean, p_ai boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if p_adult is distinct from true then raise exception 'adult_required' using errcode = '22023'; end if;
  if coalesce(length(trim(p_terms_version)), 0) = 0 or length(p_terms_version) > 40 then
    raise exception 'bad_terms_version' using errcode = '22023';
  end if;
  update public.profiles
     set terms_version = p_terms_version,
         terms_accepted_at = now(),
         adult_confirmed_at = now(),
         ai_consent_at = case when p_ai is true then now() else ai_consent_at end
   where id = uid;
end $$;
revoke execute on function public.record_consent(text, boolean, boolean) from public, anon;
grant execute on function public.record_consent(text, boolean, boolean) to authenticated, service_role;

-- ───────────── #8 storage paths ─────────────
-- The path must start with the owner's id and must not walk out of the folder. NOT VALID: only new / changed rows are checked.
alter table public.material_files
  add constraint material_files_path_ok check (split_part(storage_path, '/', 1) = user_id::text and storage_path !~ '(^|/)\.\.?(/|$)' and storage_path !~ '[\\]') not valid;
alter table public.question_samples
  add constraint question_samples_path_ok check (storage_path is null or (split_part(storage_path, '/', 1) = user_id::text and storage_path !~ '(^|/)\.\.?(/|$)' and storage_path !~ '[\\]')) not valid;
alter table public.support_messages
  add constraint support_messages_path_ok check (attachment_path is null or (split_part(attachment_path, '/', 1) = user_id::text and attachment_path !~ '(^|/)\.\.?(/|$)' and attachment_path !~ '[\\]')) not valid;
alter table public.profiles
  add constraint profiles_avatar_path_ok check (avatar_path is null or (split_part(avatar_path, '/', 1) = id::text and avatar_path !~ '(^|/)\.\.?(/|$)' and avatar_path !~ '[\\]')) not valid;

-- ───────────── #10 copy_shared_lesson: no lecturer emphasis from another student ─────────────
-- (teacher_minutes / teacher_repeats / teacher_said_exam come from the source student's own recording)
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
  select m.* into s from public.materials m
   where m.content_hash = d.content_hash and m.status = 'ready' and m.user_id <> uid and m.kind = 'pdf' and m.id <> dst
     and exists (select 1 from public.material_content c where c.material_id = m.id)
   order by m.processed_at desc nulls last limit 1;
  if not found then return false; end if;

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
    -- the lecturer-emphasis fields stay at their defaults: they come from the source student's own lecture recording
    insert into public.material_topics (material_id, user_id, title, page_from, page_to, importance, sort_order)
      values (dst, uid, rec.title, rec.page_from, rec.page_to, rec.importance, rec.sort_order)
      returning id into nid;
    tmap := tmap || jsonb_build_object(rec.id::text, nid::text);
  end loop;

  insert into public.material_chunks (material_id, user_id, page, topic_id, source, text)
    select dst, uid, page, (tmap->>topic_id::text)::uuid, source, text from public.material_chunks where material_id = s.id;

  for rec in select * from public.card_decks where material_id = s.id loop
    insert into public.card_decks (user_id, course_id, material_id, lang, title) values (uid, d.course_id, dst, rec.lang, rec.title) returning id into new_deck;
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

  insert into public.summaries (user_id, course_id, material_id, lang, kind, content)
    select uid, d.course_id, dst, lang, kind, content from public.summaries
     where material_id = s.id and kind = 'lesson' and coalesce(content->>'weakKey', '') = ''
     order by created_at desc limit 1;

  update public.materials set status = 'ready', error = null, language = s.language, page_count = s.page_count, processed_at = now() where id = dst;
  return true;
end $$;
revoke all on function public.copy_shared_lesson(uuid) from public, anon, authenticated;
grant execute on function public.copy_shared_lesson(uuid) to service_role;

-- ───────────── #11 register_device: length limits ─────────────
create or replace function public.register_device(p_install_id text, p_kind public.device_kind, p_name text, p_app_version text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  sid uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  others jsonb;
  dev uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_install_id is null or length(p_install_id) = 0 or length(p_install_id) > 100 then raise exception 'bad install id' using errcode = '22023'; end if;
  p_app_version := left(p_app_version, 40);
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
  insert into public.user_devices (user_id, install_id, kind, name, app_version, session_id, last_seen_at, signed_out_at)
  values (uid, p_install_id, p_kind, left(p_name, 80), p_app_version, sid, now(), null)
  on conflict (user_id, install_id)
    do update set kind = excluded.kind, name = excluded.name, app_version = excluded.app_version,
                  session_id = coalesce(excluded.session_id, public.user_devices.session_id),
                  last_seen_at = now(), signed_out_at = null
  returning id into dev;
  return jsonb_build_object('ok', true, 'device_id', dev);
end $$;
