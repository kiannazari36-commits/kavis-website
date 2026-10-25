// Edge Function create-share: a share link for what the app made from a lesson — summary, cards, quiz — never the
// teacher's PDF (it belongs to the teacher). Premium only (CLAUDE.md). The link opens a web page that only says
// "download the app"; in the app a Premium receiver gets a copy of the shared items.
// POST { material_id, items: ('summary' | 'cards' | 'quiz')[] } → { slug } (403 when not Premium).
import { createClient } from 'npm:@supabase/supabase-js@2';

const ITEMS = ['summary', 'cards', 'quiz'];

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
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const materialId = typeof body.material_id === 'string' ? body.material_id : '';
  // Only the app's own items; anything else (like the PDF) is dropped.
  const items = [...new Set((Array.isArray(body.items) ? body.items : []).filter((x: unknown) => ITEMS.includes(String(x))))] as string[];
  if (!materialId || !items.length) return json({ error: 'items' }, 400);

  const { data: premium } = await db.rpc('is_premium', { uid });
  if (!premium) return json({ error: 'premium' }, 403);
  const { data: m } = await db.from('materials').select('user_id').eq('id', materialId).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);

  const { data: share, error } = await db.from('shares').insert({ user_id: uid, material_id: materialId, items }).select('slug').single();
  if (error) {
    console.error('shares', error);
    return json({ error: 'failed' }, 500);
  }
  return json({ slug: share.slug });
});
