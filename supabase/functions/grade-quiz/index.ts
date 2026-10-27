// Edge Function grade-quiz: grades a finished quiz attempt of the signed-in student.
// POST { attempt_id } → { score, level, results: [{ question_id, correct }] }
// Writes (service role, never the apps): quiz_answers.correct, quiz_attempts.score/level,
// topic_progress (mastery, weak/known, next review), "Hatalarım" cards for wrong answers given with "sure",
// and an 'exam_result' notification for real exams (lesson end, exam prep, combined; not section checks).
import { createClient } from 'npm:@supabase/supabase-js@2';
import { grade, resultNotice, topicState, type AnswerRow, type QuestionRow } from './grade.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const LETTERS = 'ABCDEFGH';
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

// The service key is provided by the platform (legacy name first, then the new secret keys).
function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  // Who is calling (the platform already checked the JWT: verify_jwt = true).
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who, error: authError } = await admin.auth.getUser(token);
  if (authError || !who.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const { attempt_id } = await req.json().catch(() => ({}));
  if (typeof attempt_id !== 'string') return json({ error: 'attempt_id' }, 400);

  const { data: attempt } = await admin
    .from('quiz_attempts')
    .select('id, quiz_id, user_id, score, level, quizzes(course_id, lang, kind)')
    .eq('id', attempt_id)
    .maybeSingle();
  if (!attempt || attempt.user_id !== uid) return json({ error: 'not found' }, 404);
  const quiz = attempt.quizzes as unknown as { course_id: string | null; lang: string; kind: string };

  const { data: answers } = await admin
    .from('quiz_answers')
    .select('question_id, chosen_index, dont_know, hints_used, confidence, correct')
    .eq('attempt_id', attempt_id);
  // Already graded: return the saved result (grading twice must not add cards twice).
  if (attempt.score !== null) {
    return json({ score: Number(attempt.score), level: attempt.level, results: (answers ?? []).map((a) => ({ question_id: a.question_id, correct: a.correct })) });
  }
  const ids = (answers ?? []).map((a) => a.question_id);
  const { data: questions } = await admin
    .from('quiz_questions')
    .select('id, kind, answer_index, topic_id, text, options, explanation, source_page')
    .in('id', ids.length ? ids : ['00000000-0000-0000-0000-000000000000']);

  const g = grade((questions ?? []) as QuestionRow[], (answers ?? []) as AnswerRow[]);

  for (const r of g.results) {
    if (r.correct === null) continue;
    await admin.from('quiz_answers').update({ correct: r.correct }).eq('attempt_id', attempt_id).eq('question_id', r.question_id);
  }
  await admin.from('quiz_attempts').update({ score: g.score, level: g.level }).eq('id', attempt_id);

  // The result also goes to the notifications list (marked sent: the student sees it on screen, no push).
  if (g.score !== null && g.level && ['lesson_end', 'exam_prep', 'combined'].includes(quiz.kind)) {
    const graded = g.results.filter((r) => r.correct !== null);
    const { data: prof } = await admin.from('profiles').select('app_lang').eq('id', uid).single();
    const n = resultNotice(prof?.app_lang ?? 'tr', g.score, g.level, graded.filter((r) => r.correct).length, graded.length);
    const now = new Date().toISOString();
    await admin.from('notifications').insert({ user_id: uid, kind: 'exam_result', ...n, data: { to: '/progress', attempt_id }, send_at: now, sent_at: now });
  }

  // Topic mastery from all of the student's graded answers on these topics (view topic_mastery).
  const topics = [...new Set((questions ?? []).map((q) => q.topic_id).filter(Boolean))] as string[];
  if (topics.length) {
    const { data: mastery } = await admin.from('topic_mastery').select('topic_id, mastery').eq('user_id', uid).in('topic_id', topics);
    const today = new Date();
    for (const m of mastery ?? []) {
      const state = topicState(m.mastery);
      const next = new Date(today.getTime() + (state === 'weak' ? 1 : 4) * 86_400_000).toISOString().slice(0, 10);
      await admin
        .from('topic_progress')
        .upsert({ user_id: uid, topic_id: m.topic_id, state, mastery: m.mastery, next_review_at: next }, { onConflict: 'user_id,topic_id' });
    }
  }

  // "Add mistakes to cards": wrong answers given with "sure" go to the course's "Hatalarım" deck.
  if (g.confidentMistakes.length) {
    let deckQuery = admin.from('card_decks').select('id').eq('user_id', uid).eq('title', 'Hatalarım');
    deckQuery = quiz.course_id ? deckQuery.eq('course_id', quiz.course_id) : deckQuery.is('course_id', null);
    let { data: deck } = await deckQuery.maybeSingle();
    if (!deck) {
      ({ data: deck } = await admin
        .from('card_decks')
        .insert({ user_id: uid, course_id: quiz.course_id, lang: quiz.lang, title: 'Hatalarım' })
        .select('id')
        .single());
    }
    if (deck) {
      const { data: existing } = await admin.from('flashcards').select('question').eq('deck_id', deck.id);
      // The question part of each card (the options come after an empty line), to skip mistakes already added.
      const have = new Set((existing ?? []).map((c) => (c.question as string).split('\n\n')[0]));
      const cards = g.confidentMistakes
        .filter((q) => !have.has(q.text))
        .map((q) => ({
          deck_id: deck!.id,
          user_id: uid,
          // The options stay on the card, so a test question can still be answered.
          question: q.options?.length ? `${q.text}\n\n${q.options.map((o, i) => `${LETTERS[i]}) ${o}`).join('\n')}` : q.text,
          answer: q.options?.length ? `${LETTERS[q.answer_index ?? 0]}) ${q.options[q.answer_index ?? 0]}` : '',
          note: q.explanation,
          page: q.source_page,
          from_mistake: true,
        }));
      if (cards.length) await admin.from('flashcards').insert(cards);
    }
  }

  return json({ score: g.score, level: g.level, results: g.results });
});
