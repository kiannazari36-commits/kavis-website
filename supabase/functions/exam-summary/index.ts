// Edge Function exam-summary: "Sınav özeti". From the topics asked in the lecturer's sample questions, the AI writes a
// reading page: an overview (which PDF, which topic, which question style), then every asked topic explained fully from
// the student's own PDFs, the points the questions test and how they were asked. Only the student's PDFs are used.
// POST { course_id } → { material_id, topics }. Step 1 reads the samples (photos, PDFs, text) and finds the topics with
// search words (figure-only questions are listed apart); the pages of each topic are then found by searching the
// lesson text (material_chunks), not guessed; step 2 explains each topic from those pages only (in parallel), or says
// "not found in the PDFs". The result is a lesson row of kind
// exam_summary (+ material_content, material_chunks for the assistant, material_topics), replacing an older one.
// Writes (service role): materials, material_content, material_chunks, material_topics, usage_monthly.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { buildDoc, pageTexts, pickPages, searchTerms, tsQuery, WORDS, type Lang, type StyleKey, type Topic } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const MAX_FILE_BYTES = 15 * 1024 * 1024;
/** Lesson text sent per topic (about 5,000 tokens). */
const PAGE_CHARS = 16000;

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
const LANG_NAMES: Record<string, string> = { tr: 'Turkish', en: 'English', fa: 'Persian', ar: 'Arabic' };
const STYLES: StyleKey[] = ['case', 'side_effects', 'dose', 'knowledge', 'structure'];

const obj = (properties: Record<string, unknown>) => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false });
const int = { type: 'integer' };
const str = { type: 'string' };
const FIND = obj({
  topics: {
    type: 'array',
    items: obj({ title: str, search: { type: 'array', items: str }, questions: int, lesson: int, page_from: int, page_to: int, styles: { type: 'array', items: { type: 'string', enum: STYLES } }, points: { type: 'array', items: str }, examples: { type: 'array', items: str } }),
  },
  skipped: { type: 'array', items: obj({ sample: int, reason: str }) },
});
const EXPLAIN = obj({ found: { type: 'boolean' }, parts: { type: 'array', items: obj({ heading: str, text: str }) } });
type Found = {
  topics: { title: string; search: string[]; questions: number; lesson: number; page_from: number; page_to: number; styles: StyleKey[]; points: string[]; examples: string[] }[];
  skipped: { sample: number; reason: string }[];
};

const FIND_SYSTEM = `You read a lecturer's sample exam questions (photos, PDFs or text, numbered S1, S2, …) and the outline of the student's lessons (L1, L2, … with their topics and pages), for a study app.
Find the topics the sample questions are about: at most 8, the most asked first, near-duplicates merged. For each topic return:
- title: the topic name, in the wording of the lesson outline when one fits.
- search: 3-6 words or short terms the lesson text itself would use on the pages that teach this topic (drug names, key terms, the outline's words), in the LESSONS' language, so the pages can be found by text search.
- questions: how many sample questions are about it.
- lesson and page_from / page_to: where the lesson teaches it, taken from the outline (the closest outline topic when unsure).
- styles: the question types asked on it (case = patient case, side_effects = side effects / interactions, dose = mechanism / dose / calculation, knowledge = plain facts, structure = structure / formulation).
- points: what the questions ask about, at most 5, each short, worded from the question texts only. Never answer the questions and never add facts of your own (no "X causes Y" unless the question says it).
- examples: up to 2 question texts from the samples, copied as written, without answers.
Only topics the samples really ask about.
A question that is only a figure, image, drawing, structure or graph, with too little readable text to know its topic: make no topic from it; list it in skipped (sample = its S number, reason = a short note like "figure question, topic not readable", in the CONTENT LANGUAGE). A question whose figure is labelled clearly enough to know the topic counts normally. Write title, points and reasons in the CONTENT LANGUAGE; copy examples as they are.`;

const EXPLAIN_SYSTEM = `You explain one exam topic fully to a student, using ONLY the lesson pages given, for a study app.
First decide found: true when the pages really teach this topic, false when they do not (then return no parts).
Cover everything the pages say about the topic, not only the asked points, in an organised order: 3-8 parts, each a heading and a paragraph of 3-6 sentences.
Every sentence must be stated or directly shown by the pages. Do not use your own knowledge, even when you are sure; do not add causes, results, mechanisms, examples or numbers the pages do not give; when the pages and your knowledge differ, follow the pages. Keep the lecturer's terms, drug names, numbers, doses and thresholds exactly as in the pages. If an asked point is not covered by the pages, leave it out silently. Write it as a plain study text: never mention "the pages" or what they do or do not cover, and never mention the exam or its questions inside the explanation. Mention the page like "(s. 12)" where a fact comes from, in the CONTENT LANGUAGE's usual way.
Write everything in the CONTENT LANGUAGE.`;

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
  const { data: course } = await db.from('courses').select('user_id, name, language, content_lang_override').eq('id', courseId).maybeSingle();
  if (!course || course.user_id !== uid) return json({ error: 'not found' }, 404);

  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const [{ data: samples }, { data: lessons }, { data: settings }, { data: profile }] = await Promise.all([
    db.from('question_samples').select('id, kind, title, storage_path, text').eq('course_id', courseId).order('created_at'),
    db.from('materials').select('id, title, language').eq('course_id', courseId).eq('status', 'ready').in('kind', ['pdf', 'photo']).order('created_at'),
    db.from('user_settings').select('content_lang').eq('user_id', uid).single(),
    db.from('profiles').select('app_lang').eq('id', uid).single(),
  ]);
  if (!samples?.length) return json({ error: 'no samples' }, 400);
  if (!lessons?.length) return json({ error: 'no lessons' }, 400);

  // Content language (CLAUDE.md): the course's choice, then the general setting; "pdf" = the lessons' language.
  const choice = course.content_lang_override ?? settings?.content_lang ?? 'pdf';
  const picked = choice === 'pdf' ? (lessons[0].language ?? course.language ?? 'tr') : choice === 'app' ? (profile?.app_lang ?? 'tr') : choice;
  const lang: Lang = picked in WORDS ? (picked as Lang) : 'tr';
  const langLine = `CONTENT LANGUAGE: ${LANG_NAMES[lang]}`;

  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  let input = 0;
  let output = 0;
  // deno-lint-ignore no-explicit-any
  const ask = async (system: string, content: unknown[], schema: unknown, maxTokens: number): Promise<any> => {
    const params = {
      model: MODEL,
      max_tokens: maxTokens,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'medium', format: { type: 'json_schema', schema } },
      system,
      messages: [{ role: 'user', content }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    input += res.usage.input_tokens;
    output += res.usage.output_tokens;
    const block = res.content.find((b) => b.type === 'text');
    if (res.stop_reason === 'refusal' || res.stop_reason === 'max_tokens' || !block || block.type !== 'text') throw new Error(`ai ${res.stop_reason}`);
    return JSON.parse(block.text);
  };

  try {
    // Step 1: the topics the samples ask about, with where the lessons teach them.
    const ids = lessons.map((l) => l.id);
    const { data: outline } = await db.from('material_topics').select('material_id, title, page_from, page_to').in('material_id', ids).order('sort_order');
    const outlineText = lessons
      .map((l, i) => `L${i + 1}: ${l.title}\n${(outline ?? []).filter((t) => t.material_id === l.id).map((t) => `  - ${t.title} (p.${t.page_from ?? '?'}-${t.page_to ?? '?'})`).join('\n')}`)
      .join('\n');
    const blocks = await sampleBlocks(db, samples);
    blocks.push({ type: 'text', text: `Course: ${course.name}\n${langLine}\n\nLesson outline:\n${outlineText}` });
    const found = (await ask(FIND_SYSTEM, blocks, FIND, 6000)) as Found;
    const wanted = found.topics.filter((t) => t.title.trim()).slice(0, 8);
    if (!wanted.length) return json({ error: 'no topics' }, 422);
    const skipped = (found.skipped ?? [])
      .filter((x) => samples[x.sample - 1])
      .map((x) => `${samples[x.sample - 1].title || `${WORDS[lang].sample} ${x.sample}`}: ${x.reason}`);

    // Step 2: every topic's pages found in the lesson text, then explained from those pages only, in parallel.
    const topics: Topic[] = await Promise.all(
      wanted.map(async (t) => {
        const guessed = lessons[t.lesson - 1] ?? lessons[0];
        const terms = searchTerms([t.title, ...(t.search ?? [])]);
        const { data: hits } = terms.length
          ? await db.from('material_chunks').select('material_id, page, text').in('material_id', ids).textSearch('search', tsQuery(terms), { config: 'simple' }).limit(300)
          : { data: [] };
        const guess = { materialId: guessed.id, from: Math.min(t.page_from, t.page_to), to: Math.max(t.page_from, t.page_to) };
        const place = pickPages(hits ?? [], terms, guess);
        // Nothing found by search: the AI's guess, which the explanation step may still refuse (found = false).
        const lesson = lessons.find((l) => l.id === place?.materialId) ?? guessed;
        const near = place ? [...new Set(place.pages.flatMap((p) => [p - 1, p, p + 1]))] : [];
        const query = db.from('material_chunks').select('page, text').eq('material_id', lesson.id);
        const { data: chunks } = await (place ? query.in('page', near) : query.gte('page', Math.max(1, guess.from - 1)).lte('page', guess.to + 1)).order('page');
        // The pages the search found first, then their neighbours while there is room.
        const order = [...(chunks ?? [])].sort((a, b) => Number(!place?.pages.includes(a.page)) - Number(!place?.pages.includes(b.page)));
        const used: typeof order = [];
        let size = 0;
        for (const c of order) {
          if (used.length && size + c.text.length > PAGE_CHARS) continue;
          used.push(c);
          size += c.text.length;
        }
        const text = used.sort((a, b) => a.page - b.page).map((c) => `[p.${c.page}] ${c.text}`).join('\n').slice(0, PAGE_CHARS);
        let parts: Topic['parts'] = [];
        if (text) {
          const r = await ask(EXPLAIN_SYSTEM, [{ type: 'text', text: `${langLine}\nTopic: ${t.title}\nWhat the exam asked about (use only what the pages say): ${t.points.join('; ') || '-'}\n\nLesson pages (${lesson.title}):\n${text}` }], EXPLAIN, 5000);
          if (r.found) parts = (r.parts as Topic['parts']).filter((p) => p.text.trim()).slice(0, 8);
        }
        return {
          title: t.title.trim(),
          questions: Math.max(1, t.questions),
          lessonTitle: lesson.title,
          // The overview names the pages the search found (or, without a search hit, the pages read).
          pages: !parts.length ? [] : place ? place.pages.filter((p) => used.some((c) => c.page === p)) : [...new Set(used.map((c) => c.page as number))],
          styles: t.styles.filter((s) => STYLES.includes(s)),
          points: t.points.filter(Boolean).slice(0, 5),
          examples: t.examples.filter(Boolean).slice(0, 2),
          parts,
        };
      }),
    );

    // Save it as a lesson of its own kind; the older summary goes only after the new one is saved.
    const pages = pageTexts(lang, topics);
    const { data: mat, error } = await db
      .from('materials')
      .insert({ user_id: uid, course_id: courseId, kind: 'exam_summary', title: `${WORDS[lang].title} · ${course.name}`, language: lang, page_count: pages.length, status: 'ready', processed_at: new Date().toISOString() })
      .select('id')
      .single();
    if (error) throw error;
    const saved = await Promise.all([
      db.from('material_content').insert({ material_id: mat.id, user_id: uid, reader_doc: buildDoc(lang, topics, skipped), stats: { pages: pages.length, topics: topics.length } }),
      db.from('material_chunks').insert(pages.map((p) => ({ material_id: mat.id, user_id: uid, page: p.page, text: p.text }))),
      db.from('material_topics').insert(topics.map((t, i) => ({ material_id: mat.id, user_id: uid, title: t.title, page_from: i + 2, page_to: i + 2, importance: 3, sort_order: i }))),
    ]);
    const failed = saved.find((r) => r.error);
    if (failed?.error) {
      await db.from('materials').delete().eq('id', mat.id);
      throw failed.error;
    }
    await db.from('materials').delete().eq('course_id', courseId).eq('kind', 'exam_summary').neq('id', mat.id);

    await db.from('usage_monthly').upsert({
      user_id: uid,
      month,
      input_tokens: Number(use?.input_tokens ?? 0) + input,
      output_tokens: Number(use?.output_tokens ?? 0) + output,
      cost_usd: Number(use?.cost_usd ?? 0) + costUsd(input, output),
      generations: Number(use?.generations ?? 0) + 1,
    });
    return json({ material_id: mat.id, topics: topics.length });
  } catch (e) {
    console.error('exam-summary', e);
    return json({ error: 'ai' }, 502);
  }
});

/** Each sample as a numbered block: text as it is, a photo as an image, a PDF as a document (same as analyze-style). */
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
