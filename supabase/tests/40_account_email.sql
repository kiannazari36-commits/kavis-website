-- Behaviour tests: deletion confirmed by an email link (confirm_account_delete, migration 20261109120000).
-- Runs on the local Supabase copy inside a transaction that is rolled back:
--   docker exec -i supabase_db_kavis-study psql -U postgres < supabase/tests/40_account_email.sql
\set ON_ERROR_STOP 1
begin;
create or replace function pg_temp.ok(cond boolean, label text) returns text language sql as
  $$ select case when cond then 'PASS ' else 'FAIL ' end || label $$;
create or replace function pg_temp.fails(q text) returns text language plpgsql as $$
begin execute q; return 'FAIL (no error): ' || q;
exception when others then return 'PASS (blocked: ' || sqlstate || ')'; end $$;
create or replace function pg_temp.h(t text) returns text language sql as
  $$ select encode(extensions.digest(t, 'sha256'), 'hex') $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'e1@x.test', '{"app_lang":"tr"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'e2@x.test', '{"app_lang":"en"}');
-- e1: two open links; e2: an expired one.
insert into public.account_requests (user_id, kind, status, token_hash, expires_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'delete', 'pending', pg_temp.h(repeat('a', 43)), now() + interval '24 hours'),
  ('00000000-0000-0000-0000-0000000000e1', 'delete', 'pending', pg_temp.h(repeat('b', 43)), now() + interval '24 hours'),
  ('00000000-0000-0000-0000-0000000000e2', 'delete', 'pending', pg_temp.h(repeat('c', 43)), now() - interval '1 minute');

select pg_temp.ok(public.confirm_account_delete(repeat('z', 43))->>'error' = 'invalid', 'unknown token → invalid');
select pg_temp.ok(public.confirm_account_delete('short')->>'error' = 'invalid', 'short token → invalid');
select pg_temp.ok(public.confirm_account_delete(null)->>'error' = 'invalid', 'no token → invalid');
select pg_temp.ok(public.confirm_account_delete(repeat('c', 43))->>'error' = 'expired', 'expired link → expired');
select pg_temp.ok(not exists (select 1 from public.account_requests where user_id = '00000000-0000-0000-0000-0000000000e2' and status = 'confirmed'), 'expired link schedules nothing');
select pg_temp.ok(public.confirm_account_delete(repeat('c', 43))->>'error' = 'invalid', 'expired link is closed afterwards');

select pg_temp.ok((public.confirm_account_delete(repeat('a', 43))->>'ok')::boolean, 'valid link confirms');
select pg_temp.ok((select scheduled_for between now() + interval '29 days 23 hours' and now() + interval '30 days 1 hour'
                     from public.account_requests where user_id = '00000000-0000-0000-0000-0000000000e1' and status = 'confirmed'), 'deleted in 30 days');
select pg_temp.ok(public.confirm_account_delete(repeat('a', 43))->>'error' = 'invalid', 'same link twice → invalid (one-time)');
select pg_temp.ok(public.confirm_account_delete(repeat('b', 43))->>'error' = 'invalid', 'the other open link stopped working');
select pg_temp.ok((select count(*) from public.account_requests where user_id = '00000000-0000-0000-0000-0000000000e1' and status = 'confirmed') = 1, 'one scheduled deletion only');
select pg_temp.ok(not exists (select 1 from public.account_requests where token_hash is not null and status <> 'pending'), 'no hash kept on closed rows');

-- Students cannot call it, nor make their own pending/confirmed rows.
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000e2';
select pg_temp.fails($$select public.confirm_account_delete(repeat('a', 43))$$) as "student cannot call confirm_account_delete";
select pg_temp.fails($$insert into public.account_requests (user_id, kind, status, scheduled_for) values (auth.uid(), 'delete', 'confirmed', now())$$) as "student cannot write account_requests";
set role anon;
select pg_temp.fails($$select public.confirm_account_delete(repeat('a', 43))$$) as "anon cannot call confirm_account_delete";
reset role;
select pg_temp.ok((select public = false from storage.buckets where id = 'exports'), 'exports bucket is private');
select pg_temp.ok(not exists (select 1 from pg_policies where schemaname = 'storage' and qual ilike '%exports%'), 'no storage policy opens exports');
rollback;
