// Edge Function placement-test: the short placement test after an upload ("Seviye tespiti", design/NewPlacement.dc.html).
// POST { material_id, topic_ids? } → { quiz_id, count }. topic_ids = "Bir kısmını çalıştım": only these topics; none = all.
// No AI and free: the questions are copied from the lesson's own questions (quiz kind lesson_end, written by
// process-material), at most 2 per topic and 8 in all. A new test replaces the lesson's old one.
// The app plays it like any quiz; grade-quiz then writes the topic states (known / weak / to study) to topic_progress.
// Writes (service role): quizzes (kind placement) + quiz_questions.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { pickQuestions } from './pick.ts';

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

type Q = {
  id: string;
  topic_id: string;
  kind: string;
  style_tag: string | null;
  text: string;
  options: string[] | null;
  answer_index: number | null;
  explanation: string | null;
  source_page: number | null;
  hints: unknown;
  molecule: unknown;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  const materialId = body.material_id;
  if (typeof materialId !== 'string') return json({ error: 'material_id' }, 400);
  const { data: m } = await db.from('materials').select('user_id, course_id, status').eq('id', materialId).maybeSingle();
  if (!m || m.user_id !== uid) return json({ error: 'not found' }, 404);
  if (m.status !== 'ready') return json({ error: 'not ready' }, 409);

  const { data: topics } = await db.from('material_topics').select('id').eq('material_id', materialId).order('sort_order');
  const wanted = Array.isArray(body.topic_ids) ? new Set((body.topic_ids as unknown[]).map(String)) : null;
  const topicIds = (topics ?? []).map((t) => t.id as string).filter((id) => !wanted || wanted.has(id));

  // The lesson's own multiple-choice questions (all of them, oldest first: process-material wrote them per part).
  const { data: source } = await db.from('quizzes').select('id, lang').eq('material_id', materialId).eq('kind', 'lesson_end').maybeSingle();
  if (!source) return json({ error: 'no questions' }, 404);
  const { data: rows } = await db
    .from('quiz_questions')
    .select('id, topic_id, kind, style_tag, text, options, answer_index, explanation, source_page, hints, molecule')
    .eq('quiz_id', source.id)
    .eq('kind', 'multiple_choice')
    .not('topic_id', 'is', null)
    .order('sort_order');
  const picked = pickQuestions(topicIds, (rows ?? []) as Q[]);
  if (!picked.length) return json({ error: 'no questions' }, 404);

  // One placement test per lesson: the old one goes (its answers too; topic_progress stays).
  await db.from('quizzes').delete().eq('material_id', materialId).eq('kind', 'placement');
  const { data: quiz, error } = await db
    .from('quizzes')
    .insert({ user_id: uid, course_id: m.course_id, material_id: materialId, kind: 'placement', lang: source.lang, options: { count: picked.length, topic_ids: topicIds } })
    .select('id')
    .single();
  if (error || !quiz) return json({ error: 'failed' }, 500);
  const { error: e2 } = await db.from('quiz_questions').insert(
    picked.map((q, i) => ({
      quiz_id: quiz.id,
      user_id: uid,
      topic_id: q.topic_id,
      sort_order: i,
      kind: q.kind,
      style_tag: q.style_tag,
      text: q.text,
      options: q.options,
      answer_index: q.answer_index,
      explanation: q.explanation,
      source_page: q.source_page,
      hints: q.hints,
      molecule: q.molecule,
    })),
  );
  if (e2) return json({ error: 'failed' }, 500);
  return json({ quiz_id: quiz.id, count: picked.length });
});
