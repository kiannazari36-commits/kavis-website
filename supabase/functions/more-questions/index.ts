// Edge Function more-questions: "Yeni 3 soru" after a section check — new questions about the same pages.
// POST { material_id, page_from, page_to, count? } → { quiz_id, ids }. The AI writes multiple-choice questions with
// hints from the lecturer's own text of those pages, different from the lesson's questions already there; they are
// added to the lesson's quiz (kind lesson_end) so they stay for later.
// Writes (service role): quiz_questions, usage_monthly. Needs the trial or Premium ("generate").
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { cleanHints, costUsd } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const MAX_CHARS = 12000;

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
  questions: {
    type: 'array',
    items: obj({
      style: { type: 'string', enum: ['case', 'side_effects', 'dose', 'knowledge', 'structure'] },
      text: { type: 'string' },
      options: { type: 'array', items: { type: 'string' } },
      answer_index: { type: 'integer' },
      explanation: { type: 'string' },
      page: { type: 'integer' },
      hints: { type: 'array', items: { type: 'string' } },
    }),
  },
});
type Out = { questions: { style: string; text: string; options: string[]; answer_index: number; explanation: string; page: number; hints: string[] }[] };

const SYSTEM = `You write new exam questions for one section of a university lesson in a study app, from the lecturer's own text.
Rules: only facts from the given pages; the questions must ask about DIFFERENT facts than the questions the student already had (listed), not the same question in other words. Exactly 5 options, answer_index 0-based, explanation = why the answer is right (1-2 sentences), page = where the answer is. 3 hints that help the student THINK: 1 = the key concept to recall, 2 = something that rules out some options, 3 = narrows it to about two options; hints never mention pages and never contain the answer.
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
  const from = Number(body.page_from) || 1;
  const to = Math.max(from, Number(body.page_to) || from);
  const count = Math.min(5, Math.max(1, Number(body.count) || 3));
  if (typeof materialId !== 'string') return json({ error: 'material_id' }, 400);

  const { data: m } = await db.from('materials').select('user_id, course_id, title').eq('id', materialId).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);
  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const [{ data: chunks }, { data: quiz }] = await Promise.all([
    db.from('material_chunks').select('page, text').eq('material_id', materialId).gte('page', from).lte('page', to).order('page'),
    db.from('quizzes').select('id, lang').eq('material_id', materialId).eq('kind', 'lesson_end').maybeSingle(),
  ]);
  if (!chunks?.length || !quiz) return json({ error: 'no text' }, 400);
  const { data: old } = await db.from('quiz_questions').select('text, sort_order').eq('quiz_id', quiz.id).order('sort_order');
  let text = '';
  for (const c of chunks) {
    const line = `[p.${c.page}] ${c.text}\n`;
    if (text.length + line.length > MAX_CHARS) break;
    text += line;
  }
  const lang = quiz.lang ?? 'tr';
  const user = `Lesson: ${m.title}\nCONTENT LANGUAGE: ${LANG_NAMES[lang] ?? 'Turkish'}\nWrite ${count} new questions about pages ${from}-${to}.\n\nQuestions the student already had (do not repeat):\n${(old ?? []).map((q) => '- ' + String(q.text).split('\n\n')[0]).join('\n') || '-'}\n\nPages:\n${text}`;

  try {
    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 6000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      messages: [{ role: 'user', content: user }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
    const block = res.content.find((b) => b.type === 'text');
    if (res.stop_reason === 'max_tokens' || !block || block.type !== 'text') return json({ error: 'ai' }, 502);
    const out = JSON.parse(block.text) as Out;
    const start = ((old ?? []).at(-1)?.sort_order ?? -1) + 1;
    const questions = out.questions
      .filter((q) => q.options.length >= 2 && q.answer_index >= 0 && q.answer_index < q.options.length)
      .slice(0, count)
      .map((q, i) => ({
        quiz_id: quiz.id,
        user_id: uid,
        sort_order: start + i,
        kind: 'multiple_choice',
        style_tag: q.style,
        text: q.text,
        options: q.options,
        answer_index: q.answer_index,
        explanation: q.explanation,
        // A page outside the section is moved into it, so the question belongs to this section's check.
        source_page: Math.min(to, Math.max(from, q.page || from)),
        hints: cleanHints(q.hints, q.options, q.answer_index).slice(0, 3),
      }));
    const { data: saved, error } = await db.from('quiz_questions').insert(questions).select('id');
    if (error) throw error;
    await db.from('usage_monthly').upsert({
      user_id: uid,
      month,
      input_tokens: Number(use?.input_tokens ?? 0) + res.usage.input_tokens,
      output_tokens: Number(use?.output_tokens ?? 0) + res.usage.output_tokens,
      cost_usd: Number(use?.cost_usd ?? 0) + costUsd(res.usage.input_tokens, res.usage.output_tokens),
      generations: Number(use?.generations ?? 0) + 1,
    });
    return json({ quiz_id: quiz.id, ids: (saved ?? []).map((r) => r.id) });
  } catch (e) {
    console.error('more-questions', e);
    return json({ error: 'ai' }, 502);
  }
});
