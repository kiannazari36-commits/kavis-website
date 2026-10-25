// Edge Function assistant: answers a student's question only from their own lessons (CLAUDE.md).
// POST { question, course_id?, material_id?, mode: 'pdf' | 'ai', thread_id?, lang, page_from?, page_to?,
//        image?: { media_type, data } }  (image = "Soruyu çözdür": a photo of a question, solved step by step)
//   → a stream of server-sent events: { t: "text…" } while the answer is written, then
//     { done: true, thread_id, answer, sources: [{ material_id, lesson, page }], links: [{ url, title }], outside_pdf }, or { error }.
// One chosen lesson (material_id): Claude gets the whole lesson (cached for 5 minutes, so follow-up questions are
// cheap) and is told which pages are open. Otherwise, or for a very long lesson, it gets the best text pieces (the
// open pages first, then material_chunks full-text search). Claude Sonnet 5.5 answers; the function saves the
// thread and both messages, counts a trial question and the AI cost.
// "AI + research" (mode 'ai') may add general knowledge and search the web (at most 3 searches, ~$0.01 each), marked
// outside_pdf; the web pages it used come back as links. Apps never write answers themselves.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { costUsd, lessonText, queryTerms, rankChunks, splitTail, tsQuery } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
const PIECES = 6;
// About 35,000 tokens: the first question on a lesson costs at most ~$0.09, follow-ups read it from the cache.
const LESSON_MAX_CHARS = 120_000;
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const WEB_SEARCHES = 3;

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

const system = (mode: string, lang: string, whole: boolean, solve: boolean) => `You are Kavis, a study assistant for a university student. You answer from the student's own lecture material.
${
  whole
    ? 'You get the whole text of ONE lesson the student chose, page by page ([Page n]), and maybe earlier messages of this chat. Talk only about this lesson: if the question is about another subject, say kindly in one sentence that here you only help with this lesson.'
    : 'You get numbered excerpts [E1], [E2]… from the student\'s lessons (lesson name and page given), and maybe earlier messages of this chat.'
}
${
  mode === 'ai'
    ? 'Base your answer on the lesson text you got. When it is not enough, or the student asks for more or newer information, search the web (reliable medical and academic sources first) and add what you found; say briefly which part is not from their PDFs.'
    : 'Answer ONLY from the lesson text you got. If it does not contain the answer, say clearly (in one or two sentences) that you could not find it in their lessons and suggest what to look for; do not use outside knowledge.'
}
If the student is reading a lesson now, you are told which pages are open; "this page", "this topic", "explain this" mean those pages. They may still ask about any other page of the lesson.
${
  solve
    ? 'The student sends a photo of an exam question. Solve it step by step (numbered steps, short), say which option is right and why the others are not, and point to where it is in their lessons.'
    : 'Be short and clear: 2-6 sentences or a few bullet points. Explain simply, like a good classmate.'
}
Write in the language of the student's question (if unclear: ${LANG_NAMES[lang] ?? 'Turkish'}), plain text without markdown (no headings, no ** bold); never mention which language you use.
End with one last line exactly like: SOURCES: [2, 5] OUTSIDE: no
— ${whole ? 'the page numbers you used' : 'the excerpt numbers you used'} (empty [] if none), and OUTSIDE: yes only if you added general knowledge.`;

type Piece = { id: number; material_id: string; page: number | null; text: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const image = body.image && IMAGE_TYPES.includes(body.image.media_type) && typeof body.image.data === 'string' && body.image.data.length < 7_000_000 ? body.image : null;
  let question = typeof body.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  if (!question && !image) return json({ error: 'question' }, 400);
  const mode = body.mode === 'ai' ? 'ai' : 'pdf';
  const lang = typeof body.lang === 'string' ? body.lang : 'tr';
  const courseId: string | null = typeof body.course_id === 'string' ? body.course_id : null;
  const materialId: string | null = typeof body.material_id === 'string' ? body.material_id : null;
  const pageFrom = Number.isInteger(body.page_from) ? (body.page_from as number) : null;
  const pageTo = Number.isInteger(body.page_to) ? (body.page_to as number) : pageFrom;

  // Trial / Premium, and the monthly AI budget.
  const { data: allowed } = await db.rpc('can_use', { feature: 'ask', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('cost_usd').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
  const usage = { input: 0, output: 0, cacheWrite: 0, cacheRead: 0, searches: 0 };

  // A photo of a question: first its text (to find the right lesson pages), then the solution below.
  if (image) {
    try {
      const read = await client.messages.create({
        model: MODEL,
        max_tokens: 1500,
        messages: [{ role: 'user', content: [{ type: 'image', source: { type: 'base64', media_type: image.media_type, data: image.data } }, { type: 'text', text: 'Copy the exam question in this photo exactly (with its options). Reply with the text only.' }] }],
      });
      usage.input += read.usage.input_tokens;
      usage.output += read.usage.output_tokens;
      const text = read.content.filter((b) => b.type === 'text').map((b) => (b as { text: string }).text).join('').trim();
      question = [question, text].filter(Boolean).join('\n').slice(0, 2000);
    } catch (e) {
      console.error('assistant photo', e);
      return json({ error: 'ai' }, 502);
    }
  }

  // Which lessons to search: one lesson, one course, or all of the student's lessons.
  let lessons = db.from('materials').select('id, title').eq('user_id', uid).eq('status', 'ready');
  if (materialId) lessons = lessons.eq('id', materialId);
  else if (courseId) lessons = lessons.eq('course_id', courseId);
  const { data: mats } = await lessons;
  const titles = new Map((mats ?? []).map((m) => [m.id as string, m.title as string]));
  const ids = [...titles.keys()];

  let pieces: Piece[] = [];
  const open: Piece[] = [];
  // One chosen lesson: the whole text if it is not too long.
  let whole: string | null = null;
  let lessonPages: number[] = [];
  if (materialId && ids.includes(materialId)) {
    const { data } = await db.from('material_chunks').select('id, material_id, page, text').eq('material_id', materialId).order('page').limit(500);
    whole = lessonText(data ?? [], LESSON_MAX_CHARS);
    lessonPages = (data ?? []).map((c) => c.page).filter((p): p is number => p !== null);
    // Too long: the pages open in the reader always come first.
    if (!whole && pageFrom !== null) {
      const last = Math.min(pageTo ?? pageFrom, pageFrom + 3);
      open.push(...(data ?? []).filter((c) => c.page !== null && c.page >= pageFrom && c.page <= last).slice(0, 4));
    }
  }
  const terms = queryTerms(question);
  if (!whole && ids.length && terms.length) {
    const { data } = await db
      .from('material_chunks')
      .select('id, material_id, page, text')
      .in('material_id', ids)
      .textSearch('search', tsQuery(terms), { config: 'simple' })
      .limit(40);
    pieces = rankChunks(data ?? [], terms, PIECES);
  }
  pieces = [...open, ...pieces.filter((p) => !open.some((o) => o.id === p.id))].slice(0, PIECES + open.length);

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
  const lessonTitle = materialId ? (titles.get(materialId) ?? '') : '';
  const reading = materialId && pageFrom !== null ? `I am reading "${lessonTitle}", page ${pageFrom}${pageTo && pageTo !== pageFrom ? `-${pageTo}` : ''}.\n\n` : '';
  const userText = `${reading}${whole ? '' : `Excerpts from my lessons:\n\n${excerpts}\n\n`}${image ? 'Solve the question in this photo. Its text: ' : 'My question: '}${question}`;

  const params = {
    model: MODEL,
    max_tokens: 4000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'low' },
    ...(mode === 'ai' ? { tools: [{ type: 'web_search_20260209', name: 'web_search', max_uses: WEB_SEARCHES }] } : {}),
    system: [
      { type: 'text', text: system(mode, lang, !!whole, !!image) },
      // The lesson text is the same for every question on this lesson, so it is cached.
      ...(whole ? [{ type: 'text', text: `The lesson "${lessonTitle}", whole text:\n\n${whole}`, cache_control: { type: 'ephemeral' } }] : []),
    ],
    messages: [
      ...history,
      {
        role: 'user',
        content: image ? [{ type: 'image', source: { type: 'base64', media_type: image.media_type, data: image.data } }, { type: 'text', text: userText }] : userText,
      },
    ],
  };

  // The answer is sent while it is written (server-sent events); saving happens at the end.
  const enc = new TextEncoder();
  const stream = new ReadableStream({
    async start(ctrl) {
      const send = (x: unknown) => ctrl.enqueue(enc.encode(`data: ${JSON.stringify(x)}\n\n`));
      try {
        // deno-lint-ignore no-explicit-any
        const s = client.beta.messages.stream(params as any);
        s.on('text', (t: string) => send({ t }));
        const res = await s.finalMessage();
        if (res.stop_reason === 'refusal') {
          send({ error: 'declined' });
          return ctrl.close();
        }
        usage.input += res.usage.input_tokens;
        usage.output += res.usage.output_tokens;
        usage.cacheWrite += res.usage.cache_creation_input_tokens ?? 0;
        usage.cacheRead += res.usage.cache_read_input_tokens ?? 0;
        // Web searches cost $10 per 1,000.
        usage.searches += res.usage.server_tool_use?.web_search_requests ?? 0;
        type Page = { url?: string; title?: string };
        type Block = { type: string; text?: string; citations?: Page[] | null; content?: Page[] | { error_code: string } };
        const blocks = res.content as Block[];
        const full = blocks.filter((b) => b.type === 'text').map((b) => b.text ?? '').join('');
        // The web pages the answer cites (mode 'ai'), each once; without citations, the first pages the search found.
        const cited = blocks.flatMap((b) => b.citations ?? []);
        const found = blocks.filter((b) => b.type === 'web_search_tool_result' && Array.isArray(b.content)).flatMap((b) => b.content as Page[]);
        const links = [
          ...new Map((cited.some((c) => c.url) ? cited : found.slice(0, 3)).filter((c) => c.url).map((c) => [c.url!, { url: c.url!, title: c.title || c.url! }])).values(),
        ].slice(0, 5);
        const out = splitTail(full);
        const used: { material_id: string; page: number | null }[] = whole
          ? out.sources.filter((n) => lessonPages.includes(n)).sort((a, b) => a - b).map((page) => ({ material_id: materialId!, page }))
          : out.sources.map((n) => pieces[n - 1]).filter(Boolean).map((p) => ({ material_id: p.material_id, page: p.page }));
        const outside = mode === 'ai' && (out.outside || links.length > 0);
        const saved = await save(db, uid, threadId, courseId, materialId, question, out.answer, mode, [...used, ...links], outside);
        await count(db, uid, month, usage);
        send({ done: true, thread_id: saved, answer: out.answer, sources: used.map((p) => ({ ...p, lesson: titles.get(p.material_id) ?? '' })), links, outside_pdf: outside });
      } catch (e) {
        console.error('assistant', e);
        send({ error: 'ai' });
      }
      ctrl.close();
    },
  });
  return new Response(stream, { headers: { ...cors, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' } });
});

/** The thread (new or continued) and both messages; returns the thread id. */
async function save(
  db: SupabaseClient,
  uid: string,
  threadId: string | null,
  courseId: string | null,
  materialId: string | null,
  question: string,
  answer: string,
  mode: string,
  sources: ({ material_id: string; page: number | null } | { url: string; title: string })[],
  outside: boolean,
) {
  if (!threadId) {
    const { data: th } = await db
      .from('assistant_threads')
      .insert({ user_id: uid, course_id: courseId, material_id: materialId, mode: 'chat', title: question.slice(0, 80) })
      .select('id')
      .single();
    threadId = th!.id as string;
  } else {
    await db.from('assistant_threads').update({ updated_at: new Date().toISOString() }).eq('id', threadId);
  }
  // Both rows name every column: missing ones would be sent as null, not the column default.
  const { error } = await db.from('assistant_messages').insert([
    { thread_id: threadId, user_id: uid, role: 'user', content: question, source_mode: mode, sources: [], outside_pdf: false },
    { thread_id: threadId, user_id: uid, role: 'assistant', content: answer, source_mode: mode, sources, outside_pdf: outside },
  ]);
  if (error) console.error('assistant_messages', error);
  return threadId;
}

/** A trial question (not for Premium) and the month's AI cost. */
async function count(db: SupabaseClient, uid: string, month: string, u: { input: number; output: number; cacheWrite: number; cacheRead: number; searches: number }) {
  const { data: premium } = await db.rpc('is_premium', { uid });
  if (!premium) {
    const { data: t } = await db.from('trial_usage').select('assistant_questions').eq('user_id', uid).maybeSingle();
    await db.from('trial_usage').upsert({ user_id: uid, assistant_questions: (t?.assistant_questions ?? 0) + 1 });
  }
  const { data: m } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, assistant_questions').eq('user_id', uid).eq('month', month).maybeSingle();
  await db.from('usage_monthly').upsert({
    user_id: uid,
    month,
    input_tokens: Number(m?.input_tokens ?? 0) + u.input + u.cacheWrite + u.cacheRead,
    output_tokens: Number(m?.output_tokens ?? 0) + u.output,
    cost_usd: Number(m?.cost_usd ?? 0) + costUsd(u.input, u.output, u.cacheWrite, u.cacheRead) + u.searches * 0.01,
    assistant_questions: Number(m?.assistant_questions ?? 0) + 1,
  });
}
