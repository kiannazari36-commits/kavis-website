-- "Kendi planım" (own study plan): the student's own weekly plan, written by the app (not the server).
-- One row = one course on one weekday for some minutes, in the order the student added them.
create table public.own_plan_items (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  weekday     smallint not null check (weekday between 1 and 7),   -- 1 = Monday
  course_id   uuid not null references public.courses(id) on delete cascade,
  minutes     smallint not null default 45 check (minutes between 5 and 240),
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index own_plan_items_user_day on public.own_plan_items (user_id, weekday, sort_order);
create index own_plan_items_course on public.own_plan_items (course_id);

alter table public.own_plan_items enable row level security;
revoke all on public.own_plan_items from anon;
grant select, insert, update, delete on public.own_plan_items to authenticated;

create policy "own rows read"   on public.own_plan_items for select to authenticated using (user_id = (select auth.uid()));
create policy "own rows insert" on public.own_plan_items for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own rows update" on public.own_plan_items for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own rows delete" on public.own_plan_items for delete to authenticated using (user_id = (select auth.uid()));
-- The course must be the student's own.
create policy "own parents" on public.own_plan_items as restrictive for all to authenticated
  using (true) with check (private.owns_course(course_id));
