-- Invite codes that give a time-limited free Premium (first ~100 users). Only the server (service role) touches these
-- tables and the function; a student reaches them only through the Edge Function `redeem-code`.
alter type public.store_provider add value if not exists 'promo';

create table public.promo_codes (
  code        text primary key check (code = upper(code)),
  days        int  not null default 30 check (days between 1 and 365),
  max_uses    int  not null default 1 check (max_uses >= 1),
  used        int  not null default 0,
  expires_at  timestamptz,              -- the code can be redeemed until this moment (null = no limit)
  note        text,                     -- for the owner only, e.g. "Ayşe" or "Farmakoloji 3. sınıf"
  created_at  timestamptz not null default now()
);

create table public.promo_redemptions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  code         text not null references public.promo_codes(code),
  redeemed_at  timestamptz not null default now(),
  ends_at      timestamptz not null,
  unique (user_id, code)
);

-- wrong guesses, for the brute-force limit
create table public.promo_attempts (
  id       bigint generated always as identity primary key,
  user_id  uuid not null references public.profiles(id) on delete cascade,
  at       timestamptz not null default now()
);
create index promo_attempts_user on public.promo_attempts (user_id, at desc);

alter table public.promo_codes       enable row level security;
alter table public.promo_redemptions enable row level security;
alter table public.promo_attempts    enable row level security;
-- no policies: students can read and write nothing; the service role bypasses RLS.

-- Redeem a code for a student. Returns { ok: true, ends_at, days } or { ok: false, error, ... } with error one of
-- rate_limited | unknown | expired | used_up | already_redeemed | promo_active | already_premium.
create or replace function public.redeem_promo_code(uid uuid, raw_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  c        public.promo_codes;
  norm     text := upper(regexp_replace(coalesce(raw_code, ''), '\s', '', 'g'));
  ends     timestamptz;
  paid_end timestamptz;
  active_promo timestamptz;
  unlimited boolean;
begin
  if uid is null then return jsonb_build_object('ok', false, 'error', 'unknown'); end if;
  if (select count(*) from public.promo_attempts where user_id = uid and at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'rate_limited');
  end if;

  select * into c from public.promo_codes where code = norm for update;
  if not found then
    insert into public.promo_attempts (user_id) values (uid);
    return jsonb_build_object('ok', false, 'error', 'unknown');
  end if;
  if c.expires_at is not null and c.expires_at <= now() then
    insert into public.promo_attempts (user_id) values (uid);
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;
  if exists (select 1 from public.promo_redemptions where user_id = uid and code = norm) then
    return jsonb_build_object('ok', false, 'error', 'already_redeemed');
  end if;
  if c.used >= c.max_uses then
    insert into public.promo_attempts (user_id) values (uid);
    return jsonb_build_object('ok', false, 'error', 'used_up');
  end if;

  -- one promo at a time
  select max(expires_at) into active_promo from public.subscriptions
   where user_id = uid and provider = 'promo' and status = 'active' and expires_at > now();
  if active_promo is not null then
    return jsonb_build_object('ok', false, 'error', 'promo_active', 'ends_at', active_promo);
  end if;

  -- a real subscription (Apple, or the owner's manual row) that lasts at least as long wins: never downgrade
  ends := now() + make_interval(days => c.days);
  select bool_or(expires_at is null), max(expires_at) into unlimited, paid_end from public.subscriptions
   where user_id = uid and provider <> 'promo' and status in ('active', 'grace', 'billing_retry')
     and (expires_at is null or expires_at > now());
  if unlimited or paid_end >= ends then
    return jsonb_build_object('ok', false, 'error', 'already_premium', 'ends_at', paid_end);
  end if;

  insert into public.subscriptions (user_id, provider, product_id, original_transaction_id, status, started_at, expires_at)
  values (uid, 'promo', 'promo.' || c.days || 'd', 'promo:' || norm || ':' || uid, 'active', now(), ends);
  insert into public.promo_redemptions (user_id, code, ends_at) values (uid, norm, ends);
  update public.promo_codes set used = used + 1 where code = norm;
  return jsonb_build_object('ok', true, 'ends_at', ends, 'days', c.days);
end $$;
revoke execute on function public.redeem_promo_code(uuid, text) from public, anon, authenticated;
grant execute on function public.redeem_promo_code(uuid, text) to service_role;

-- Owner helper (paste in the SQL editor): make n codes. See supabase/scripts/make-codes.sql.
create or replace function public.make_promo_codes(n int, days int default 30, max_uses int default 1,
                                                   expires timestamptz default null, note text default null)
returns table (new_code text, new_days int, new_max_uses int, new_expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';   -- no 0/O/1/I/L
  made int := 0;
  c text;
begin
  while made < n loop
    c := 'KAVIS-';
    for i in 1..5 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    insert into public.promo_codes as p (code, days, max_uses, expires_at, note)
      values (c, make_promo_codes.days, make_promo_codes.max_uses, expires, make_promo_codes.note)
      on conflict do nothing;
    if found then made := made + 1; end if;
  end loop;
  return query select p.code, p.days, p.max_uses, p.expires_at from public.promo_codes p
    order by p.created_at desc, p.code limit n;
end $$;
revoke execute on function public.make_promo_codes(int, int, int, timestamptz, text) from public, anon, authenticated;
grant execute on function public.make_promo_codes(int, int, int, timestamptz, text) to service_role;

-- access_status: add when Premium ends and where it came from (so the apps can show "Premium aktif · bitiş: …").
create or replace function public.access_status() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid     uuid := auth.uid();
  started timestamptz;
  t       record;
  prem    boolean;
  s_until timestamptz;
  s_src   public.store_provider;
begin
  if uid is null then return null; end if;
  select trial_started_at into started from public.profiles where id = uid;
  select coalesce(max(lessons), 0) as lessons, coalesce(max(assistant_questions), 0) as qs
    into t from public.trial_usage where user_id = uid;
  prem := public.is_premium(uid);
  if prem then
    select provider, expires_at into s_src, s_until from public.subscriptions
     where user_id = uid and status in ('active', 'grace', 'billing_retry') and (expires_at is null or expires_at > now())
     order by expires_at desc nulls first limit 1;
  end if;
  return jsonb_build_object(
    'premium',        prem,
    'premium_until',  s_until,
    'premium_source', s_src,
    'trial_ends_at',  started + interval '3 days',
    'trial_ended',    now() >= started + interval '3 days',
    'days_left',      greatest(0, ceil(extract(epoch from (started + interval '3 days' - now())) / 86400))::int,
    'lessons_used',   t.lessons,
    'questions_used', t.qs,
    'limits',         jsonb_build_object('days', 3, 'lessons', 2, 'questions', 60, 'pages_per_lesson', 100),
    'fair_use',       case when prem then public.fair_use(uid) end
  );
end $$;
