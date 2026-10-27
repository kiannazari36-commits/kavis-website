// Edge Function assistant: answers a student's question only from their own lessons (CLAUDE.md).
// POST { question, course_id?, material_id?, mode: 'pdf' | 'ai', thread_id?, lang, page_from?, page_to?,
//        image?: { media_type, data } }  (image = "Soruyu çözdür": a photo of a question, solved step by step)
//   → a stream of server-sent events: { t: "text…" } while the answer is written, then
//     { done: true, thread_id, answer, sources: [{ material_id, lesson, page }], links: [{ url, title }], acts, outside_pdf }, or { error }.
// One chosen lesson (material_id): Claude gets the whole lesson (cached for 5 minutes, so follow-up questions are
// cheap) and is told which pages are open. Otherwise, or for a very long lesson, it gets the best text pieces (the
// open pages first, then material_chunks full-text search). Claude Sonnet 5.5 answers; the function saves the
// thread and both messages, counts a trial question and the AI cost.
// "AI + research" (mode 'ai') may add general knowledge and search the web (at most 3 searches, ~$0.01 each), marked
// outside_pdf; the web pages it used come back as links. Apps never write answers themselves.
// When the student asks, the assistant can also act: mark a topic as weak (it then comes into the study plan and
// the weak-topic lists) or make a flash card in the lesson's deck. Each action is sent as { act: { kind, title } }.
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
const MAX_TURNS = 3;

// What the assistant can do for the student (run here, with the student's id; never other students' data).
const TOOLS = [
  {
    name: 'mark_weak_topic',
    description:
      "Adds a topic of the student's lesson to their weak topics, so it comes into their study plan, review lists, quizzes and summaries. Use it when the student asks for that or says they are weak at / do not understand a topic (e.g. 'zayıf konularıma ekle', 'bu konuda zayıfım', 'bunu anlamadım', 'bunu çalışmam gerekenlere ekle', 'plana ekle'). Do not add a topic that is already in their weak topics list.",
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Short topic title (2-5 words) in the lesson language, e.g. "K vitamini".' },
        page: { type: 'integer', description: 'A page of the lesson where the topic is.' },
        excerpt: { type: 'integer', description: 'The excerpt number [E n] the topic is from, or 0 if you got the whole lesson.' },
      },
      required: ['title', 'page', 'excerpt'],
      additionalProperties: false,
    },
  },
  {
    name: 'add_flashcard',
    description: "Makes a flash card in the lesson's deck. Use it only when the student asks for a card ('karta ekle', 'kart yap').",
    strict: true,
    input_schema: {
      type: 'object',
      properties: {
        question: { type: 'string', description: 'Short question, from the lesson text.' },
        answer: { type: 'string', description: 'Short answer.' },
        note: { type: 'string', description: 'One sentence that helps remember, or "".' },
        page: { type: 'integer', description: 'The lesson page.' },
        excerpt: { type: 'integer', description: 'The excerpt number [E n], or 0 if you got the whole lesson.' },
      },
      required: ['question', 'answer', 'note', 'page', 'excerpt'],
      additionalProperties: false,
    },
  },
];
type Act = { kind: 'weak' | 'card'; title: string };

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
You may get the list of the student's weak topics (the ones they told you about and the ones they answered wrong in quizzes). When they ask about "my weak topics" / "zayıf olduğum konular", use exactly that list (with its pages) and do not ask which topics they mean; if the list is empty, say they have no weak topics saved yet.
You can act for the student with tools: mark_weak_topic and add_flashcard. Use them only when the student asks for it; after an action, confirm it in one short sentence. You cannot do anything else (no reminders, no notes); say so kindly if asked.
Write in the language of the student's question (if unclear: ${LANG_NAMES[lang] ?? 'Turkish'}), plain text without markdown (no headings, no ** bold) — except when the student asks for a table, chart, list to compare or memorise ("cetvel", "tablo", "çizelge", "table"): then write a simple markdown table (a header row, a |---| line, one row per line, short cells) and at most one short sentence before it; never mention which language you use.
Never write excerpt or page labels like [E1] or [Page 3] inside the answer text; the student does not see them. Only the last SOURCES line carries numbers.
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

  const weakText = await weakTopics(db, uid, ids, titles);

  const excerpts = pieces.length
    ? pieces.map((p, i) => `[E${i + 1}] (${titles.get(p.material_id) ?? ''}, page ${p.page ?? '?'})\n${p.text.slice(0, 2500)}`).join('\n\n')
    : '(no matching excerpts were found in the student\'s lessons)';
  const lessonTitle = materialId ? (titles.get(materialId) ?? '') : '';
  const reading = materialId && pageFrom !== null ? `I am reading "${lessonTitle}", page ${pageFrom}${pageTo && pageTo !== pageFrom ? `-${pageTo}` : ''}.\n\n` : '';
  const userText = `${reading}${weakText}${whole ? '' : `Excerpts from my lessons:\n\n${excerpts}\n\n`}${image ? 'Solve the question in this photo. Its text: ' : 'My question: '}${question}`;

  const params = {
    model: MODEL,
    max_tokens: 4000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'low' },
    tools: [...TOOLS, ...(mode === 'ai' ? [{ type: 'web_search_20260209', name: 'web_search', max_uses: WEB_SEARCHES }] : [])],
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
        type Page = { url?: string; title?: string };
        type Block = { type: string; id?: string; name?: string; input?: Record<string, unknown>; text?: string; citations?: Page[] | null; content?: Page[] | { error_code: string } };
        const blocks: Block[] = [];
        const acts: Act[] = [];
        // The whole text as the student saw it (all rounds).
        let full = '';
        const write = (t: string) => {
          full += t;
          send({ t });
        };
        // The answer, with at most MAX_TURNS rounds of actions (the tools run here, then Claude goes on).
        for (let turn = 0; turn < MAX_TURNS; turn++) {
          // deno-lint-ignore no-explicit-any
          const s = client.beta.messages.stream(params as any);
          s.on('text', write);
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
          blocks.push(...(res.content as Block[]));
          const calls = (res.content as Block[]).filter((b) => b.type === 'tool_use');
          if (res.stop_reason !== 'tool_use' || !calls.length) break;
          const results = [];
          for (const c of calls) {
            const r = await act(db, uid, c.name ?? '', c.input ?? {}, materialId ?? pieces[Number(c.input?.excerpt) - 1]?.material_id ?? ids[0] ?? null);
            if (r.act) {
              acts.push(r.act);
              send({ act: r.act });
            }
            results.push({ type: 'tool_result', tool_use_id: c.id, content: r.text, ...(r.act ? {} : { is_error: true }) });
          }
          params.messages = [...params.messages, { role: 'assistant', content: res.content }, { role: 'user', content: results }] as typeof params.messages;
          write('\n\n');
        }
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
        const saved = await save(db, uid, threadId, courseId, materialId, question, out.answer, mode, [...used, ...links, ...acts.map((a) => ({ act: a.kind, title: a.title }))], outside);
        await count(db, uid, month, usage);
        send({ done: true, thread_id: saved, answer: out.answer, sources: used.map((p) => ({ ...p, lesson: titles.get(p.material_id) ?? '' })), links, acts, outside_pdf: outside });
      } catch (e) {
        console.error('assistant', e);
        send({ error: 'ai' });
      }
      ctrl.close();
    },
  });
  return new Response(stream, { headers: { ...cors, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' } });
});

/**
 * The student's weak topics in the lessons of this question (from topic_progress: what they asked to add, and
 * topics they answered wrong in quizzes), with pages, mastery and the number of wrong answers. "" when none.
 */
async function weakTopics(db: SupabaseClient, uid: string, ids: string[], titles: Map<string, string>) {
  if (!ids.length) return '';
  type Row = { id: string; material_id: string; title: string; page_from: number | null; page_to: number | null; topic_progress: { state: string; mastery: number | null }[] };
  const { data } = await db
    .from('material_topics')
    .select('id, material_id, title, page_from, page_to, topic_progress!inner(state, mastery)')
    .in('material_id', ids)
    .eq('topic_progress.user_id', uid)
    .eq('topic_progress.state', 'weak')
    .limit(40);
  const rows = (data ?? []) as Row[];
  if (!rows.length) return "My weak topics: none saved yet.\n\n";
  const { data: wrong } = await db.from('quiz_answers').select('quiz_questions!inner(topic_id)').eq('user_id', uid).eq('correct', false).in('quiz_questions.topic_id', rows.map((r) => r.id));
  const misses = new Map<string, number>();
  for (const w of (wrong ?? []) as unknown as { quiz_questions: { topic_id: string } }[]) misses.set(w.quiz_questions.topic_id, (misses.get(w.quiz_questions.topic_id) ?? 0) + 1);
  const lines = rows
    .sort((a, b) => (a.topic_progress[0]?.mastery ?? 0) - (b.topic_progress[0]?.mastery ?? 0))
    .map((r) => {
      const pages = r.page_from ? ` p.${r.page_from}${r.page_to && r.page_to !== r.page_from ? `-${r.page_to}` : ''}` : '';
      const n = misses.get(r.id) ?? 0;
      return `- ${r.title} (${titles.get(r.material_id) ?? ''}${pages}): mastery ${r.topic_progress[0]?.mastery ?? 0}%${n ? `, ${n} wrong answer${n > 1 ? 's' : ''}` : ''}`;
    });
  return `My weak topics (saved; use them when I ask about my weak topics):\n${lines.join('\n')}\n\n`;
}

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
  sources: ({ material_id: string; page: number | null } | { url: string; title: string } | { act: string; title: string })[],
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

/**
 * Runs one action the assistant asked for, for this student only. Returns the text Claude gets back and, when it
 * worked, what the app shows.
 */
async function act(db: SupabaseClient, uid: string, name: string, input: Record<string, unknown>, materialId: string | null): Promise<{ text: string; act?: Act }> {
  if (!materialId) return { text: 'No lesson to add it to.' };
  const page = Number.isInteger(input.page) ? (input.page as number) : null;
  if (name === 'mark_weak_topic') {
    const title = String(input.title ?? '').trim().slice(0, 120);
    if (!title) return { text: 'The topic title is empty.' };
    // The lesson's topic with this title or on this page; a new topic if the lesson has none.
    const { data: topics } = await db.from('material_topics').select('id, title, page_from, page_to').eq('material_id', materialId).eq('user_id', uid);
    const lower = title.toLocaleLowerCase('tr');
    let topic =
      (topics ?? []).find((x) => x.title.toLocaleLowerCase('tr') === lower) ??
      (topics ?? []).find((x) => page !== null && x.page_from !== null && page >= x.page_from && page <= (x.page_to ?? x.page_from));
    if (!topic) {
      const { data: made } = await db
        .from('material_topics')
        .insert({ material_id: materialId, user_id: uid, title, page_from: page, page_to: page, importance: 2, sort_order: 999 })
        .select('id, title, page_from, page_to')
        .single();
      topic = made ?? undefined;
    }
    if (!topic) return { text: 'Could not save the topic.' };
    const { data: had } = await db.from('topic_progress').select('mastery').eq('user_id', uid).eq('topic_id', topic.id).maybeSingle();
    const { error } = await db.from('topic_progress').upsert(
      { user_id: uid, topic_id: topic.id, state: 'weak', mastery: Math.min(had?.mastery ?? 40, 40), next_review_at: new Date().toISOString().slice(0, 10) },
      { onConflict: 'user_id,topic_id' },
    );
    if (error) return { text: 'Could not save the topic.' };
    return { text: `Added "${topic.title}" to the student's weak topics; it will come into their study plan.`, act: { kind: 'weak', title: topic.title } };
  }
  if (name === 'add_flashcard') {
    const question = String(input.question ?? '').trim().slice(0, 300);
    const answer = String(input.answer ?? '').trim().slice(0, 500);
    if (!question || !answer) return { text: 'The card needs a question and an answer.' };
    const { data: mat } = await db.from('materials').select('course_id, title, language').eq('id', materialId).single();
    const { data: decks } = await db.from('card_decks').select('id').eq('user_id', uid).eq('material_id', materialId).order('created_at').limit(1);
    let deckId = decks?.[0]?.id as string | undefined;
    if (!deckId) {
      const lang = ['tr', 'en', 'fa', 'ar'].includes(mat?.language) ? mat!.language : 'tr';
      const { data: deck } = await db.from('card_decks').insert({ user_id: uid, course_id: mat?.course_id ?? null, material_id: materialId, lang, title: mat?.title ?? null }).select('id').single();
      deckId = deck?.id;
    }
    if (!deckId) return { text: 'Could not make the card.' };
    const { data: same } = await db.from('flashcards').select('id').eq('deck_id', deckId).eq('question', question).maybeSingle();
    if (same) return { text: 'This card is already in the deck.', act: { kind: 'card', title: question } };
    const { data: last } = await db.from('flashcards').select('sort_order').eq('deck_id', deckId).order('sort_order', { ascending: false }).limit(1);
    const note = String(input.note ?? '').trim().slice(0, 300) || null;
    const { error } = await db.from('flashcards').insert({ deck_id: deckId, user_id: uid, question, answer, note, page, sort_order: (last?.[0]?.sort_order ?? 0) + 1 });
    if (error) return { text: 'Could not make the card.' };
    return { text: 'The card was added to the lesson deck.', act: { kind: 'card', title: question } };
  }
  return { text: 'Unknown action.' };
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
