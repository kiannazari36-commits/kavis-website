-- Behaviour tests: invite codes with free Premium (redeem_promo_code). Run after 10_behaviour.sql in a fresh database.
\set ON_ERROR_STOP 1
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'd1@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000d2', 'd2@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000d3', 'd3@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000d4', 'd4@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000d5', 'd5@x', '{"app_lang":"tr"}');
insert into public.promo_codes (code, days, max_uses, expires_at) values
  ('KAVIS-OK111', 30, 1, null), ('KAVIS-OLD11', 30, 1, now() - interval '1 day'),
  ('KAVIS-CLASS', 30, 100, null), ('KAVIS-SHORT', 5, 1, null), ('KAVIS-OTHER', 30, 1, null);

-- valid code, typed sloppily; Premium starts now and ends in 30 days
select pg_temp.ok((public.redeem_promo_code('00000000-0000-0000-0000-0000000000d1', ' kavis-ok 111 ')->>'ok')::boolean, 'valid code (lowercase, spaces) works');
select pg_temp.ok(public.is_premium('00000000-0000-0000-0000-0000000000d1'), 'student is Premium');
select pg_temp.ok((select expires_at between now() + interval '29 days 23 hours' and now() + interval '30 days 1 hour' from public.subscriptions where user_id = '00000000-0000-0000-0000-0000000000d1' and provider = 'promo'), 'ends 30 days from redeeming');
-- used up
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d2', 'KAVIS-OK111')->>'error' = 'used_up', 'used-up code refused');
-- expired, unknown
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d2', 'KAVIS-OLD11')->>'error' = 'expired', 'expired code refused');
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d2', 'NOPE')->>'error' = 'unknown', 'unknown code refused');
-- same code twice / second code while promo is active
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d1', 'KAVIS-OK111')->>'error' = 'already_redeemed', 'same code twice refused');
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d1', 'KAVIS-OTHER')->>'error' = 'promo_active', 'second code while promo active refused');
-- shared class code: many students, counter goes up
select public.redeem_promo_code('00000000-0000-0000-0000-0000000000d2', 'KAVIS-CLASS');
select public.redeem_promo_code('00000000-0000-0000-0000-0000000000d3', 'KAVIS-CLASS');
select pg_temp.ok((select used from public.promo_codes where code = 'KAVIS-CLASS') = 2, 'class code counted 2 uses');
-- brute force: 10 wrong tries, then even a right code is refused
select public.redeem_promo_code('00000000-0000-0000-0000-0000000000d4', 'WRONG' || g) from generate_series(1, 10) g;
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d4', 'KAVIS-OTHER')->>'error' = 'rate_limited', 'after 10 wrong tries: rate limited');
update public.promo_attempts set at = now() - interval '2 hours' where user_id = '00000000-0000-0000-0000-0000000000d4';
select pg_temp.ok((public.redeem_promo_code('00000000-0000-0000-0000-0000000000d4', 'KAVIS-OTHER')->>'ok')::boolean, 'limit lifts after an hour');
-- never downgrade a paid subscription (longer than the code, or no end date)
insert into public.subscriptions (user_id, provider, product_id, original_transaction_id, status, expires_at)
  values ('00000000-0000-0000-0000-0000000000d5', 'apple', 'study.kavis.premium.year', 'tx5', 'active', now() + interval '200 days');
select pg_temp.ok(public.redeem_promo_code('00000000-0000-0000-0000-0000000000d5', 'KAVIS-SHORT')->>'error' = 'already_premium', 'longer paid subscription: promo refused');
select pg_temp.ok((select count(*) from public.subscriptions where user_id = '00000000-0000-0000-0000-0000000000d5') = 1, 'paid subscription untouched');
-- access_status shows the end date and the source
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
select pg_temp.ok((public.access_status()->>'premium')::boolean and public.access_status()->>'premium_source' = 'promo' and (public.access_status()->>'premium_until') is not null, 'access_status: premium_until + source promo');
select pg_temp.ok(public.can_i('upload') and public.can_i('share'), 'can_i: upload and share allowed with promo');
select pg_temp.ok((select count(*) from public.promo_codes) = 0, 'student sees no codes');
reset role;
-- promo ends: back to the normal trial/locked state
update public.subscriptions set expires_at = now() - interval '1 minute' where user_id = '00000000-0000-0000-0000-0000000000d1';
update public.profiles set trial_started_at = now() - interval '10 days' where id = '00000000-0000-0000-0000-0000000000d1';
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000d1';
select pg_temp.ok(not (public.access_status()->>'premium')::boolean and (public.access_status()->>'trial_ended')::boolean and not public.can_i('upload'), 'after promo ends: locked like a finished trial');
reset role;
-- a new code can be redeemed once the old promo has ended
select pg_temp.ok((public.redeem_promo_code('00000000-0000-0000-0000-0000000000d1', 'KAVIS-SHORT')->>'ok')::boolean, 'after the promo ended a new code works');
