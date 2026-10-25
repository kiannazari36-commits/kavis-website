// Edge Function process-material: turns an uploaded lesson PDF into the reading page and study material.
// POST { material_id } by the student (Authorization: their login), then it continues by itself in batches of
// 8 pages (each batch calls itself for the next one, with the service key). Writes with the service role:
// materials.status / page_count, material_content (reader_doc + stats), material_terms, material_topics,
// material_chunks (assistant search), card_decks + flashcards, quizzes + quiz_questions, usage_monthly,
// and a "lesson ready" notification. The teacher's text is cut from the PDF, never written by the AI.
// Photos of pages and scanned PDFs (POST { material_id, ocr: true }) first go through text recognition (ocr.ts):
// the AI copies each page's text exactly, in batches of 4 pages, then the same steps follow.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { extractText, getDocumentProxy } from 'npm:unpdf';
import { PDFDocument } from 'npm:pdf-lib@1.17.1';
import { OCR_SCHEMA, OCR_SYSTEM, pageTexts, toBase64, type OcrBatch } from './ocr.ts';
import { batches, cleanHints, costUsd, markTerms, paragraphsOf, readyNotice } from './lib.ts';
import { SCHEMA, SYSTEM, contentLanguage, userMessage, type AiBatch } from './ai.ts';

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void };

const MODEL = 'claude-sonnet-5-5';
const BATCH_PAGES = 8;
/** Text recognition reads images, so fewer pages per run (each run has its own time limit). */
const OCR_BATCH_PAGES = 4;
const MAX_PAGES = 100;
/** AI spending per student per month (US dollars); above it new lessons are not prepared. */
const MONTHLY_BUDGET_USD = 3;

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
  const secret = secretKey();
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secret, { auth: { persistSession: false } });
  const body = await req.json().catch(() => ({}));
  const id = body.material_id;
  if (typeof id !== 'string') return json({ error: 'material_id' }, 400);

  // The next batch, started by this function itself.
  if (req.headers.get('x-internal-key') === secret) {
    EdgeRuntime.waitUntil(runBatch(db, id, Number(body.batch) || 0, body.ocr === true));
    return json({ ok: true });
  }

  // A student: only their own lesson, only once.
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const { data: m } = await db.from('materials').select('user_id, status, kind, counted_in_trial').eq('id', id).maybeSingle();
  if (!m || m.user_id !== who.user.id) return json({ error: 'not found' }, 404);
  if (m.kind === 'audio') return json({ error: 'audio comes later' }, 400);
  // Photos always need text recognition; a scanned PDF only when the student asks for it.
  const ocr = m.kind === 'photo' || body.ocr === true;
  const again = m.status === 'needs_ocr' && ocr;
  if (m.status !== 'uploaded' && m.status !== 'failed' && !again) return json({ status: m.status });
  // A scanned PDF gave its trial lesson back; reading it with text recognition uses one again.
  if (again && !m.counted_in_trial && !(await chargeTrial(db, id, m.user_id))) return json({ error: 'trial' }, 403);
  await db.from('materials').update({ status: 'processing', error: null }).eq('id', id);
  EdgeRuntime.waitUntil(runBatch(db, id, 0, ocr));
  return json({ status: 'processing' }, 202);
});

type FileRow = { storage_path: string; mime_type: string | null };

async function download(db: SupabaseClient, path: string) {
  const { data: blob, error } = await db.storage.from('materials').download(path);
  if (error || !blob) throw new Error('download failed');
  return new Uint8Array(await blob.arrayBuffer());
}

/**
 * The lesson's pages: a PDF with text gives every page's text now; a scanned PDF and photos give only the page
 * count (their text comes from text recognition, batch by batch).
 */
async function readLesson(db: SupabaseClient, materialId: string, kind: string, ocr: boolean) {
  const { data: files } = await db.from('material_files').select('storage_path, mime_type').eq('material_id', materialId).order('sort_order');
  if (!files?.length) throw new Error('file row missing');
  if (kind === 'photo') return { totalPages: files.length, text: [] as string[], files: files as FileRow[], pdf: null };
  const bytes = await download(db, files[0].storage_path);
  const doc = await getDocumentProxy(bytes.slice());
  if (ocr) return { totalPages: doc.numPages, text: [] as string[], files: files as FileRow[], pdf: bytes };
  const { totalPages, text } = await extractText(doc, { mergePages: false });
  return { totalPages, text: text as string[], files: files as FileRow[], pdf: null };
}

/** Text recognition of pages from…to: photos as images, a scanned PDF as a small PDF of just those pages. */
async function recognise(db: SupabaseClient, files: FileRow[], pdf: Uint8Array | null, from: number, to: number) {
  const blocks: unknown[] = [];
  if (pdf) {
    const src = await PDFDocument.load(pdf, { ignoreEncryption: true });
    const part = await PDFDocument.create();
    const pages = await part.copyPages(src, Array.from({ length: to - from + 1 }, (_, i) => from - 1 + i));
    pages.forEach((p) => part.addPage(p));
    blocks.push({ type: 'text', text: `The PDF below holds pages ${from} to ${to}, in order.` });
    blocks.push({ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: toBase64(await part.save()) } });
  } else {
    for (let p = from; p <= to; p++) {
      const f = files[p - 1];
      blocks.push({ type: 'text', text: `[Page ${p}]` });
      blocks.push({ type: 'image', source: { type: 'base64', media_type: f.mime_type ?? 'image/jpeg', data: toBase64(await download(db, f.storage_path)) } });
    }
  }
  blocks.push({ type: 'text', text: `Copy the text of pages ${from}-${to}.` });
  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  const params = {
    model: MODEL,
    max_tokens: 16000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'low', format: { type: 'json_schema', schema: OCR_SCHEMA } },
    system: OCR_SYSTEM,
    messages: [{ role: 'user', content: blocks }],
  };
  // deno-lint-ignore no-explicit-any
  const res = await client.beta.messages.create(params as any);
  if (res.stop_reason === 'refusal') throw new Error('the AI declined this part');
  if (res.stop_reason === 'max_tokens') throw new Error('the page text was cut off');
  const text = res.content.find((b) => b.type === 'text');
  if (!text || text.type !== 'text') throw new Error('no text from the AI');
  return { texts: pageTexts(JSON.parse(text.text) as OcrBatch, from, to), usage: { input: res.usage.input_tokens, output: res.usage.output_tokens } };
}

/** Uses a trial lesson (or Premium) for a lesson that had given its lesson back; false = no lesson left. */
async function chargeTrial(db: SupabaseClient, materialId: string, userId: string) {
  const { data: premium } = await db.rpc('is_premium', { uid: userId });
  if (premium) return true;
  const { data: ok } = await db.rpc('can_use', { feature: 'upload', uid: userId });
  if (!ok) return false;
  const { data: t } = await db.from('trial_usage').select('lessons').eq('user_id', userId).maybeSingle();
  await db.from('trial_usage').upsert({ user_id: userId, lessons: (t?.lessons ?? 0) + 1 });
  await db.from('materials').update({ counted_in_trial: true }).eq('id', materialId);
  return true;
}

/** A retry after a failure starts clean: removes what an earlier, unfinished run wrote. */
async function clearOutput(db: SupabaseClient, materialId: string) {
  await Promise.all([
    db.from('material_content').delete().eq('material_id', materialId),
    db.from('material_terms').delete().eq('material_id', materialId),
    db.from('material_chunks').delete().eq('material_id', materialId),
    db.from('card_decks').delete().eq('material_id', materialId),
    db.from('quizzes').delete().eq('material_id', materialId),
  ]);
  await db.from('material_topics').delete().eq('material_id', materialId);
}

/** The lesson does not use up a trial lesson (scanned PDF, too long): give it back. */
async function refundTrial(db: SupabaseClient, materialId: string, userId: string) {
  const { data } = await db.from('materials').select('counted_in_trial').eq('id', materialId).single();
  if (!data?.counted_in_trial) return;
  await db.from('materials').update({ counted_in_trial: false }).eq('id', materialId);
  const { data: t } = await db.from('trial_usage').select('lessons').eq('user_id', userId).maybeSingle();
  if (t && t.lessons > 0) await db.from('trial_usage').update({ lessons: t.lessons - 1 }).eq('user_id', userId);
}

async function runBatch(db: SupabaseClient, materialId: string, batchNo: number, ocr: boolean) {
  const { data: m } = await db.from('materials').select('user_id, course_id, title, kind').eq('id', materialId).single();
  if (!m) return;
  const uid = m.user_id as string;
  try {
    const { totalPages, text, files, pdf } = await readLesson(db, materialId, m.kind, ocr);

    if (batchNo === 0) {
      await clearOutput(db, materialId);
      const chars = text.reduce((a, t) => a + t.replace(/\s/g, '').length, 0);
      if (!ocr && chars < 20 * Math.min(totalPages, 5)) {
        await refundTrial(db, materialId, uid);
        await db.from('materials').update({ status: 'needs_ocr', page_count: totalPages }).eq('id', materialId);
        return;
      }
      if (totalPages > MAX_PAGES) {
        await refundTrial(db, materialId, uid);
        await db.from('materials').update({ status: 'too_long', page_count: totalPages }).eq('id', materialId);
        return;
      }
      const month = new Date().toISOString().slice(0, 7) + '-01';
      const { data: use } = await db.from('usage_monthly').select('cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
      if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) throw new Error('monthly AI budget reached');
      await db.from('materials').update({ page_count: totalPages }).eq('id', materialId);
    }

    const all = batches(totalPages, ocr ? OCR_BATCH_PAGES : BATCH_PAGES);
    const [from, to] = all[batchNo];
    if (ocr) {
      const seen = await recognise(db, files, pdf, from, to);
      await saveUsage(db, uid, seen.usage.input, seen.usage.output);
      seen.texts.forEach((t, i) => (text[from - 1 + i] = t));
    }
    const pages = [];
    for (let p = from; p <= to; p++) pages.push({ page: p, paragraphs: paragraphsOf(text[p - 1] ?? '') });

    // Settings for the content language and the course name.
    const [{ data: course }, { data: settings }, { data: profile }] = await Promise.all([
      m.course_id ? db.from('courses').select('name, content_lang_override').eq('id', m.course_id).maybeSingle() : Promise.resolve({ data: null }),
      db.from('user_settings').select('content_lang').eq('user_id', uid).single(),
      db.from('profiles').select('app_lang').eq('id', uid).single(),
    ]);
    const choice = (course?.content_lang_override ?? settings?.content_lang ?? 'pdf') as string;
    const langText = contentLanguage(course?.content_lang_override ?? null, settings?.content_lang ?? 'pdf', profile?.app_lang ?? 'tr');

    const ai = await askClaude(m.title, course?.name ?? '', langText, pages);
    await saveUsage(db, uid, ai.usage.input, ai.usage.output);
    const out = ai.data;
    const docLang = out.language === 'other' ? 'en' : out.language;
    const contentLang = choice === 'pdf' ? docLang : choice === 'app' ? (profile?.app_lang ?? 'tr') : choice;

    // Reading page so far.
    const { data: existing } = await db.from('material_content').select('reader_doc, stats').eq('material_id', materialId).maybeSingle();
    type Doc = { language: string; sections: { title: string; blocks: unknown[] }[] };
    const doc: Doc = (existing?.reader_doc as Doc) ?? { language: docLang, sections: [] };
    const stats = (existing?.stats as Record<string, number>) ?? {};

    // Hard words: saved with explanations, then marked in the text (first place only).
    const termOffset = stats.terms ?? 0;
    const terms = out.terms.filter((t) => t.surface.trim()).map((t, i) => ({ ...t, key: `t${termOffset + i + 1}` }));
    if (terms.length) {
      await db.from('material_terms').insert(
        terms.map((t) => ({ material_id: materialId, user_id: uid, term_key: t.key, surface: t.surface.trim(), page: t.page, explanation: t.explanations })),
      );
    }
    const used = new Set<string>();
    for (const pg of pages) {
      const info = out.pages.find((x) => x.page === pg.page);
      let paragraphs = pg.paragraphs;
      const heading = info?.heading && paragraphs.includes(info.heading) ? info.heading : undefined;
      if (heading) paragraphs = paragraphs.filter((x) => x !== heading);
      if (!paragraphs.length && !heading) continue;
      const pageTerms = terms.filter((t) => t.page === pg.page).concat(terms.filter((t) => t.page !== pg.page));
      const block = {
        pageFrom: pg.page,
        pageTo: pg.page,
        tag: info?.tag ?? 'general',
        ...(heading ? { heading } : {}),
        paragraphs: paragraphs.map((x) => markTerms(x, pageTerms, used)),
      };
      if (info?.section_title || !doc.sections.length) doc.sections.push({ title: info?.section_title || m.title, blocks: [] });
      doc.sections[doc.sections.length - 1].blocks.push(block);
    }

    // Topics (with ids, so questions and search pieces can point to them).
    const { data: topics } = out.topics.length
      ? await db
          .from('material_topics')
          .insert(
            out.topics.map((t, i) => ({
              material_id: materialId,
              user_id: uid,
              title: t.title,
              page_from: t.page_from,
              page_to: t.page_to,
              importance: Math.max(0, Math.min(3, t.importance)),
              sort_order: (stats.topics ?? 0) + i,
            })),
          )
          .select('id, page_from, page_to')
      : { data: [] };
    const topicFor = (page: number) => topics?.find((t) => page >= (t.page_from ?? 0) && page <= (t.page_to ?? 0))?.id ?? null;

    // Pieces of text for the assistant's search.
    const chunks = pages.filter((p) => p.paragraphs.length).map((p) => ({ material_id: materialId, user_id: uid, page: p.page, topic_id: topicFor(p.page), text: p.paragraphs.join('\n') }));
    if (chunks.length) await db.from('material_chunks').insert(chunks);

    // Flash cards in the lesson's deck.
    if (out.cards.length) {
      let { data: deck } = await db.from('card_decks').select('id').eq('material_id', materialId).maybeSingle();
      if (!deck) ({ data: deck } = await db.from('card_decks').insert({ user_id: uid, course_id: m.course_id, material_id: materialId, lang: contentLang, title: m.title }).select('id').single());
      await db.from('flashcards').insert(
        out.cards.map((c, i) => ({ deck_id: deck!.id, user_id: uid, question: c.question, answer: c.answer, note: c.note || null, page: c.page, sort_order: (stats.cards ?? 0) + i })),
      );
    }

    // Exam questions of the lesson.
    if (out.questions.length) {
      let { data: quiz } = await db.from('quizzes').select('id').eq('material_id', materialId).eq('kind', 'lesson_end').maybeSingle();
      if (!quiz) ({ data: quiz } = await db.from('quizzes').insert({ user_id: uid, course_id: m.course_id, material_id: materialId, kind: 'lesson_end', lang: contentLang, teacher_style: false }).select('id').single());
      await db.from('quiz_questions').insert(
        out.questions
          .filter((q) => q.options.length >= 2 && q.answer_index >= 0 && q.answer_index < q.options.length)
          .map((q, i) => ({
            quiz_id: quiz!.id,
            user_id: uid,
            topic_id: topicFor(q.page),
            sort_order: (stats.questions ?? 0) + i,
            kind: 'multiple_choice',
            style_tag: q.style,
            text: q.text,
            options: q.options,
            answer_index: q.answer_index,
            explanation: q.explanation,
            source_page: q.page,
            hints: cleanHints(q.hints, q.options, q.answer_index).slice(0, 3),
          })),
      );
    }

    const newStats = {
      pages: totalPages,
      terms: termOffset + terms.length,
      topics: (stats.topics ?? 0) + (topics?.length ?? 0),
      cards: (stats.cards ?? 0) + out.cards.length,
      questions: (stats.questions ?? 0) + out.questions.length,
      done_pages: to,
    };
    await db.from('material_content').upsert({ material_id: materialId, user_id: uid, reader_doc: doc, stats: newStats });
    await db.from('materials').update({ language: docLang }).eq('id', materialId);

    if (batchNo + 1 < all.length) {
      // Next 8 pages in a fresh run of this function (each run has its own time limit).
      const next = fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/process-material`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-internal-key': secretKey() },
        body: JSON.stringify({ material_id: materialId, batch: batchNo + 1, ocr }),
      });
      await next;
      return;
    }
    await finish(db, materialId, uid, m.title);
  } catch (e) {
    console.error('process-material', materialId, batchNo, e);
    await db.from('materials').update({ status: 'failed', error: String((e as Error).message ?? e).slice(0, 300) }).eq('id', materialId);
  }
}

/** Last batch: "ready" and a notification. (The check after a section uses the lesson's questions of its pages.) */
async function finish(db: SupabaseClient, materialId: string, uid: string, title: string) {
  await db.from('materials').update({ status: 'ready', processed_at: new Date().toISOString() }).eq('id', materialId);
  const { data: c } = await db.from('material_content').select('stats').eq('material_id', materialId).single();
  const st = (c?.stats ?? {}) as Record<string, number>;
  // In the student's app language (profiles.app_lang, saved by the apps).
  const { data: prof } = await db.from('profiles').select('app_lang').eq('id', uid).single();
  const note = readyNotice(prof?.app_lang ?? 'tr', title, st);
  await db.from('notifications').insert({
    user_id: uid,
    kind: 'lesson_ready',
    title: note.title,
    body: note.body,
    data: { to: '/courses' },
    sent_at: new Date().toISOString(),
  });
}

/** One AI call for a batch of pages; the answer must match SCHEMA. */
async function askClaude(title: string, course: string, contentLang: string, pages: { page: number; paragraphs: string[] }[]) {
  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  const params = {
    model: MODEL,
    max_tokens: 16000,
    // If a safety filter wrongly declines (e.g. toxicology), Anthropic retries on its recommended fallback model.
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'medium', format: { type: 'json_schema', schema: SCHEMA } },
    system: SYSTEM,
    messages: [{ role: 'user', content: userMessage(title, course, contentLang, pages) }],
  };
  // deno-lint-ignore no-explicit-any
  const res = await client.beta.messages.create(params as any);
  if (res.stop_reason === 'refusal') throw new Error('the AI declined this part');
  if (res.stop_reason === 'max_tokens') throw new Error('the AI answer was cut off');
  const text = res.content.find((b) => b.type === 'text');
  if (!text || text.type !== 'text') throw new Error('no answer from the AI');
  return { data: JSON.parse(text.text) as AiBatch, usage: { input: res.usage.input_tokens, output: res.usage.output_tokens } };
}

/** Adds tokens and cost to this month's usage (cost limits read it). */
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
