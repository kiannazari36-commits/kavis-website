-- A lesson without a course shows in no list (iOS and web list courses and their lessons). It happened when a student
-- with no course uploaded a PDF, and with lessons received through a share link (found 28 Nov 2026).
-- Fix on the server, so no app update is needed:
--  1. a new PDF / photo lesson without a course goes into the student's general folder (made when needed);
--  2. new cards / quizzes / summaries of a lesson take the lesson's course when none is given;
--  3. the lessons that are already hidden are moved into that folder.

-- The student's general folder, in the app language. Reused when it exists (in any of the four languages).
create or replace function private.general_course(p_uid uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  cid uuid;
  lang text;
  term_name text;
  today date := (now() at time zone 'Europe/Istanbul')::date;
  m int := extract(month from today);
  y int := extract(year from today);
  start_year int;
begin
  select id into cid from public.courses
   where user_id = p_uid and archived_at is null and name in ('Genel', 'General', 'عمومی', 'عام')
   order by created_at limit 1;
  if cid is not null then return cid; end if;

  select app_lang::text into lang from public.profiles where id = p_uid;
  -- The term of the student's newest folder; otherwise the current one, written like the apps write it.
  select term into term_name from public.courses
   where user_id = p_uid and archived_at is null and term is not null order by created_at desc limit 1;
  if term_name is null then
    start_year := case when m >= 8 then y else y - 1 end;
    term_name := start_year || '–' || (start_year + 1) || ' ' || case when m >= 8 or m = 1 then 'Güz' else 'Bahar' end;
  end if;

  insert into public.courses (user_id, name, term, sort_order)
  values (p_uid,
          case lang when 'en' then 'General' when 'fa' then 'عمومی' when 'ar' then 'عام' else 'Genel' end,
          term_name,
          (select coalesce(max(sort_order) + 1, 0) from public.courses where user_id = p_uid))
  returning id into cid;
  return cid;
end $$;
revoke all on function private.general_course(uuid) from public, anon, authenticated;

-- After the insert (the access rules have already been checked on the row the student sent). The per-student lock
-- taken by materials_flags is still held, so two uploads at once cannot make two folders.
create or replace function public.on_material_default_course() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.materials set course_id = private.general_course(new.user_id) where id = new.id and course_id is null;
  return null;
end $$;
revoke all on function public.on_material_default_course() from public, anon, authenticated;
create trigger materials_default_course after insert on public.materials
  for each row when (new.course_id is null and new.parent_id is null and new.kind in ('pdf', 'photo'))
  execute function public.on_material_default_course();

create or replace function public.on_lesson_child_course() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  select course_id into new.course_id from public.materials where id = new.material_id and user_id = new.user_id;
  return new;
end $$;
revoke all on function public.on_lesson_child_course() from public, anon, authenticated;
create trigger card_decks_course before insert on public.card_decks
  for each row when (new.course_id is null and new.material_id is not null) execute function public.on_lesson_child_course();
create trigger quizzes_course before insert on public.quizzes
  for each row when (new.course_id is null and new.material_id is not null) execute function public.on_lesson_child_course();
create trigger summaries_course before insert on public.summaries
  for each row when (new.course_id is null and new.material_id is not null) execute function public.on_lesson_child_course();

-- The lessons that are hidden today, with everything that belongs to them.
do $$
declare
  r record;
  cid uuid;
  ids uuid[];
  t text;
begin
  for r in select user_id, array_agg(id) as lessons from public.materials
            where course_id is null and parent_id is null and kind in ('pdf', 'photo') group by user_id loop
    cid := private.general_course(r.user_id);
    -- the lessons, their parts and their recordings
    update public.materials set course_id = cid
     where user_id = r.user_id and course_id is null
       and (id = any(r.lessons) or parent_id = any(r.lessons) or linked_material_id = any(r.lessons));
    select array_agg(id) into ids from public.materials where user_id = r.user_id and course_id = cid;
    foreach t in array array['card_decks', 'quizzes', 'summaries', 'assistant_threads', 'plan_items', 'study_sessions', 'review_sessions'] loop
      execute format('update public.%I set course_id = $1 where user_id = $2 and course_id is null and material_id = any($3)', t)
        using cid, r.user_id, ids;
    end loop;
  end loop;
end $$;
