// Edge Function owner-overview (was admin-stats; renamed because ad blockers block "…-stats" addresses): the owner's page (/admin) — how many people signed up, who they are, trial / Premium,
// lessons and AI cost (per student this month, total vs. the budget line, cache hit share). Only the app owner may call it: their user id is below (ADMIN_USER_IDS overrides it, e.g.
// for the local test copy). Read only. E-mails are personal data (KVKK): only for running the app.
// POST {} → { totals, users: [{ email, joined, lastLogin, confirmed, status, lessons, questions, cost }] }
import { createClient } from 'npm:@supabase/supabase-js@2';

const OWNER = '9a69763b-e12c-4e47-a993-739188d9d652';
const TRIAL_DAYS = 3;
// The whole month's AI budget for all students together (US dollars): the spend board draws its line here. Easy to change.
const MONTHLY_TOTAL_BUDGET_USD = 150;

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

function cacheShare(rows: { input_tokens: number | string; cache_read_tokens: number | string }[]) {
  const input = rows.reduce((a, r) => a + Number(r.input_tokens), 0);
  const read = rows.reduce((a, r) => a + Number(r.cache_read_tokens), 0);
  return input > 0 ? Math.round((read / input) * 1000) / 1000 : 0;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const admins = (Deno.env.get('ADMIN_USER_IDS') ?? OWNER).split(',').map((x) => x.trim());
  if (!admins.includes(who.user.id)) return json({ error: 'not admin' }, 403);

  const month = new Date().toISOString().slice(0, 7) + '-01';
  const [{ data: list }, { data: profiles }, { data: lessons }, { data: usage }, { data: subs }] = await Promise.all([
    db.auth.admin.listUsers({ perPage: 1000 }),
    db.from('profiles').select('id, full_name, trial_started_at'),
    db.from('materials').select('user_id, created_at'),
    db.from('usage_monthly').select('user_id, cost_usd, assistant_questions, input_tokens, cache_read_tokens, cache_write_tokens').eq('month', month),
    db.from('subscriptions').select('user_id, status, expires_at'),
  ]);

  const now = Date.now();
  const monthStart = new Date(month).getTime();
  const DAY = 86_400_000;
  const users = (list?.users ?? []).map((u) => {
    const p = (profiles ?? []).find((x) => x.id === u.id);
    const premium = (subs ?? []).some(
      (s) => s.user_id === u.id && ['active', 'grace', 'billing_retry'].includes(s.status) && (!s.expires_at || new Date(s.expires_at).getTime() > now),
    );
    const trialEnds = p ? new Date(p.trial_started_at).getTime() + TRIAL_DAYS * DAY : 0;
    const use = (usage ?? []).find((x) => x.user_id === u.id);
    return {
      email: u.email ?? '',
      name: p?.full_name ?? '',
      joined: u.created_at,
      lastLogin: u.last_sign_in_at ?? null,
      confirmed: !!u.email_confirmed_at,
      status: premium ? 'premium' : trialEnds > now ? 'trial' : 'ended',
      lessons: (lessons ?? []).filter((m) => m.user_id === u.id).length,
      lessonsMonth: (lessons ?? []).filter((m) => m.user_id === u.id && new Date(m.created_at).getTime() >= monthStart).length,
      questions: Number(use?.assistant_questions ?? 0),
      cost: Math.round(Number(use?.cost_usd ?? 0) * 100) / 100,
    };
  });
  users.sort((a, b) => b.joined.localeCompare(a.joined));

  const since = (iso: string | null, days: number) => !!iso && now - new Date(iso).getTime() < days * DAY;
  const totals = {
    users: users.length,
    new7: users.filter((u) => since(u.joined, 7)).length,
    active7: users.filter((u) => since(u.lastLogin, 7)).length,
    premium: users.filter((u) => u.status === 'premium').length,
    trial: users.filter((u) => u.status === 'trial').length,
    ended: users.filter((u) => u.status === 'ended').length,
    lessons: (lessons ?? []).length,
    costMonth: Math.round(users.reduce((a, u) => a + u.cost, 0) * 100) / 100,
    budget: MONTHLY_TOTAL_BUDGET_USD,
    // Share of the month's input tokens that were read from the prompt cache (cache reads cost a tenth).
    cacheShare: cacheShare(usage ?? []),
  };
  return json({ totals, users });
});
