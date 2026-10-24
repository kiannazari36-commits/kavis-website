// Edge Function assistant: answers a student's question only from their own lessons (CLAUDE.md).
// POST { question, course_id?, material_id?, mode: 'pdf' | 'ai', thread_id?, lang }
//   → { thread_id, answer, sources: [{ material_id, lesson, page }], outside_pdf }
// Finds the best text pieces (material_chunks, full-text search), asks Claude Sonnet 5.5, saves the thread and both
// messages, counts a trial question and the AI cost. "AI + research" (mode 'ai') may add general knowledge,
// marked outside_pdf. Apps never write answers themselves.
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { costUsd, queryTerms, rankChunks, tsQuery } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const PIECES = 6;

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

const SCHEMA = {
  type: 'object',
  properties: {
    answer: { type: 'string' },
    sources: { type: 'array', items: { type: 'integer' } },
    outside_pdf: { type: 'boolean' },
  },
  required: ['answer', 'sources', 'outside_pdf'],
  additionalProperties: false,
};

const system = (mode: string, lang: string) => `You are Kavis, a study assistant for a university student. You answer from the student's own lecture material.
You get numbered excerpts [E1], [E2]… from the student's lessons (lesson name and page given), and maybe earlier messages of this chat.
${
  mode === 'ai'
    ? 'Answer mainly from the excerpts. If they are not enough, you may add general textbook knowledge; then set outside_pdf to true and say briefly which part is not from their PDFs.'
    : 'Answer ONLY from the excerpts. If they do not contain the answer, say clearly (in one or two sentences) that you could not find it in their lessons and suggest what to look for; do not use outside knowledge. outside_pdf is always false.'
}
Write in the language of the student's question (if unclear: ${LANG_NAMES[lang] ?? 'Turkish'}). Be short and clear: 2-6 sentences or a few bullet points, plain text without markdown headings. Explain simply, like a good classmate.
sources: the numbers of the excerpts you actually used (e.g. [2, 5]); empty if none.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const question = typeof body.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  if (!question) return json({ error: 'question' }, 400);
  const mode = body.mode === 'ai' ? 'ai' : 'pdf';
  const lang = typeof body.lang === 'string' ? body.lang : 'tr';
  const courseId: string | null = typeof body.course_id === 'string' ? body.course_id : null;
  const materialId: string | null = typeof body.material_id === 'string' ? body.material_id : null;

  // Trial / Premium, and the monthly AI budget.
  const { data: allowed } = await db.rpc('can_use', { feature: 'ask', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  // Which lessons to search: one lesson, one course, or all of the student's lessons.
  let lessons = db.from('materials').select('id, title').eq('user_id', uid).eq('status', 'ready');
  if (materialId) lessons = lessons.eq('id', materialId);
  else if (courseId) lessons = lessons.eq('course_id', courseId);
  const { data: mats } = await lessons;
  const titles = new Map((mats ?? []).map((m) => [m.id as string, m.title as string]));
  const ids = [...titles.keys()];

  let pieces: { id: number; material_id: string; page: number | null; text: string }[] = [];
  const terms = queryTerms(question);
  if (ids.length && terms.length) {
    const { data } = await db
      .from('material_chunks')
      .select('id, material_id, page, text')
      .in('material_id', ids)
      .textSearch('search', tsQuery(terms), { config: 'simple' })
      .limit(40);
    pieces = rankChunks(data ?? [], terms, PIECES);
  }

  // The thread: continue it, or start a new one.
  let threadId: string | null = typeof body.thread_id === 'string' ? body.thread_id : null;
  if (threadId) {
    const { data: th } = await db.from('assistant_threads').select('user_id').eq('id', threadId).maybeSingle();
    if (!th || th.user_id !== uid) threadId = null;
  }
  const history: { role: 'user' | 'assistant'; content: string }[] = [];
  if (threadId) {
    const { data: prev } = await db.from('assistant_messages').select('role, content').eq('thread_id', threadId).order('created_at', { ascending: false }).limit(6);
    history.push(...((prev ?? []).reverse() as typeof history));
  }

  const excerpts = pieces.length
    ? pieces.map((p, i) => `[E${i + 1}] (${titles.get(p.material_id) ?? ''}, page ${p.page ?? '?'})\n${p.text.slice(0, 2500)}`).join('\n\n')
    : '(no matching excerpts were found in the student\'s lessons)';

  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  const params = {
    model: MODEL,
    max_tokens: 4000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
    system: system(mode, lang),
    messages: [...history, { role: 'user', content: `Excerpts from my lessons:\n\n${excerpts}\n\nMy question: ${question}` }],
  };
  let res;
  try {
    // deno-lint-ignore no-explicit-any
    res = await client.beta.messages.create(params as any);
  } catch (e) {
    console.error('assistant', e);
    return json({ error: 'ai' }, 502);
  }
  if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
  const block = res.content.find((b) => b.type === 'text');
  if (!block || block.type !== 'text') return json({ error: 'ai' }, 502);
  const out = JSON.parse(block.text) as { answer: string; sources: number[]; outside_pdf: boolean };
  const used = [...new Set(out.sources)].map((n) => pieces[n - 1]).filter(Boolean);
  const sources = used.map((p) => ({ material_id: p.material_id, page: p.page }));

  // Save: thread, both messages, trial question, cost.
  if (!threadId) {
    const { data: th } = await db
      .from('assistant_threads')
      .insert({ user_id: uid, course_id: courseId, material_id: materialId, mode: 'chat', title: question.slice(0, 80) })
      .select('id')
      .single();
    threadId = th!.id;
  } else {
    await db.from('assistant_threads').update({ updated_at: new Date().toISOString() }).eq('id', threadId);
  }
  await db.from('assistant_messages').insert([
    { thread_id: threadId, user_id: uid, role: 'user', content: question, source_mode: mode },
    { thread_id: threadId, user_id: uid, role: 'assistant', content: out.answer, source_mode: mode, sources, outside_pdf: mode === 'ai' && out.outside_pdf },
  ]);
  const { data: premium } = await db.rpc('is_premium', { uid });
  if (!premium) {
    const { data: t } = await db.from('trial_usage').select('assistant_questions').eq('user_id', uid).maybeSingle();
    await db.from('trial_usage').upsert({ user_id: uid, assistant_questions: (t?.assistant_questions ?? 0) + 1 });
  }
  const input = res.usage.input_tokens;
  const output = res.usage.output_tokens;
  const { data: u } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, assistant_questions').eq('user_id', uid).eq('month', month).maybeSingle();
  await db.from('usage_monthly').upsert({
    user_id: uid,
    month,
    input_tokens: Number(u?.input_tokens ?? 0) + input,
    output_tokens: Number(u?.output_tokens ?? 0) + output,
    cost_usd: Number(u?.cost_usd ?? 0) + costUsd(input, output),
    assistant_questions: Number(u?.assistant_questions ?? 0) + 1,
  });

  return json({
    thread_id: threadId,
    answer: out.answer,
    sources: used.map((p) => ({ material_id: p.material_id, lesson: titles.get(p.material_id) ?? '', page: p.page })),
    outside_pdf: mode === 'ai' && out.outside_pdf,
  });
});
