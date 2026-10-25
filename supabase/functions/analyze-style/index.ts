// Edge Function analyze-style: "Hocanın soru tarzı". Reads a course's question samples (photos, PDFs, pasted text —
// table question_samples, files in the private "question-samples" bucket) and finds how the lecturer asks:
// the share of each question type, the topics asked most, a few patterns and the usual number of options.
// POST { course_id } → the style. Writes (service role): teacher_styles, question_samples.question_count.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const MAX_FILE_BYTES = 15 * 1024 * 1024;

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

const costUsd = (input: number, output: number) => Math.round(((input * 2 + output * 10) / 1_000_000) * 10000) / 10000;
function toBase64(bytes: Uint8Array) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
const MIME: Record<string, string> = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', pdf: 'application/pdf' };

const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });
const int = { type: 'integer' };
const str = { type: 'string' };
const SCHEMA = obj({
  samples: { type: 'array', items: obj({ sample: int, questions: int }) },
  types: obj({ case: int, side_effects: int, dose: int, knowledge: int, structure: int }),
  options: int,
  top_topics: { type: 'array', items: obj({ title: str, count: int }) },
  patterns: { type: 'array', items: str },
});
type Out = {
  samples: { sample: number; questions: number }[];
  types: Record<'case' | 'side_effects' | 'dose' | 'knowledge' | 'structure', number>;
  options: number;
  top_topics: { title: string; count: number }[];
  patterns: string[];
};

const SYSTEM = (lang: string) => `You study a university lecturer's exam questions (old exams, questions given in class) for a study app, to learn how this lecturer asks.
You get several samples (numbered S1, S2, …): photos, PDFs or pasted text. Return JSON:
- samples: for each sample its number and how many questions it holds.
- types: the share of each question type in percent (all five add up to 100): case = patient case ("which drug?"), side_effects = side effects / interactions / contraindications, dose = mechanism, dose and calculations, knowledge = plain facts and definitions, structure = chemical structure / formulation / technology.
- options: the usual number of options in multiple-choice questions (0 if they are not multiple choice).
- top_topics: the topics asked most (at most 6), with how many questions were about each; use the course's topic names when one fits.
- patterns: 2-5 short notes on how the lecturer asks (e.g. "Cases are 2-3 sentences and start with age and sex", "Often asks which drug must NOT be given"). Write them in ${lang}.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const courseId = body.course_id;
  if (typeof courseId !== 'string') return json({ error: 'course_id' }, 400);
  const { data: course } = await db.from('courses').select('user_id, name').eq('id', courseId).maybeSingle();
  if (!course || course.user_id !== uid) return json({ error: 'not found' }, 404);

  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const { data: samples } = await db.from('question_samples').select('id, kind, title, storage_path, text').eq('course_id', courseId).order('created_at');
  if (!samples?.length) return json({ error: 'no samples' }, 400);

  try {
    const blocks = await sampleBlocks(db, samples);
    const { data: topics } = await db.from('material_topics').select('title, materials!inner(course_id)').eq('materials.course_id', courseId).limit(60);
    const { data: profile } = await db.from('profiles').select('app_lang').eq('id', uid).single();
    const langName = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' }[profile?.app_lang as string] ?? 'Turkish';
    blocks.push({ type: 'text', text: `Course: ${course.name}\nThe course's topics: ${(topics ?? []).map((t) => t.title).join('; ') || '-'}` });

    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 4000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'medium', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM(langName),
      messages: [{ role: 'user', content: blocks }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
    const block = res.content.find((b) => b.type === 'text');
    if (!block || block.type !== 'text') return json({ error: 'ai' }, 502);
    const out = JSON.parse(block.text) as Out;

    for (const s of out.samples) {
      const row = samples[s.sample - 1];
      if (row) await db.from('question_samples').update({ question_count: Math.max(0, s.questions) }).eq('id', row.id);
    }
    const style = {
      course_id: courseId,
      user_id: uid,
      distribution: { types: out.types, options: out.options, patterns: out.patterns.slice(0, 5), questions: out.samples.reduce((a, s) => a + s.questions, 0) },
      top_topics: out.top_topics.slice(0, 6),
      analyzed_at: new Date().toISOString(),
    };
    await db.from('teacher_styles').upsert(style, { onConflict: 'course_id' });
    await db.from('usage_monthly').upsert({
      user_id: uid,
      month,
      input_tokens: Number(use?.input_tokens ?? 0) + res.usage.input_tokens,
      output_tokens: Number(use?.output_tokens ?? 0) + res.usage.output_tokens,
      cost_usd: Number(use?.cost_usd ?? 0) + costUsd(res.usage.input_tokens, res.usage.output_tokens),
      generations: Number(use?.generations ?? 0) + 1,
    });
    return json(style);
  } catch (e) {
    console.error('analyze-style', e);
    return json({ error: 'ai' }, 502);
  }
});

/** Each sample as a numbered block: text as it is, a photo as an image, a PDF as a document. */
async function sampleBlocks(db: SupabaseClient, samples: { kind: string; title: string | null; storage_path: string | null; text: string | null }[]) {
  const blocks: unknown[] = [];
  for (const [i, s] of samples.entries()) {
    blocks.push({ type: 'text', text: `S${i + 1}${s.title ? ` (${s.title})` : ''}:` });
    if (s.kind === 'text' || !s.storage_path) {
      blocks.push({ type: 'text', text: (s.text ?? '').slice(0, 20000) || '(empty)' });
      continue;
    }
    const { data: blob } = await db.storage.from('question-samples').download(s.storage_path);
    if (!blob || blob.size > MAX_FILE_BYTES) {
      blocks.push({ type: 'text', text: '(file could not be read)' });
      continue;
    }
    const mime = MIME[s.storage_path.split('.').pop()?.toLowerCase() ?? ''] ?? 'image/jpeg';
    const data = toBase64(new Uint8Array(await blob.arrayBuffer()));
    blocks.push(mime === 'application/pdf' ? { type: 'document', source: { type: 'base64', media_type: mime, data } } : { type: 'image', source: { type: 'base64', media_type: mime, data } });
  }
  return blocks;
}
