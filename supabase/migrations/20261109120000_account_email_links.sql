-- "Hesap bilgilerimi iste" and "Hesabı sil" by email (Edge Functions export-data and delete-account).
-- Delete: the app asks → a 'delete' row with status 'pending', the SHA-256 of a one-time link token and expires_at (24 h);
--   the link in the email opens the web page /account/delete, its button calls delete-account 'confirm' →
--   confirm_account_delete(): the row becomes 'confirmed' with scheduled_for +30 days (the old flow from here on).
--   Only the hash is stored, so the database alone cannot be used to confirm anything.
-- Export: the JSON file goes to the private bucket 'exports' (<user>/<random>.json), the email has a 7-day signed link;
--   file_path is kept on the 'export' row so the nightly purge can remove the file after 7 days.

alter table public.account_requests
  add column if not exists token_hash text,
  add column if not exists expires_at timestamptz,
  add column if not exists file_path  text;
create unique index if not exists account_requests_token on public.account_requests (token_hash) where token_hash is not null;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('exports', 'exports', false, 104857600, array['application/json'])
on conflict (id) do nothing;
-- No storage policies for 'exports': only the server (service role) reads and writes it; the student gets a signed link.

-- One-time confirmation of a deletion link. Service role only (the Edge Function delete-account calls it).
-- → { ok: true, scheduled_for } | { ok: false, error: 'invalid' | 'expired' }
create or replace function public.confirm_account_delete(token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r       public.account_requests;
  already timestamptz;
  h       text := encode(extensions.digest(coalesce(token, ''), 'sha256'), 'hex');
begin
  if length(coalesce(token, '')) < 32 then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  select * into r from public.account_requests a
   where a.token_hash = h and a.kind = 'delete' and a.status = 'pending'
   for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  if r.expires_at is null or r.expires_at < now() then
    update public.account_requests set status = 'cancelled', token_hash = null where id = r.id;
    return jsonb_build_object('ok', false, 'error', 'expired');
  end if;
  -- Already scheduled (an earlier link): keep that date, close this link.
  select scheduled_for into already from public.account_requests a
   where a.user_id = r.user_id and a.kind = 'delete' and a.status = 'confirmed';
  if already is not null then
    update public.account_requests set status = 'cancelled', token_hash = null where id = r.id;
    return jsonb_build_object('ok', true, 'scheduled_for', already);
  end if;
  update public.account_requests
     set status = 'confirmed', token_hash = null, scheduled_for = now() + interval '30 days'
   where id = r.id
  returning scheduled_for into already;
  -- Other open links of the same student stop working.
  update public.account_requests set status = 'cancelled', token_hash = null
   where user_id = r.user_id and kind = 'delete' and status = 'pending';
  return jsonb_build_object('ok', true, 'scheduled_for', already);
end $$;
revoke execute on function public.confirm_account_delete(text) from public, anon, authenticated;
grant execute on function public.confirm_account_delete(text) to service_role;
