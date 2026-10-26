import { supabase } from './supabase';
import type { Lang } from '../i18n/I18nProvider';

// "Ders özeti" (design ScrReview, tab "Bu ders"): one lesson's weak topics (from quiz results), the hard words the
// student tapped, and a short review summary from the PDF (Edge Function lesson-summary: made once, then kept).

export type WeakTopic = { id: string; title: string; page: number | null; mastery: number; sure: boolean };
export type TappedWord = { word: string; text: string; taps: number };
export type RecapPoint = { text: string; page_from: number; page_to: number };

export async function lessonSummaryData(materialId: string, lang: Lang) {
  type TopicRow = { id: string; title: string; page_from: number | null; topic_progress: { state: string; mastery: number | null }[] | { state: string; mastery: number | null } | null };
  type WordRow = { taps: number; material_terms: { surface: string; explanation: Record<string, { name: string; text: string }> } };
  type AnswerRow = { quiz_questions: { topic_id: string | null } | null };
  type AttemptRow = { score: number | null; started_at: string };
  const [lesson, topics, words, sure, attempt] = await Promise.all([
    supabase.from('materials').select('title, page_count').eq('id', materialId).maybeSingle<{ title: string; page_count: number | null }>(),
    supabase.from('material_topics').select('id, title, page_from, topic_progress(state, mastery)').eq('material_id', materialId).order('sort_order').returns<TopicRow[]>(),
    supabase
      .from('term_lookups')
      .select('taps, material_terms!inner(surface, explanation, material_id)')
      .eq('material_terms.material_id', materialId)
      .order('taps', { ascending: false })
      .limit(6)
      .returns<WordRow[]>(),
    supabase.from('quiz_answers').select('quiz_questions(topic_id)').eq('correct', false).eq('confidence', 'sure').returns<AnswerRow[]>(),
    supabase
      .from('quiz_attempts')
      .select('score, started_at, quizzes!inner(material_id)')
      .eq('quizzes.material_id', materialId)
      .not('score', 'is', null)
      .order('started_at', { ascending: false })
      .limit(1)
      .returns<AttemptRow[]>(),
  ]);
  for (const r of [topics, words, sure, attempt]) if (r.error) console.error('lessonSummaryData', r.error);
  const sureTopics = new Set((sure.data ?? []).map((a) => a.quiz_questions?.topic_id).filter(Boolean));
  const weak: WeakTopic[] = (topics.data ?? [])
    .map((t) => {
      const p = Array.isArray(t.topic_progress) ? t.topic_progress[0] : t.topic_progress;
      return { id: t.id, title: t.title, page: t.page_from, mastery: p?.mastery ?? 100, state: p?.state ?? 'unknown', sure: sureTopics.has(t.id) };
    })
    .filter((t) => t.state === 'weak' || t.mastery < 60)
    .sort((a, b) => a.mastery - b.mastery)
    .map(({ state: _state, ...t }) => t);
  const tapped: TappedWord[] = (words.data ?? []).map((w) => {
    const ex = w.material_terms.explanation[lang] ?? w.material_terms.explanation.tr ?? Object.values(w.material_terms.explanation)[0];
    return { word: w.material_terms.surface, text: ex?.text ?? '', taps: w.taps };
  });
  const last = attempt.data?.[0];
  return { title: lesson.data?.title ?? '', pages: lesson.data?.page_count ?? null, weak, words: tapped, score: last?.score != null ? Math.round(Number(last.score)) : null, scoredOn: last?.started_at ?? null };
}

/** The short review summary: a saved one at once, else the server makes it with the AI (once per lesson). */
export async function lessonRecap(materialId: string): Promise<{ points: RecapPoint[]; lang: Lang } | { error: 'locked' | 'budget' | 'failed' }> {
  const { data, error } = await supabase.functions.invoke('lesson-summary', { body: { material_id: materialId } });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return { error: status === 403 ? 'locked' : status === 429 ? 'budget' : 'failed' };
  }
  return data as { points: RecapPoint[]; lang: Lang };
}
