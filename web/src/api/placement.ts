import { supabase } from './supabase';
import { getQuizById } from './quiz';

// Placement test after an upload ("Seviye tespiti", design/NewPlacement.dc.html). The server (Edge placement-test)
// copies the lesson's own questions into a short test: no AI, free. grade-quiz then writes each topic's state
// (known / weak / todo) to topic_progress; the plan and the cards use it.

export type PlacementTopic = { id: string; title: string; pageFrom: number | null; pageTo: number | null; questions: number };
export type PlacementLesson = { title: string; pages: number; topics: PlacementTopic[] };

/** Same rules as the server (supabase/functions/placement-test/pick.ts). */
export const MAX_QUESTIONS = 8;
export const PER_TOPIC = 2;

/** How many questions a test on these topics has. */
export function questionCount(topics: PlacementTopic[]) {
  return Math.min(MAX_QUESTIONS, topics.reduce((n, t) => n + Math.min(PER_TOPIC, t.questions), 0));
}

/** The lesson's title, page count and topics in order, with how many test questions each topic has. */
export async function placementLesson(materialId: string): Promise<PlacementLesson | null> {
  const [{ data: m }, { data: topics }, { data: quiz }] = await Promise.all([
    supabase.from('materials').select('title, page_count').eq('id', materialId).maybeSingle(),
    supabase.from('material_topics').select('id, title, page_from, page_to').eq('material_id', materialId).order('sort_order'),
    supabase.from('quizzes').select('id').eq('material_id', materialId).eq('kind', 'lesson_end').maybeSingle(),
  ]);
  if (!m) return null;
  const { data: qs } = quiz
    ? await supabase.from('quiz_questions').select('topic_id').eq('quiz_id', quiz.id).eq('kind', 'multiple_choice')
    : { data: [] as { topic_id: string | null }[] };
  const per = new Map<string, number>();
  for (const q of qs ?? []) if (q.topic_id) per.set(q.topic_id, (per.get(q.topic_id) ?? 0) + 1);
  return {
    title: m.title,
    pages: m.page_count ?? 0,
    topics: (topics ?? []).map((t) => ({ id: t.id, title: t.title, pageFrom: t.page_from, pageTo: t.page_to, questions: per.get(t.id) ?? 0 })),
  };
}

/** A test with its questions and each question's topic; null when it is gone (a newer test replaced it). */
export async function placementQuiz(quizId: string) {
  const [quiz, { data }] = await Promise.all([getQuizById(quizId), supabase.from('quiz_questions').select('id, topic_id').eq('quiz_id', quizId)]);
  if (!quiz?.questions.length) return null;
  return { ...quiz, topicOf: Object.fromEntries((data ?? []).map((q) => [q.id, q.topic_id as string])) as Record<string, string> };
}
export type PlacementQuiz = NonNullable<Awaited<ReturnType<typeof placementQuiz>>>;

/** Makes a new test (on some topics only, or all); 'none' when the lesson has no questions for it. */
export async function startPlacement(materialId: string, topicIds?: string[]): Promise<PlacementQuiz | 'none' | null> {
  const { data, error } = await supabase.functions.invoke('placement-test', { body: { material_id: materialId, ...(topicIds ? { topic_ids: topicIds } : {}) } });
  if (error || !data?.quiz_id) {
    const status = (error as { context?: Response } | null)?.context?.status;
    if (status === 404) return 'none';
    console.error('placement-test', error);
    return null;
  }
  return placementQuiz(data.quiz_id as string);
}

/** A test in progress, kept on this device ("Sonra devam et"). */
export type SavedTest = { quizId: string; topicIds: string[] | null; index: number; answers: Record<string, number | 'x'> };
const key = (materialId: string) => `kavis.placement.${materialId}`;

export function savedTest(materialId: string): SavedTest | null {
  try {
    const v = localStorage.getItem(key(materialId));
    return v ? (JSON.parse(v) as SavedTest) : null;
  } catch {
    return null;
  }
}

export function keepTest(materialId: string, t: SavedTest | null) {
  try {
    if (t) localStorage.setItem(key(materialId), JSON.stringify(t));
    else localStorage.removeItem(key(materialId));
  } catch {
    /* storage blocked: the test just starts again next time */
  }
}
