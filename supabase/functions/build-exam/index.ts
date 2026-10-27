// Edge Function build-exam: "Sınav merkezi" (design ScrReview, tab "Sınav"). No AI, free: an exam is put together
// from the questions (multiple choice, fill in the blank, written) the server already wrote for the student's lessons (lesson end, section checks,
// exam packs, new questions).
// POST { action: 'overview' }                                   → { courses: [{ course_id, questions (multiple choice), types: { multiple_choice, fill_blank, written counts } }] }
// POST { action: 'build', course_ids, count, weak_focus, types? } → { quiz_id, questions } or 404 { error: 'empty' }
//   One course = "Derse özel sınav", several = "Genel sınav" (quizzes.kind 'combined'). With weak_focus, half of the
//   questions come from the student's weak topics and earlier wrong answers. The questions are copied into the new
//   quiz, so grade-quiz grades it like any other; quizzes.options.sources keeps each question's lesson
//   ("Sayfa n'e bak" opens the right PDF).
// Writes (service role): quizzes + quiz_questions.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

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

/** Quiz kinds whose questions are about the student's own lessons (not placement / style samples). */
const SOURCE_KINDS = ['section_check', 'lesson_end', 'exam_prep', 'review'];

type Kind = 'multiple_choice' | 'fill_blank' | 'written';
const KINDS: Kind[] = ['multiple_choice', 'fill_blank', 'written'];
type Question = {
  id: string; kind: Kind; model_answer: string | null; quiz_id: string; topic_id: string | null; style_tag: string | null; text: string; options: string[];
  answer_index: number | null; explanation: string | null; source_page: number | null; hints: unknown; molecule: unknown;
};
type Source = Question & { course_id: string; material_id: string | null; lang: string };

/** Every question of the student's lessons in these courses, of the chosen types (the same text once). */
async function sourceQuestions(db: SupabaseClient, uid: string, courseIds?: string[], kinds: Kind[] = KINDS): Promise<Source[]> {
  const { data: mats } = await db.from('materials').select('id, course_id').eq('user_id', uid);
  const courseOf = new Map((mats ?? []).map((m) => [m.id as string, m.course_id as string]));
  const { data: quizzes } = await db.from('quizzes').select('id, course_id, material_id, lang').eq('user_id', uid).in('kind', SOURCE_KINDS);
  const quizInfo = new Map<string, { course_id: string; material_id: string | null; lang: string }>();
  for (const q of quizzes ?? []) {
    const course = (q.course_id as string | null) ?? (q.material_id ? courseOf.get(q.material_id as string) : undefined);
    if (!course || (courseIds && !courseIds.includes(course))) continue;
    quizInfo.set(q.id as string, { course_id: course, material_id: q.material_id as string | null, lang: q.lang as string });
  }
  if (!quizInfo.size) return [];
  const { data: rows } = await db.from('quiz_questions')
    .select('id, quiz_id, kind, model_answer, topic_id, style_tag, text, options, answer_index, explanation, source_page, hints, molecule')
    .in('quiz_id', [...quizInfo.keys()]).in('kind', kinds);
  const seen = new Set<string>();
  const out: Source[] = [];
  for (const r of (rows ?? []) as Question[]) {
    if (r.kind === 'multiple_choice' ? !Array.isArray(r.options) || r.options.length < 2 : !r.model_answer) continue;
    const key = r.text.trim().toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ ...r, ...quizInfo.get(r.quiz_id)! });
  }
  return out;
}

/** Questions on weak topics or answered wrong before. */
async function weakIds(db: SupabaseClient, uid: string, qs: Source[]): Promise<Set<string>> {
  const { data: weak } = await db.from('topic_progress').select('topic_id').eq('user_id', uid).eq('state', 'weak');
  const topics = new Set((weak ?? []).map((w) => w.topic_id as string));
  const { data: wrong } = await db.from('quiz_answers').select('question_id').eq('user_id', uid).eq('correct', false);
  const wrongIds = new Set((wrong ?? []).map((w) => w.question_id as string));
  return new Set(qs.filter((q) => (q.topic_id && topics.has(q.topic_id)) || wrongIds.has(q.id)).map((q) => q.id));
}

function shuffle<T>(a: T[]): T[] {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Picks `count` questions: with weak focus half from the weak ones, the rest spread over the courses. */
export function pick(qs: Source[], weak: Set<string>, count: number, weakFocus: boolean): Source[] {
  const weakQs = shuffle(qs.filter((q) => weak.has(q.id)));
  const chosen: Source[] = weakFocus ? weakQs.slice(0, Math.floor(count / 2)) : [];
  const taken = new Set(chosen.map((q) => q.id));
  // The rest round-robin over the courses, so a combined exam is not all one course.
  const byCourse = new Map<string, Source[]>();
  for (const q of shuffle(qs.filter((q) => !taken.has(q.id)))) {
    byCourse.set(q.course_id, [...(byCourse.get(q.course_id) ?? []), q]);
  }
  const lists = [...byCourse.values()];
  while (chosen.length < count && lists.some((l) => l.length)) {
    for (const l of lists) if (l.length && chosen.length < count) chosen.push(l.shift()!);
  }
  return shuffle(chosen);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;
  const body = await req.json().catch(() => ({}));

  try {
    if (body.action === 'overview') {
      const qs = await sourceQuestions(db, uid);
      const counts = new Map<string, number>();
      const perKind = new Map<string, Record<string, number>>();
      for (const q of qs) {
        counts.set(q.course_id, (counts.get(q.course_id) ?? 0) + (q.kind === 'multiple_choice' ? 1 : 0));
        const k = perKind.get(q.course_id) ?? {};
        k[q.kind] = (k[q.kind] ?? 0) + 1;
        perKind.set(q.course_id, k);
      }
      return json({ courses: [...counts].map(([course_id, questions]) => ({ course_id, questions, types: perKind.get(course_id) })) });
    }

    if (body.action === 'build') {
      // After the trial only Premium may build a new exam (CLAUDE.md).
      const { data: allowed } = await db.rpc('can_use', { feature: 'generate', uid });
      if (!allowed) return json({ error: 'locked' }, 403);
      const courseIds = (Array.isArray(body.course_ids) ? body.course_ids : []).map(String);
      if (!courseIds.length) return json({ error: 'courses' }, 400);
      const count = Math.min(Math.max(Number(body.count) || 20, 5), 60);
      // The question types the student chose for this exam (none = multiple choice only, like before).
      const kinds = (Array.isArray(body.types) ? body.types : []).filter((x: unknown) => (KINDS as string[]).includes(String(x))) as Kind[];
      const qs = await sourceQuestions(db, uid, courseIds, kinds.length ? kinds : ['multiple_choice']);
      if (!qs.length) return json({ error: 'empty' }, 404);
      const chosen = pick(qs, await weakIds(db, uid, qs), count, body.weak_focus !== false);
      // The language most of the questions are in (the content language of those lessons).
      const langs = new Map<string, number>();
      for (const q of chosen) langs.set(q.lang, (langs.get(q.lang) ?? 0) + 1);
      const lang = [...langs].sort((a, b) => b[1] - a[1])[0][0];
      const { data: quiz, error } = await db.from('quizzes').insert({
        user_id: uid,
        course_id: courseIds.length === 1 ? courseIds[0] : null,
        kind: 'combined',
        lang,
        options: { count, weak_focus: body.weak_focus !== false, course_ids: courseIds, source: 'exam_center', types: kinds.length ? kinds : ['multiple_choice'] },
      }).select('id').single();
      if (error) throw error;
      const { data: copies, error: e2 } = await db.from('quiz_questions').insert(chosen.map((q, i) => ({
        quiz_id: quiz.id, user_id: uid, topic_id: q.topic_id, sort_order: i, kind: q.kind, model_answer: q.model_answer, style_tag: q.style_tag,
        text: q.text, options: q.options, answer_index: q.answer_index, explanation: q.explanation, source_page: q.source_page,
        hints: q.hints ?? [], molecule: q.molecule,
      }))).select('id, sort_order');
      if (e2) throw e2;
      const sources = Object.fromEntries((copies ?? []).map((c) => [c.id, chosen[c.sort_order as number].material_id]));
      await db.from('quizzes').update({ options: { count, weak_focus: body.weak_focus !== false, course_ids: courseIds, source: 'exam_center', sources } }).eq('id', quiz.id);
      return json({ quiz_id: quiz.id, questions: chosen.length });
    }
    return json({ error: 'action' }, 400);
  } catch (e) {
    console.error('build-exam', e);
    return json({ error: 'build' }, 500);
  }
});
