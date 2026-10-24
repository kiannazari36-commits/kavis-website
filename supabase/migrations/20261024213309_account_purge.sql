-- "Hesabı sil": every night at 03:30 (UTC) the accounts whose 30 days are over are deleted by the Edge Function
-- delete-account (action 'purge': files in Storage, then the login; every table follows by cascade).
-- The job proves itself with a random key made here in the database (never in git): the job sends it,
-- the function checks it with check_purge_key().

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create table if not exists private.app_secrets (
  key   text primary key,
  value text not null
);
revoke all on private.app_secrets from public, anon, authenticated;

insert into private.app_secrets (key, value)
values ('purge_key', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (key) do nothing;

-- Only the server (service role) may ask whether a key is right.
create or replace function public.check_purge_key(key text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.app_secrets s where s.key = 'purge_key' and s.value = check_purge_key.key);
$$;
revoke execute on function public.check_purge_key(text) from public, anon, authenticated;
grant execute on function public.check_purge_key(text) to service_role;

select cron.schedule(
  'purge-deleted-accounts',
  '30 3 * * *',
  $job$
  select net.http_post(
    url := 'https://lnbfcfxxrqohcnkhlcur.supabase.co/functions/v1/delete-account',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-purge-key', (select value from private.app_secrets where key = 'purge_key')
    ),
    body := '{"action":"purge"}'::jsonb
  );
  $job$
);
