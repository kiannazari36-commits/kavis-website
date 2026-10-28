// Edge Function redeem-code: a student types an invite code and gets free Premium for the days the code grants,
// counted from now. POST { code } → { ok: true, ends_at, days } | { ok: false, error, ends_at? } with error one of
// rate_limited | unknown | expired | used_up | already_redeemed | promo_active | already_premium.
// All the rules (and the 10-wrong-tries-per-hour limit) live in the SQL function redeem_promo_code; this function
// only checks the login and calls it with the service role (subscriptions are written by the server only).
import { createClient } from 'npm:@supabase/supabase-js@2';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);

  const body = await req.json().catch(() => ({}));
  const code = typeof body.code === 'string' ? body.code.slice(0, 40) : '';
  const { data, error } = await db.rpc('redeem_promo_code', { uid: who.user.id, raw_code: code });
  if (error || !data) return json({ ok: false, error: 'failed' }, 500);
  return json(data, data.ok || data.error !== 'rate_limited' ? 200 : 429);
});
