-- Behaviour tests: pre-launch security fixes (migration 20261119120000). Run after 10_behaviour.sql in a fresh database.
\set ON_ERROR_STOP 1
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'e1@x', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'e2@x', '{"app_lang":"tr"}');

-- ── add_usage: atomic increments ──
select public.add_usage('00000000-0000-0000-0000-0000000000e1', '2026-11-01', 100, 50, 0.25, 1, 0, 10, 20);
select pg_temp.ok(public.add_usage('00000000-0000-0000-0000-0000000000e1', '2026-11-01', 200, 70, 0.5, 0, 1, 0, 0) = 0.75, 'add_usage returns the new month cost');
select pg_temp.ok((select input_tokens = 300 and output_tokens = 120 and generations = 1 and assistant_questions = 1 and cache_read_tokens = 10 and cache_write_tokens = 20 and cost_usd = 0.75
                     from public.usage_monthly where user_id = '00000000-0000-0000-0000-0000000000e1' and month = '2026-11-01'), 'add_usage adds every counter');
select pg_temp.ok(public.add_usage('00000000-0000-0000-0000-0000000000e1', '2026-11-01', -5, -5, -1) = 0.75, 'add_usage ignores negative numbers');
select pg_temp.ok(public.add_trial_question('00000000-0000-0000-0000-0000000000e1') = 1 and public.add_trial_question('00000000-0000-0000-0000-0000000000e1') = 2, 'add_trial_question counts up');

-- apps (anon / signed-in) cannot call them
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e1';
select pg_temp.fails($$select public.add_usage(auth.uid(), '2026-11-01', 0, 0, -1000)$$) as "student cannot call add_usage";
select pg_temp.fails($$select public.add_trial_question(auth.uid())$$) as "student cannot call add_trial_question";
select pg_temp.fails($$select public.claim_processing_slot(gen_random_uuid(), auth.uid(), 2)$$) as "student cannot call claim_processing_slot";
select pg_temp.fails($$select * from public.promo_codes$$) as "student cannot read promo_codes";
select pg_temp.fails($$select * from public.promo_redemptions$$) as "student cannot read promo_redemptions";
select pg_temp.fails($$select * from public.promo_attempts$$) as "student cannot read promo_attempts";
reset role;
set role anon;
select pg_temp.fails($$select public.add_usage('00000000-0000-0000-0000-0000000000e1', '2026-11-01', 0, 0, 0)$$) as "anon cannot call add_usage";
reset role;

-- ── at most 2 lessons processing at once ──
insert into public.materials (id, user_id, kind, title) values
  ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e2', 'audio', 'a'),
  ('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000e2', 'audio', 'b'),
  ('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000e2', 'audio', 'c');
select pg_temp.ok(public.claim_processing_slot('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e2', 2), 'slot 1 claimed');
select pg_temp.ok(public.claim_processing_slot('50000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000e2', 2), 'slot 2 claimed');
select pg_temp.ok(not public.claim_processing_slot('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000e2', 2), 'third lesson refused');
select pg_temp.ok((select status from public.materials where id = '50000000-0000-0000-0000-000000000003') = 'uploaded', 'refused lesson keeps its status');
update public.materials set status = 'ready' where id = '50000000-0000-0000-0000-000000000001';
select pg_temp.ok(public.claim_processing_slot('50000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000e2', 2), 'a free slot after one finished');
alter table public.materials disable trigger user;  -- so the touch trigger does not reset updated_at
update public.materials set updated_at = now() - interval '10 minutes' where id = '50000000-0000-0000-0000-000000000002';
alter table public.materials enable trigger user;
select pg_temp.ok(public.claim_processing_slot('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e2', 2), 'a stopped (stale) lesson does not hold a slot');
select pg_temp.ok(not public.claim_processing_slot('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000e1', 2), 'another student cannot claim this lesson');

-- ── trial: a 3rd lesson is refused by the trigger itself (even for the server) ──
insert into public.materials (user_id, kind, title) values ('00000000-0000-0000-0000-0000000000e1', 'pdf', 'one'), ('00000000-0000-0000-0000-0000000000e1', 'photo', 'two');
select pg_temp.fails($$insert into public.materials (user_id, kind, title) values ('00000000-0000-0000-0000-0000000000e1', 'pdf', 'three')$$) as "trial: 3rd lesson refused by the trigger";
select pg_temp.ok((select lessons from public.trial_usage where user_id = '00000000-0000-0000-0000-0000000000e1') = 2, 'trial counter stays at 2');
insert into public.materials (user_id, kind, title) values ('00000000-0000-0000-0000-0000000000e1', 'audio', 'rec');
select pg_temp.ok(true, 'audio is still allowed');
-- Premium has no trial limit
insert into public.subscriptions (user_id, provider, product_id, original_transaction_id, status, expires_at)
  values ('00000000-0000-0000-0000-0000000000e1', 'apple', 'study.kavis.premium.year', 'tx-e1', 'active', now() + interval '200 days');
insert into public.materials (user_id, kind, title) values ('00000000-0000-0000-0000-0000000000e1', 'pdf', 'premium three');
select pg_temp.ok(true, 'Premium can add more lessons');
