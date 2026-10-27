// Edge Function build-plan: the Kavis study plan of the signed-in student (rules in planner.ts, no AI, free).
// POST { action: 'build' | 'light_day' | 'add_mistakes', today: 'YYYY-MM-DD' (the student's own date), course_id?, count? }
//   build        → makes the rest of this week (today … Sunday): done tasks and past days stay, the rest is made
//                  again from courses, exams, timetable, unread pages, weak topics and due cards.
//   light_day    → "Bugün az vaktim var": today keeps the 2 most important tasks, the others move to later days.
//   add_mistakes → "Yanlışları plana ekle": a 15-minute mistakes task tomorrow.
// Writes study_plans + plan_items with the service role (the apps only tick tasks off and move missed ones).
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { addDays, daysBetween, lightDay, mondayOf, TEXT, type Lang } from './planner.ts';
import { build, planFor } from './build.ts';

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

const LANGS = ['tr', 'en', 'fa', 'ar'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  // The student's own date (time zones); only a day away from the server's date is believed.
  const serverToday = new Date().toISOString().slice(0, 10);
  const today = typeof body.today === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(body.today) && Math.abs(daysBetween(serverToday, body.today)) <= 1 ? body.today : serverToday;

  const { data: profile } = await db.from('profiles').select('app_lang, created_at').eq('id', uid).single();
  const lang = (LANGS.includes(profile?.app_lang) ? profile!.app_lang : 'tr') as Lang;

  try {
    if (body.action === 'light_day') return json(await light(db, uid, today));
    if (body.action === 'add_mistakes') return json(await addMistakes(db, uid, today, lang, body.course_id ?? null, Number(body.count) || 0));
    return json(await build(db, uid, today, lang, profile?.created_at ?? null));
  } catch (e) {
    console.error('build-plan', e);
    return json({ error: 'plan' }, 500);
  }
});

async function light(db: SupabaseClient, uid: string, today: string) {
  const { data: plan } = await db.from('study_plans').select('id, plan_items(id, day, minutes, status, sort_order)').eq('user_id', uid).eq('week_start', mondayOf(today)).maybeSingle();
  const items = (plan?.plan_items ?? []) as { id: string; day: string; minutes: number; status: string; sort_order: number }[];
  const todays = items.filter((x) => x.day === today && x.status === 'todo');
  const later: Record<string, number> = {};
  for (const x of items) if (x.day > today && x.status === 'todo') later[x.day] = (later[x.day] ?? 0) + x.minutes;
  const r = lightDay(today, todays, later);
  for (const m of r.move) await db.from('plan_items').update({ day: m.day }).eq('id', m.id);
  // Sunday: no later day this week; next week's plan takes the work up again.
  const stay = new Set([...r.keep, ...r.move.map((m) => m.id)]);
  const rest = todays.filter((x) => !stay.has(x.id)).map((x) => x.id);
  if (rest.length) await db.from('plan_items').update({ status: 'removed' }).in('id', rest);
  return { kept: r.keep.length, moved: r.move.map((m) => m.day) };
}

async function addMistakes(db: SupabaseClient, uid: string, today: string, lang: Lang, courseId: string | null, count: number) {
  const day = addDays(today, 1);
  const planId = await planFor(db, uid, mondayOf(day));
  const { data: last } = await db.from('plan_items').select('sort_order').eq('plan_id', planId).eq('day', day).order('sort_order', { ascending: false }).limit(1);
  const T = TEXT[lang];
  const { error } = await db.from('plan_items').insert({
    plan_id: planId,
    user_id: uid,
    day,
    course_id: courseId,
    kind: 'mistakes',
    title: T.mistakes(),
    minutes: 15,
    why: T.mistakesWhy(Math.max(1, count)),
    target: 'cards',
    sort_order: (last?.[0]?.sort_order ?? -1) + 1,
  });
  if (error) throw error;
  return { day };
}
