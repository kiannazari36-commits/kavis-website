-- 1) Scheduled jobs of the server (Edge Functions called by pg_cron, proved by a random key kept in the database):
--    daily-planner      every hour at :05 → for students whose local time is 04:xx: this week's plan, today's
--                       review ("Bugünün tekrarı"), the day's reminder notification, on Monday the weekly report.
--    send-notifications every minute → push for due notifications. Created SWITCHED OFF: it needs the Apple APNs
--                       key (Supabase secrets APNS_*). Switch on later with:
--                       select cron.alter_job((select jobid from cron.job where jobname = 'send-notifications'), active := true);
-- 2) "Sign a device out" ends that device's login at once: sign_out_device deletes its auth session (no refresh any
--    more) and a PostgREST pre-request check refuses requests whose session is gone (its access token stays
--    signed for up to an hour, so without the check it could still read data until then).

-- ───────────── keys and the functions address ─────────────
insert into private.app_secrets (key, value)
values ('cron_key', encode(extensions.gen_random_bytes(32), 'hex')),
       ('functions_url', 'https://lnbfcfxxrqohcnkhlcur.supabase.co/functions/v1')
on conflict (key) do nothing;

-- Only the server (service role) may ask whether a job key is right.
create or replace function public.check_cron_key(key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.app_secrets s where s.key = 'cron_key' and s.value = check_cron_key.key);
$$;
revoke execute on function public.check_cron_key(text) from public, anon, authenticated;
grant execute on function public.check_cron_key(text) to service_role;

-- Calls an Edge Function of this project with the job key (used by the cron jobs below).
create or replace function private.call_job(fn text, body jsonb default '{}'::jsonb) returns bigint
language sql security definer set search_path = '' as $$
  select net.http_post(
    url := (select value from private.app_secrets where key = 'functions_url') || '/' || fn,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-key', (select value from private.app_secrets where key = 'cron_key')
    ),
    body := body,
    timeout_milliseconds := 120000
  );
$$;
revoke execute on function private.call_job(text, jsonb) from public, anon, authenticated;

select cron.schedule('daily-planner', '5 * * * *', $job$ select private.call_job('daily-planner'); $job$);
select cron.schedule('send-notifications', '* * * * *', $job$ select private.call_job('send-notifications'); $job$);
select cron.alter_job((select jobid from cron.job where jobname = 'send-notifications'), active := false);

-- Notifications the push job still has to look at (new, or a snooze that just ended).
create index if not exists notifications_snoozed on public.notifications (snoozed_until) where snoozed_until is not null;

-- ───────────── devices: remember the login, end it on sign-out ─────────────
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

-- Signs out one of the student's devices and ends its login (its auth session and refresh tokens).
create or replace function public.sign_out_device(p_device_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  sid uuid;
  found boolean;
begin
  update public.user_devices set signed_out_at = now()
   where id = p_device_id and user_id = auth.uid() and signed_out_at is null
  returning true, session_id into found, sid;
  if not coalesce(found, false) then return false; end if;
  if sid is not null then
    delete from auth.sessions where id = sid and user_id = auth.uid();
  end if;
  return true;
end $$;
grant execute on function public.sign_out_device(uuid) to authenticated;

-- PostgREST runs this before every API request: a login whose session was ended gets 401 "session_ended".
-- Own schema (not exposed by the API) so anon can run it without reaching the other private helpers.
create schema if not exists hooks;
revoke all on schema hooks from public;
grant usage on schema hooks to anon, authenticated, service_role;

create or replace function hooks.check_session() returns void
language plpgsql stable security definer set search_path = '' as $$
declare
  claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  sid text := claims ->> 'session_id';
begin
  if sid is null or sid = '' or coalesce(claims ->> 'role', '') <> 'authenticated' then return; end if;
  if not exists (select 1 from auth.sessions where id = sid::uuid) then
    raise sqlstate 'PGRST' using
      message = '{"code":"session_ended","message":"This device was signed out."}',
      detail  = '{"status":401,"headers":{}}';
  end if;
end $$;
revoke execute on function hooks.check_session() from public;
grant execute on function hooks.check_session() to anon, authenticated, service_role;

alter role authenticator set pgrst.db_pre_request = 'hooks.check_session';
notify pgrst, 'reload config';
