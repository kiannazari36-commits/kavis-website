// Edge Function apple-link: after "Sign in with Apple" the iPhone app sends the one-time authorization code Apple gave it.
// POST { authorization_code } (signed in) → exchanges it at Apple for a refresh token and keeps it in the account's
// app_metadata (server side only; the student cannot read or change it). delete-account revokes that token when the
// account is purged, as Apple requires. Needs the Apple secrets (APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID,
// APPLE_PRIVATE_KEY); without them it answers { linked: false } and nothing happens. Never blocks sign-in: the app ignores errors.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { appleEnvFrom, exchangeAppleCode } from '../_shared/apple-revoke.ts';

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
  const { data: who } = await db.auth.getUser((req.headers.get('Authorization') ?? '').replace('Bearer ', ''));
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const body = await req.json().catch(() => ({}));
  const code = typeof body.authorization_code === 'string' ? body.authorization_code.slice(0, 2000) : '';
  if (!code) return json({ error: 'code' }, 400);
  const refresh = await exchangeAppleCode(code, appleEnvFrom((k) => Deno.env.get(k)), fetch);
  if (!refresh) return json({ linked: false });
  const { error } = await db.auth.admin.updateUserById(who.user.id, { app_metadata: { ...who.user.app_metadata, apple_refresh_token: refresh } });
  if (error) {
    console.error('apple-link', error);
    return json({ linked: false });
  }
  return json({ linked: true });
});
