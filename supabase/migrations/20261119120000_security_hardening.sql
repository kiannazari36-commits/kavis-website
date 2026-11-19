-- Pre-launch security fixes (19 Nov 2026).
-- 1. add_usage: one atomic increment of the month's AI usage/cost (no read-then-write race). Service role only.
-- 2. claim_processing_slot: at most N lessons "processing" at the same time per student. Service role only.
-- 3. Trial lesson limit: the check is serialized per student, so parallel uploads cannot pass it together.
-- 4. promo_* tables: no direct access for the apps (only the service role / SQL functions use them).

-- ───────────── 1. atomic usage counter ─────────────
create or replace function public.add_usage(
  p_uid uuid, p_month date,
  p_input bigint default 0, p_output bigint default 0, p_cost numeric default 0,
  p_generations int default 0, p_questions int default 0,
  p_cache_read bigint default 0, p_cache_write bigint default 0
) returns numeric
language plpgsql security definer set search_path = '' as $$
declare total numeric;
begin
  insert into public.usage_monthly as u (user_id, month, input_tokens, output_tokens, cost_usd, generations, assistant_questions, cache_read_tokens, cache_write_tokens)
  values (p_uid, p_month, greatest(p_input, 0), greatest(p_output, 0), greatest(p_cost, 0), greatest(p_generations, 0), greatest(p_questions, 0), greatest(p_cache_read, 0), greatest(p_cache_write, 0))
  on conflict (user_id, month) do update set
    input_tokens        = u.input_tokens + excluded.input_tokens,
    output_tokens       = u.output_tokens + excluded.output_tokens,
    cost_usd            = u.cost_usd + excluded.cost_usd,
    generations         = u.generations + excluded.generations,
    assistant_questions = u.assistant_questions + excluded.assistant_questions,
    cache_read_tokens   = u.cache_read_tokens + excluded.cache_read_tokens,
    cache_write_tokens  = u.cache_write_tokens + excluded.cache_write_tokens
  returning u.cost_usd into total;
  return total;
end $$;
revoke execute on function public.add_usage(uuid, date, bigint, bigint, numeric, int, int, bigint, bigint) from public, anon, authenticated;
grant execute on function public.add_usage(uuid, date, bigint, bigint, numeric, int, int, bigint, bigint) to service_role;

-- Trial question counter: same idea (atomic, +1).
create or replace function public.add_trial_question(p_uid uuid) returns int
language sql security definer set search_path = '' as $$
  insert into public.trial_usage as t (user_id, assistant_questions) values (p_uid, 1)
  on conflict (user_id) do update set assistant_questions = t.assistant_questions + 1
  returning t.assistant_questions;
$$;
revoke execute on function public.add_trial_question(uuid) from public, anon, authenticated;
grant execute on function public.add_trial_question(uuid) to service_role;

-- ───────────── 2. at most N lessons processing at once ─────────────
-- Moves the lesson to 'processing' only if the student has fewer than p_max other lessons processing
-- (a processing lesson not touched for 5 minutes was stopped and does not count). Returns true if claimed.
create or replace function public.claim_processing_slot(p_material uuid, p_uid uuid, p_max int default 2) returns boolean
language plpgsql security definer set search_path = '' as $$
declare busy int;
begin
  perform pg_advisory_xact_lock(hashtextextended('processing:' || p_uid::text, 0));
  select count(*) into busy from public.materials
   where user_id = p_uid and status = 'processing' and id <> p_material
     and updated_at > now() - interval '5 minutes';
  if busy >= p_max then return false; end if;
  update public.materials set status = 'processing', error = null where id = p_material and user_id = p_uid;
  return found;
end $$;
revoke execute on function public.claim_processing_slot(uuid, uuid, int) from public, anon, authenticated;
grant execute on function public.claim_processing_slot(uuid, uuid, int) to service_role;

-- ───────────── 3. trial lesson limit without a race ─────────────
-- The flags trigger runs before every insert. It now takes a per-student lock (held until the transaction ends)
-- and refuses a 3rd trial lesson. A parallel insert waits, then sees the first one's count.
create or replace function public.on_material_flags() returns trigger
language plpgsql security definer set search_path = '' as $$
declare used int;
begin
  if new.parent_id is null and new.kind in ('pdf', 'photo') then
    perform pg_advisory_xact_lock(hashtextextended('material:' || new.user_id::text, 0));
    if public.is_premium(new.user_id) then
      new.slow_lane := coalesce((public.fair_use(new.user_id)->>'used')::int, 0) >= 40;
      new.counted_in_trial := false;
    else
      select coalesce(max(lessons), 0) into used from public.trial_usage where user_id = new.user_id;
      if used >= 2 then
        raise exception 'trial lesson limit reached' using errcode = '42501';
      end if;
      new.slow_lane := false;
      new.counted_in_trial := true;
    end if;
  end if;
  return new;
end $$;

-- ───────────── 4. promo tables: no grants for the apps ─────────────
revoke all on public.promo_codes, public.promo_redemptions, public.promo_attempts from anon, authenticated;
