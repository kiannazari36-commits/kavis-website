// Edge Function lesson-summary: the short review summary of one lesson ("Ders özeti · tekrar için kısa özet").
// POST { material_id } → { points: [{ text, page_from, page_to }], lang }. Made once by the AI from the lecturer's
// own text (only facts from the PDF, with the pages) and kept in summaries (kind 'lesson'); later calls read it.
// The student's weak topics (what they asked to add, wrong answers) get more detail and are marked (weak = true);
// when the weak list changes, the summary is made again (once per change).
// Making a new one needs the trial or Premium ("generate"); reading a saved one is always allowed.
// Writes (service role): summaries, usage_monthly.
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { costUsd } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const MAX_CHARS = 30000;

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

const LANG_NAMES: Record<string, string> = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' };
const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });
const SCHEMA = obj({
  points: { type: 'array', items: obj({ text: { type: 'string' }, page_from: { type: 'integer' }, page_to: { type: 'integer' }, weak: { type: 'boolean' } }) },
});
type Point = { text: string; page_from: number; page_to: number; weak: boolean };

const SYSTEM = `You write the short review summary of one university lesson for a study app, from the lecturer's own text.
Write 5-8 points that cover the whole lesson in order (up to 10 when the student has weak topics: give each weak topic 1-2 extra points with the details to remember, and set weak = true on those points, false on the others): each point one or two short sentences with the key facts to remember (names, numbers, mechanisms, contraindications), page_from and page_to = the pages it comes from. Only facts from the given pages, nothing added. Plain text, no markdown.
Write everything in the CONTENT LANGUAGE given.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const materialId = body.material_id;
  if (typeof materialId !== 'string') return json({ error: 'material_id' }, 400);
  const { data: m } = await db.from('materials').select('user_id, course_id, title').eq('id', materialId).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);

  // The student's weak topics in this lesson; the summary is kept per weak list.
  type Topic = { id: string; title: string; page_from: number | null; page_to: number | null };
  const { data: weakRows } = await db
    .from('material_topics')
    .select('id, title, page_from, page_to, topic_progress!inner(state)')
    .eq('material_id', materialId)
    .eq('topic_progress.user_id', uid)
    .eq('topic_progress.state', 'weak');
  const weak = ((weakRows ?? []) as Topic[]).sort((a, b) => (a.page_from ?? 0) - (b.page_from ?? 0));
  const weakKey = weak.map((t) => t.id).sort().join(',');

  // A saved summary for the same weak list: free, also after the trial (the student keeps their summaries).
  const { data: saved } = await db.from('summaries').select('content, lang').eq('material_id', materialId).eq('kind', 'lesson')
    .order('created_at', { ascending: false }).limit(1).maybeSingle();
  const savedContent = saved?.content as { points?: Point[]; weakKey?: string } | undefined;
  if (saved && (savedContent?.weakKey ?? '') === weakKey) return json({ points: savedContent?.points ?? [], lang: saved.lang });

  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  // After the trial a new one cannot be made: the saved one stays.
  if (!allowed) return saved ? json({ points: savedContent?.points ?? [], lang: saved.lang }) : json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations, cache_read_tokens, cache_write_tokens').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const [{ data: chunks }, { data: quiz }] = await Promise.all([
    db.from('material_chunks').select('page, text').eq('material_id', materialId).order('page'),
    db.from('quizzes').select('lang').eq('material_id', materialId).eq('kind', 'lesson_end').maybeSingle(),
  ]);
  if (!chunks?.length) return json({ error: 'no text' }, 400);
  // Long lessons: each page shortened so the whole lesson fits.
  const per = Math.max(300, Math.floor(MAX_CHARS / chunks.length));
  const text = chunks.map((c) => `[p.${c.page}] ${String(c.text).slice(0, per)}`).join('\n');
  const lang = quiz?.lang ?? 'tr';

  try {
    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 4000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      // The lesson text comes first and is cached (a new summary after the weak list changed reads it from the cache).
      messages: [{ role: 'user', content: [
        { type: 'text', text: `Lesson: ${m.title}\n\nPages:\n${text}`, cache_control: { type: 'ephemeral' } },
        { type: 'text', text: `CONTENT LANGUAGE: ${LANG_NAMES[lang] ?? 'Turkish'}\n\nThe student's weak topics: ${weak.length ? '\n' + weak.map((t) => `- ${t.title} (p.${t.page_from ?? '?'}-${t.page_to ?? t.page_from ?? '?'})`).join('\n') : 'none'}` },
      ] }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
    const block = res.content.find((b) => b.type === 'text');
    if (res.stop_reason === 'max_tokens' || !block || block.type !== 'text') return json({ error: 'ai' }, 502);
    const points = (JSON.parse(block.text) as { points: Point[] }).points.slice(0, 10);
    await db.from('summaries').insert({ user_id: uid, course_id: m.course_id, material_id: materialId, lang, kind: 'lesson', content: { points, weakKey } });
    const cw = res.usage.cache_creation_input_tokens ?? 0;
    const cr = res.usage.cache_read_input_tokens ?? 0;
    await db.from('usage_monthly').upsert({
      user_id: uid,
      month,
      input_tokens: Number(use?.input_tokens ?? 0) + res.usage.input_tokens + cw + cr,
      output_tokens: Number(use?.output_tokens ?? 0) + res.usage.output_tokens,
      cost_usd: Number(use?.cost_usd ?? 0) + costUsd(res.usage.input_tokens, res.usage.output_tokens, cw, cr),
      cache_write_tokens: Number(use?.cache_write_tokens ?? 0) + cw,
      cache_read_tokens: Number(use?.cache_read_tokens ?? 0) + cr,
      generations: Number(use?.generations ?? 0) + 1,
    });
    return json({ points, lang });
  } catch (e) {
    console.error('lesson-summary', e);
    return json({ error: 'ai' }, 502);
  }
});
