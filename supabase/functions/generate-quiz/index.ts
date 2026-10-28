// Edge Function generate-quiz: the exam pack of a course ("Sınava özel").
// POST { course_id, count?, styles?, types? } → { quiz_id, questions }. types = the question formats the student chose:
// multiple_choice, fill_blank (one blank "____"), written (open question); none = multiple_choice. styles = the question types the student chose
// ("Hangi tarzda soru istersin?"): case, side_effects, dose, knowledge, structure; none = a mix. From the course's
// lessons (most important pages first: what the lecturer said will be in the exam, weak topics, central topics),
// like the student's sample questions when they added some (teacher_styles, "Sınavlarda" on), the AI writes exam
// questions with hints and a short exam summary.
// Writes (service role): quizzes (kind exam_prep) + quiz_questions, summaries (kind exam_prep), usage_monthly.
import { createClient } from 'npm:@supabase/supabase-js@2';
import Anthropic from 'npm:@anthropic-ai/sdk';
import { cleanHints, costUsd, pickPages, type Page } from './lib.ts';

const MODEL = 'claude-sonnet-5-5';
const MONTHLY_BUDGET_USD = 3;
/** Lecture text sent to the AI (about 8,000 tokens). */
const MAX_CHARS = 26000;

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
const int = { type: 'integer' };
const str = { type: 'string' };
const SCHEMA = obj({
  questions: {
    type: 'array',
    items: obj({
      kind: { type: 'string', enum: ['multiple_choice', 'fill_blank', 'written'] },
      style: { type: 'string', enum: ['case', 'side_effects', 'dose', 'knowledge', 'structure'] },
      text: str,
      options: { type: 'array', items: str },
      answer_index: int,
      model_answer: str,
      explanation: str,
      lesson: int,
      page: int,
      hints: { type: 'array', items: str },
    }),
  },
  topics: {
    type: 'array',
    items: obj({ title: str, lesson: int, page_from: int, page_to: int, points: { type: 'array', items: str }, reason: { type: 'string', enum: ['teacher', 'weak', 'samples', 'base'] }, teacher: str }),
  },
});
type Out = {
  questions: { kind: 'multiple_choice' | 'fill_blank' | 'written'; style: string; text: string; options: string[]; answer_index: number; model_answer: string; explanation: string; lesson: number; page: number; hints: string[] }[];
  topics: { title: string; lesson: number; page_from: number; page_to: number; points: string[]; reason: 'teacher' | 'weak' | 'samples' | 'base'; teacher: string }[];
};

const SYSTEM = `You write an exam-prep pack for one university course in a study app: exam questions and a short exam summary, from the lecturer's own lesson text.
Question formats (kind): multiple_choice = 5 options, answer_index 0-based, model_answer ""; fill_blank = a sentence from the lesson with ONE key term replaced by "____" in text, options [], answer_index -1, model_answer = the missing term only (1-3 words); written = an open question answered in 1-3 sentences, options [], answer_index -1, model_answer = the key facts a right answer must contain. For fill_blank and written, explanation = a short pointer to where it is in the lesson. Use only the formats asked for. Rules for questions: only facts from the given pages; prefer what the lecturer said will be in the exam, the student's weak topics and central topics. For multiple choice exactly 5 options unless the lecturer's style says otherwise, answer_index 0-based, explanation = why the answer is right (1-2 sentences), lesson and page = where the answer is. 3 hints that help the student THINK: 1 = the key concept to recall, 2 = something that rules out some options (for fill_blank / written: a first letter or related concept), 3 = narrows it to about two options (for fill_blank / written: the nearest hint short of the answer); hints never mention pages and never contain the answer. If a lecturer style is given, follow its share of question types and its patterns.
topics: 4-6 topics to revise most for this exam, most important first: lesson, pages, 3-4 short points each, reason ("teacher" = the lecturer stressed it or said it will be in the exam, "weak" = the student's weak topic, "samples" = asked often in the lecturer's old questions (only when a lecturer style is given), "base" = central to the course), teacher = the lecturer's words about it if given, else "".
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
  const courseId = body.course_id;
  const count = Math.min(20, Math.max(5, Number(body.count) || 10));
  const TYPES = ['case', 'side_effects', 'dose', 'knowledge', 'structure'];
  const wanted = (Array.isArray(body.styles) ? body.styles : []).filter((x: unknown) => TYPES.includes(String(x))) as string[];
  const KINDS = ['multiple_choice', 'fill_blank', 'written'] as const;
  const kinds = (Array.isArray(body.types) ? body.types : []).filter((x: unknown) => (KINDS as readonly string[]).includes(String(x))) as (typeof KINDS)[number][];
  if (!kinds.length) kinds.push('multiple_choice');
  if (typeof courseId !== 'string') return json({ error: 'course_id' }, 400);
  const { data: course } = await db.from('courses').select('user_id, name, language, content_lang_override').eq('id', courseId).maybeSingle();
  if (!course || course.user_id !== uid) return json({ error: 'not found' }, 404);

  const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
  if (!allowed) return json({ error: 'locked' }, 403);
  const month = new Date().toISOString().slice(0, 7) + '-01';
  const { data: use } = await db.from('usage_monthly').select('input_tokens, output_tokens, cost_usd, generations, cache_read_tokens, cache_write_tokens').eq('user_id', uid).eq('month', month).maybeSingle();
  if (use && Number(use.cost_usd) >= MONTHLY_BUDGET_USD) return json({ error: 'budget' }, 429);

  const { data: lessons } = await db.from('materials').select('id, title, language').eq('course_id', courseId).eq('status', 'ready').in('kind', ['pdf', 'photo']).order('created_at');
  if (!lessons?.length) return json({ error: 'no lessons' }, 400);
  const ids = lessons.map((l) => l.id);
  const index = new Map(ids.map((id, i) => [id, i + 1]));

  const [{ data: chunks }, { data: topics }, { data: style }, { data: lectures }, { data: settings }, { data: profile }] = await Promise.all([
    db.from('material_chunks').select('material_id, page, text').in('material_id', ids),
    db.from('material_topics').select('id, material_id, title, page_from, page_to, importance, teacher_minutes, teacher_said_exam, topic_progress(state, mastery)').in('material_id', ids),
    db.from('teacher_styles').select('distribution, top_topics, use_in_quizzes').eq('course_id', courseId).maybeSingle(),
    db.from('materials').select('material_content(lecture)').eq('course_id', courseId).eq('kind', 'audio').eq('status', 'ready'),
    db.from('user_settings').select('content_lang').eq('user_id', uid).single(),
    db.from('profiles').select('app_lang').eq('id', uid).single(),
  ]);

  // Content language (CLAUDE.md): the course's choice, then the general setting; "pdf" = the lessons' language.
  const choice = course.content_lang_override ?? settings?.content_lang ?? 'pdf';
  const lang = choice === 'pdf' ? (lessons[0].language ?? course.language ?? 'tr') : choice === 'app' ? (profile?.app_lang ?? 'tr') : choice;

  // How much each page matters: said "in the exam" > weak topic > central topic.
  type T = { material_id: string; title: string; page_from: number | null; page_to: number | null; importance: number; teacher_minutes: number | null; teacher_said_exam: boolean; topic_progress: { state: string; mastery: number | null }[] | { state: string; mastery: number | null } | null };
  const topicRows = (topics ?? []) as T[];
  const weight = (lessonId: string, page: number) =>
    topicRows
      .filter((t) => t.material_id === lessonId && page >= (t.page_from ?? 0) && page <= (t.page_to ?? 0))
      .reduce((w, t) => {
        const tp = Array.isArray(t.topic_progress) ? t.topic_progress[0] : t.topic_progress;
        return Math.max(w, (t.teacher_said_exam ? 10 : 0) + (tp?.state === 'weak' ? 6 : 0) + t.importance);
      }, 0);
  const pages: Page[] = (chunks ?? []).map((c) => ({ lesson: index.get(c.material_id)!, page: c.page ?? 0, text: String(c.text), weight: weight(c.material_id, c.page ?? 0) }));
  const chosen = pickPages(pages, MAX_CHARS);

  const topicText = topicRows
    .map((t) => {
      const tp = Array.isArray(t.topic_progress) ? t.topic_progress[0] : t.topic_progress;
      const notes = [
        t.teacher_said_exam ? 'lecturer said it will be in the exam' : '',
        t.teacher_minutes ? `lecturer spent ${t.teacher_minutes} min` : '',
        tp?.state === 'weak' ? `student's weak topic (${tp.mastery ?? 0}%)` : '',
        `importance ${t.importance}`,
      ].filter(Boolean);
      return `- ${t.title} (L${index.get(t.material_id)} p.${t.page_from ?? '?'}-${t.page_to ?? '?'}): ${notes.join(', ')}`;
    })
    .join('\n');
  const quotes = (lectures ?? [])
    .flatMap((l) => {
      const c = l.material_content as unknown as { lecture: { quotes?: { kind: string; text: string }[] } | null } | { lecture: { quotes?: { kind: string; text: string }[] } | null }[] | null;
      return (Array.isArray(c) ? c[0]?.lecture : c?.lecture)?.quotes ?? [];
    })
    .slice(0, 10)
    .map((q) => `- (${q.kind}) "${q.text}"`)
    .join('\n');
  const useStyle = style && style.use_in_quizzes ? style : null;
  const styleText = useStyle
    ? `Lecturer's question style (from their old questions): types in percent ${JSON.stringify((useStyle.distribution as { types?: unknown }).types)}, options per question ${(useStyle.distribution as { options?: number }).options ?? 5}, patterns: ${((useStyle.distribution as { patterns?: string[] }).patterns ?? []).join(' | ')}; topics asked most: ${(useStyle.top_topics as { title: string }[]).map((x) => x.title).join(', ')}`
    : 'Lecturer style unknown: mix short patient cases with knowledge questions.';
  const wantedText = wanted.length ? `\nThe student asked for these question types only: ${wanted.join(', ')} (share them about equally).` : '';

  const kindsText = `\nQuestion formats asked for (kind): ${kinds.join(', ')} — share them about equally.`;
  const user = `Course: ${course.name}\nCONTENT LANGUAGE: ${LANG_NAMES[lang] ?? 'Turkish'}\nWrite ${count} questions.\n\n${styleText}${wantedText}${kindsText}\n\nLessons:\n${lessons.map((l, i) => `L${i + 1}: ${l.title}`).join('\n')}\n\nTopics:\n${topicText || '-'}\n\nWhat the lecturer said in recorded classes:\n${quotes || '-'}`;
  // The chosen pages come first and are cached: a second quiz on the same pages reads them from the cache.
  const pagesText = `Pages:\n${chosen.map((p) => `[L${p.lesson} p.${p.page}] ${p.text}`).join('\n')}`;

  try {
    const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')!.trim() });
    const params = {
      model: MODEL,
      max_tokens: 16000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'medium', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      messages: [{ role: 'user', content: [{ type: 'text', text: pagesText, cache_control: { type: 'ephemeral' } }, { type: 'text', text: user }] }],
    };
    // deno-lint-ignore no-explicit-any
    const res = await client.beta.messages.create(params as any);
    if (res.stop_reason === 'refusal') return json({ error: 'declined' }, 422);
    if (res.stop_reason === 'max_tokens') return json({ error: 'ai' }, 502);
    const block = res.content.find((b) => b.type === 'text');
    if (!block || block.type !== 'text') return json({ error: 'ai' }, 502);
    const out = JSON.parse(block.text) as Out;

    const { data: quiz, error } = await db
      .from('quizzes')
      .insert({ user_id: uid, course_id: courseId, kind: 'exam_prep', lang, teacher_style: !!useStyle, options: { count, styles: wanted, types: kinds } })
      .select('id')
      .single();
    if (error) throw error;
    const questions = out.questions.filter((q) =>
      kinds.includes(q.kind) &&
      (q.kind === 'multiple_choice' ? q.options.length >= 2 && q.answer_index >= 0 && q.answer_index < q.options.length : q.model_answer.trim().length > 0 && (q.kind !== 'fill_blank' || q.text.includes('____'))),
    );
    if (questions.length) {
      const { error: e2 } = await db.from('quiz_questions').insert(
        questions.map((q, i) => ({
          quiz_id: quiz.id,
          user_id: uid,
          sort_order: i,
          kind: q.kind,
          style_tag: q.style,
          text: q.text,
          options: q.kind === 'multiple_choice' ? q.options : [],
          answer_index: q.kind === 'multiple_choice' ? q.answer_index : null,
          model_answer: q.kind === 'multiple_choice' ? null : q.model_answer.trim(),
          explanation: q.explanation,
          source_page: q.page || null,
          hints: cleanHints(q.hints, q.kind === 'multiple_choice' ? q.options : [q.model_answer], q.kind === 'multiple_choice' ? q.answer_index : 0).slice(0, 3),
        })),
      );
      if (e2) throw e2;
    }
    const kindOf = { teacher: 'imp', samples: 'imp', weak: 'weak', base: 'base' } as const;
    const summaryTopics = out.topics.slice(0, 6).map((t) => {
      const row = topicRows.find((x) => x.title === t.title);
      const tp = row ? (Array.isArray(row.topic_progress) ? row.topic_progress[0] : row.topic_progress) : null;
      const reason =
        t.reason === 'weak'
          ? { type: 'weak', mastery: tp?.mastery ?? 0 }
          : t.reason === 'teacher'
            ? { type: 'teacher', minutes: Math.round(row?.teacher_minutes ?? 0) }
            : t.reason === 'samples'
              ? { type: 'samples', count: (useStyle?.top_topics as { title: string; count: number }[] | undefined)?.find((x) => x.title === t.title)?.count ?? 1 }
              : { type: 'base' };
      return { title: t.title, kind: kindOf[t.reason], reason, pageFrom: t.page_from, pageTo: t.page_to, points: t.points.slice(0, 4), ...(t.teacher ? { teacher: t.teacher } : {}) };
    });
    await db.from('summaries').insert({ user_id: uid, course_id: courseId, lang, kind: 'exam_prep', content: { topics: summaryTopics } });
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
    return json({ quiz_id: quiz.id, questions: questions.length });
  } catch (e) {
    console.error('generate-quiz', e);
    return json({ error: 'ai' }, 502);
  }
});
