-- Follow-up from the Supabase advisors.
-- 1) Internal ownership checks used by policies move to a schema the API does not expose.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;
alter function public.owns_course(uuid)   set schema private;
alter function public.owns_material(uuid) set schema private;
alter function public.owns_quiz(uuid)     set schema private;

-- 2) Indexes for foreign keys that had none.
create index if not exists material_chunks_topic   on public.material_chunks (topic_id);
create index if not exists material_files_user     on public.material_files (user_id);
create index if not exists materials_course        on public.materials (course_id);
create index if not exists push_tokens_device      on public.push_tokens (device_id);
create index if not exists timetable_course        on public.timetable_entries (course_id);
