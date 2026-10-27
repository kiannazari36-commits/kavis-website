import { supabase } from './supabase';
import { dueCards } from './cards';
import { getSectionCheck } from './quiz';
import type { FlashCard, QuizQuestion } from './types';

// "Bugünün tekrarı" (design NewRevise): the short review the daily planner made for today (table review_sessions):
// a summary of the lesson's weak points, the due cards, 3 questions. The student's results are saved like everywhere
// else: card ratings (rateCard) and the questions as a quiz try the server grades (saveAttempt → grade-quiz).

export type Review = {
  id: string;
  materialId: string | null;
  courseId: string | null;
  title: string;
  minutes: number;
  cards: number;
  status: string;
};

export async function getReview(id: string): Promise<Review | null> {
  const { data, error } = await supabase
    .from('review_sessions')
    .select('id, material_id, course_id, minutes, content, status, materials(title)')
    .eq('id', id)
    .maybeSingle<{
      id: string;
      material_id: string | null;
      course_id: string | null;
      minutes: number;
      status: string;
      content: { cards?: number };
      materials: { title: string } | null;
    }>();
  if (error) console.error('review_sessions', error);
  if (!data) return null;
  return {
    id: data.id,
    materialId: data.material_id,
    courseId: data.course_id,
    title: data.materials?.title ?? '',
    minutes: data.minutes,
    cards: data.content.cards ?? 6,
    status: data.status,
  };
}

/** The cards of the review: the lesson's due cards, else the course's. */
export async function reviewCards(r: Review): Promise<FlashCard[]> {
  const own = r.materialId ? await dueCards({ materialId: r.materialId }, r.cards) : [];
  if (own.length || !r.courseId) return own;
  return dueCards({ courseId: r.courseId }, r.cards);
}

/** Up to 3 questions of the lesson (weak topics first). */
export async function reviewQuestions(r: Review): Promise<{ quizId: string; questions: QuizQuestion[] } | null> {
  if (!r.materialId) return null;
  const q = await getSectionCheck(r.materialId);
  return q && q.questions.length ? { quizId: q.quizId, questions: q.questions.slice(0, 3) } : null;
}
