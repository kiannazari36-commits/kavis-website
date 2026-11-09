// Edge Function delete-account: "Hesabı sil".
// POST { action: 'request' }          → an email with a one-time confirmation link (24 h) to the account's address
//   (works for Apple / Google sign-in too, no password needed). account_requests: kind 'delete', status 'pending',
//   token_hash, expires_at. → { sent: true } | { scheduled_for } (already scheduled) | 429 { error: 'limit' }
// POST { action: 'confirm', token }    → no login: the web page /account/delete (button in the email's link) sends
//   the token; confirm_account_delete() makes it 'confirmed' with scheduled_for +30 days. → { ok, scheduled_for | error }
// POST { action: 'cancel' }            → "Vazgeç" within the 30 days.
// POST { action: 'purge' } + header x-purge-key (the nightly job, migration 20261024213309_account_purge.sql)
//   → deletes the accounts whose 30 days are over: their files in Storage, then the login (every table goes with it);
//   also removes the export files (export-data) older than 7 days.
// verify_jwt is off because the nightly job and the confirm page have no login; request/cancel check the login themselves.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { asLang, MAILS_PER_HOUR, newToken, sendAccountMail, siteUrl } from '../_shared/mail.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

const LINK_HOURS = 24;
const EXPORT_DAYS = 7;
const BUCKETS = ['materials', 'avatars', 'question-samples', 'ink', 'support', 'exports'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const url = Deno.env.get('SUPABASE_URL')!;
  const db = createClient(url, secretKey(), { auth: { persistSession: false } });
  const body = await req.json().catch(() => ({}));

  try {
    if (body.action === 'purge') {
      const key = req.headers.get('x-purge-key') ?? '';
      const { data: ok } = await db.rpc('check_purge_key', { key });
      if (!ok) return json({ error: 'forbidden' }, 403);
      return json(await purge(db));
    }

    if (body.action === 'confirm') {
      const { data, error } = await db.rpc('confirm_account_delete', { token: String(body.token ?? '') });
      if (error) throw error;
      return json(data, (data as { ok: boolean }).ok ? 200 : 400);
    }

    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const { data: who } = await db.auth.getUser(token);
    if (!who?.user) return json({ error: 'not signed in' }, 401);
    const uid = who.user.id;

    if (body.action === 'cancel') {
      await db.from('account_requests').update({ status: 'cancelled' }).eq('user_id', uid).eq('kind', 'delete').eq('status', 'confirmed');
      return json({ cancelled: true });
    }

    if (body.action === 'request') {
      const { data: open } = await db.from('account_requests').select('scheduled_for').eq('user_id', uid).eq('kind', 'delete').eq('status', 'confirmed').maybeSingle();
      if (open) return json({ scheduled_for: open.scheduled_for });
      const email = who.user.email;
      if (!email) return json({ error: 'no_email' }, 400);
      const since = new Date(Date.now() - 3_600_000).toISOString();
      const { count } = await db.from('account_requests').select('id', { count: 'exact', head: true }).eq('user_id', uid).eq('kind', 'delete').gte('created_at', since);
      if ((count ?? 0) >= MAILS_PER_HOUR) return json({ error: 'limit' }, 429);

      const { token, hash } = await newToken();
      const expires = new Date(Date.now() + LINK_HOURS * 3_600_000).toISOString();
      const { data: row, error: e2 } = await db.from('account_requests')
        .insert({ user_id: uid, kind: 'delete', status: 'pending', token_hash: hash, expires_at: expires }).select('id').single();
      if (e2) throw e2;
      const { data: prof } = await db.from('profiles').select('app_lang').eq('id', uid).maybeSingle();
      try {
        await sendAccountMail('delete', email, asLang(prof?.app_lang), `${siteUrl()}/account/delete#t=${token}`);
      } catch (e) {
        await db.from('account_requests').delete().eq('id', row.id);
        throw e;
      }
      return json({ sent: true });
    }
    return json({ error: 'action' }, 400);
  } catch (e) {
    console.error('delete-account', e);
    return json({ error: 'delete' }, 500);
  }
});

/** All files under "<user>/" in a bucket (folders are walked through). */
async function filesOf(db: SupabaseClient, bucket: string, prefix: string): Promise<string[]> {
  const out: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const { data, error } = await db.storage.from(bucket).list(prefix, { limit: 100, offset });
    if (error || !data?.length) break;
    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      if (item.id === null) out.push(...(await filesOf(db, bucket, path)));
      else out.push(path);
    }
    if (data.length < 100) break;
  }
  return out;
}

async function purge(db: SupabaseClient) {
  const { data: due } = await db.from('account_requests').select('user_id').eq('kind', 'delete').eq('status', 'confirmed').lte('scheduled_for', new Date().toISOString());
  let deleted = 0;
  for (const { user_id: uid } of due ?? []) {
    for (const bucket of BUCKETS) {
      const paths = await filesOf(db, bucket, uid);
      for (let i = 0; i < paths.length; i += 100) await db.storage.from(bucket).remove(paths.slice(i, i + 100));
    }
    // The login goes; profiles and every table with the student's rows follow by cascade.
    const { error } = await db.auth.admin.deleteUser(uid);
    if (error) console.error('purge', uid, error);
    else deleted++;
  }
  // Export files (export-data) live 7 days.
  const old = new Date(Date.now() - EXPORT_DAYS * 86_400_000).toISOString();
  const { data: exports } = await db.from('account_requests').select('id, file_path').eq('kind', 'export').not('file_path', 'is', null).lte('created_at', old);
  for (const x of exports ?? []) {
    const { error } = await db.storage.from('exports').remove([x.file_path]);
    if (!error) await db.from('account_requests').update({ file_path: null }).eq('id', x.id);
  }
  return { deleted, exports_removed: exports?.length ?? 0 };
}
