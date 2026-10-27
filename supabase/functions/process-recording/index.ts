// Edge Function process-recording: a lecture recording turned into text on the student's device.
// POST { material_id, segments: [{ start, end, text }], duration } — the audio lesson row (kind 'audio',
// linked_material_id → its PDF lesson) is made by the app first. Only the text comes here, never the sound.
// The AI matches parts of the talk to the PDF's pages and topics and finds what the lecturer stressed (time spent,
// repeats, "sınavda soruyorum"). Writes (service role): material_content.lecture of the recording,
// material_topics.teacher_* of the PDF lesson, materials.status, usage_monthly.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { cleanSegments, costUsd, transcriptLines, type Segment } from './lib.ts';

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
/** PDF text sent per page (enough to recognise it). */
const PAGE_CHARS = 1200;

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

const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });
const int = { type: 'integer' };
const SCHEMA = obj({
  parts: { type: 'array', items: obj({ start: int, end: int, page: int, topic: int }) },
  topics: { type: 'array', items: obj({ topic: int, minutes: { type: 'number' }, repeats: int, said_exam: { type: 'boolean' } }) },
  quotes: { type: 'array', items: obj({ at: int, topic: int, kind: { type: 'string', enum: ['exam', 'stress'] }, text: { type: 'string' } }) },
});
type Out = {
  parts: { start: number; end: number; page: number; topic: number }[];
  topics: { topic: number; minutes: number; repeats: number; said_exam: boolean }[];
  quotes: { at: number; topic: number; kind: 'exam' | 'stress'; text: string }[];
};

const SYSTEM = `You match a recorded university lecture to the lecturer's PDF for a study app.
You get the PDF's pages ([Page n]), its topics (T0, T1, … with their pages) and the transcript of the recording: lines "[s] text", where s is the second the line starts. The transcript was made by speech recognition, so some words may be wrong.
Return JSON:
- parts: the lecture cut into consecutive parts by what is being explained (usually 1-5 minutes each), covering the whole recording: start and end second, the PDF page it matches (0 if none) and the topic number (-1 if none).
- topics: for each topic the lecturer talked about: minutes spent on it, how many times they came back to it (repeats), and said_exam = true only if they said it will be in the exam (e.g. "sınavda soruyorum", "bu çıkar", "bunu bilin").
- quotes: at most 8 short moments worth seeing: kind "exam" when the lecturer says something will be in the exam, "stress" when they insist that something is very important. at = second, text = their words copied from the transcript (shortened, never invented), topic = topic number or -1.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  // After the trial only Premium may start new AI work (CLAUDE.md); the web's lock is only for show.
  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);

  const body = await req.json().catch(() => ({}));
  const id = body.material_id;
  if (typeof id !== 'string') return json({ error: 'material_id' }, 400);
  const segments = cleanSegments(body.segments);
  if (!segments) return json({ error: 'segments' }, 400);
  const duration = Math.max(Number(body.duration) || 0, Math.ceil(segments[segments.length - 1].end));

  const { data: m } = await db.from('materials').select('user_id, kind, status, linked_material_id').eq('id', id).maybeSingle();
  if (!m || m.user_id !== uid || m.kind !== 'audio' || !m.linked_material_id) return json({ error: 'not found' }, 404);
  if (m.status !== 'uploaded' && m.status !== 'failed') return json({ status: m.status });
  const { data: pdf } = await db.from('materials').select('user_id, status, title, language').eq('id', m.linked_material_id).maybeSingle();
  if (!pdf || pdf.user_id !== uid || pdf.status !== 'ready') return json({ error: 'lesson not ready' }, 409);

  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  await db.from('materials').update({ status: 'processing', error: null, duration_sec: duration }).eq('id', id);
  EdgeRuntime.waitUntil(run(db, uid, id, m.linked_material_id, pdf.title, pdf.language, segments, duration));
  return json({ status: 'processing' }, 202);
});

async function run(db: SupabaseClient, uid: string, id: string, pdfId: string, title: string, language: string | null, segments: Segment[], duration: number) {
  try {
    const [{ data: pages }, { data: topics }] = await Promise.all([
      db.from('material_chunks').select('page, text').eq('material_id', pdfId).order('page'),
      db.from('material_topics').select('id, title, page_from, page_to').eq('material_id', pdfId).order('sort_order'),
    ]);
    const topicList = topics ?? [];
    const pdfText = (pages ?? []).map((p) => `[Page ${p.page}] ${String(p.text).slice(0, PAGE_CHARS)}`).join('\n');
    const topicText = topicList.map((t, i) => `T${i}: ${t.title} (pages ${t.page_from ?? '?'}-${t.page_to ?? '?'})`).join('\n');
    const user = `Lesson: ${title}\n\nPDF pages:\n${pdfText}\n\nTopics:\n${topicText || '(none)'}\n\nTranscript (${Math.round(duration / 60)} minutes):\n${transcriptLines(segments).join('\n')}`;

    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 16000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'medium', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      messages: [{ role: 'user', content: user }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') throw new Error('the AI declined this recording');
    if (res.stop_reason === 'max_tokens') throw new Error('the AI answer was cut off');
    const block = res.content.find((b) => b.type === 'text');
    if (!block || block.type !== 'text') throw new Error('no answer from the AI');
    const out = JSON.parse(block.text) as Out;

    // Topic numbers → the PDF's topic ids; the lecturer's emphasis goes onto the PDF's topics.
    const topicId = (n: number) => topicList[n]?.id ?? null;
    for (const t of out.topics) {
      const tid = topicId(t.topic);
      if (!tid) continue;
      await db
        .from('material_topics')
        .update({ teacher_minutes: Math.round(t.minutes * 10) / 10, teacher_repeats: Math.max(0, t.repeats), teacher_said_exam: t.said_exam })
        .eq('id', tid);
    }
    const lecture = {
      pdf_id: pdfId,
      duration,
      segments,
      parts: out.parts.map((p) => ({ ...p, topic_id: topicId(p.topic) })),
      topics: out.topics.filter((t) => topicId(t.topic)).map((t) => ({ ...t, topic_id: topicId(t.topic), title: topicList[t.topic].title })),
      quotes: out.quotes.slice(0, 8).map((q) => ({ ...q, topic_id: topicId(q.topic) })),
    };
    await db.from('material_content').upsert({
      material_id: id,
      user_id: uid,
      reader_doc: { language: language ?? 'tr', sections: [] },
      lecture,
      stats: { minutes: Math.round(duration / 60), parts: out.parts.length, exam_quotes: out.quotes.filter((q) => q.kind === 'exam').length },
    });
    await saveUsage(db, uid, res.usage.input_tokens, res.usage.output_tokens);
    await db.from('materials').update({ status: 'ready', processed_at: new Date().toISOString(), language }).eq('id', id);
  } catch (e) {
    console.error('process-recording', id, e);
    await db.from('materials').update({ status: 'failed', error: String((e as Error).message ?? e).slice(0, 300) }).eq('id', id);
  }
}

async function saveUsage(db: SupabaseClient, uid: string, input: number, output: number) {
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: u } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations').eq('user_id', uid).eq('month', month).maybeSingle();
  await db.from('usage_monthly').upsert({
    user_id: uid,
    month,
    input_tokens: Number(u?.input_tokens ?? 0) + input,
    output_tokens: Number(u?.output_tokens ?? 0) + output,
    cost_usd: Number(u?.cost_usd ?? 0) + costUsd(input, output),
    generations: Number(u?.generations ?? 0) + 1,
  });
}
