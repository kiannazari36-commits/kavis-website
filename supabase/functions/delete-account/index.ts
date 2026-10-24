// Edge Function delete-account: "Hesabı sil".
// POST { action: 'request', password } → the password is checked once more, then the account is deleted in 30 days
//   (account_requests: kind 'delete', status 'confirmed', scheduled_for). → { scheduled_for } or 403 { error: 'password' }
// POST { action: 'cancel' }            → "Vazgeç" within the 30 days.
// POST { action: 'purge' } + header x-purge-key (the nightly job, migration 20261025120000_account_purge.sql)
//   → deletes the accounts whose 30 days are over: their files in Storage, then the login (every table goes with it).
// verify_jwt is off because the nightly job has no login; request/cancel check the student's login themselves.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

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
function publicKey() {
  const legacy = Deno.env.get('SUPABASE_ANON_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

const WAIT_DAYS = 30;
const BUCKETS = ['materials', 'avatars', 'question-samples', 'ink', 'support'];

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

    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const { data: who } = await db.auth.getUser(token);
    if (!who?.user) return json({ error: 'not signed in' }, 401);
    const uid = who.user.id;

    if (body.action === 'cancel') {
      await db.from('account_requests').update({ status: 'cancelled' }).eq('user_id', uid).eq('kind', 'delete').eq('status', 'confirmed');
      return json({ cancelled: true });
    }

    if (body.action === 'request') {
      // The password once more, with a separate login that is closed right away.
      const check = createClient(url, publicKey(), { auth: { persistSession: false, autoRefreshToken: false } });
      const { error } = await check.auth.signInWithPassword({ email: who.user.email ?? '', password: String(body.password ?? '') });
      if (error) return json({ error: 'password' }, 403);
      await check.auth.signOut({ scope: 'local' });

      const { data: open } = await db.from('account_requests').select('scheduled_for').eq('user_id', uid).eq('kind', 'delete').eq('status', 'confirmed').maybeSingle();
      if (open) return json({ scheduled_for: open.scheduled_for });
      const scheduled = new Date(Date.now() + WAIT_DAYS * 86_400_000).toISOString();
      const { error: e2 } = await db.from('account_requests').insert({ user_id: uid, kind: 'delete', status: 'confirmed', scheduled_for: scheduled });
      if (e2) throw e2;
      return json({ scheduled_for: scheduled });
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
  return { deleted };
}
