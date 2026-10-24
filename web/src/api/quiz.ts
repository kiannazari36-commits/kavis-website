import { supabase } from './supabase';
import { currentUser } from './auth';
import type { Lang } from '../i18n/I18nProvider';
import type { ExamTopic, QuizQuestion } from './types';
import { runPlanner } from './plan';

/** Exam-prep pack of a course: summary topics by importance + a quiz in the lecturer's style (made by the server). */
export type ExamPack = { quizId: string; lang: Lang; topics: ExamTopic[]; questions: QuizQuestion[] };

type QRow = {
  id: string;
  style_tag: string | null;
  text: string;
  options: string[] | null;
  answer_index: number | null;
  explanation: string | null;
  source_page: number | null;
  hints: string[];
  molecule: { name?: string } | null;
  material_topics: { title: string } | null;
};

const toQuestion = (r: QRow): QuizQuestion => ({
  id: r.id,
  style: r.style_tag ?? 'knowledge',
  text: r.text,
  options: r.options ?? [],
  answer: r.answer_index ?? 0,
  why: r.explanation ?? '',
  page: r.source_page,
  topic: r.material_topics?.title ?? '',
  hints: r.hints ?? [],
  molecule: r.molecule?.name === 'captopril' ? 'captopril' : undefined,
});

/** The newest quiz of a kind for a course (or one lesson), with its questions in order. */
async function latestQuiz(kind: 'exam_prep' | 'section_check' | 'lesson_end', filter: { course?: string; material?: string }) {
  let q = supabase.from('quizzes').select('id, lang').eq('kind', kind).order('created_at', { ascending: false }).limit(1);
  if (filter.course) q = q.eq('course_id', filter.course);
  if (filter.material) q = q.eq('material_id', filter.material);
  const { data: quiz, error } = await q.maybeSingle<{ id: string; lang: Lang }>();
  if (error) console.error('latestQuiz', error);
  if (!quiz) return null;
  const { data, error: e2 } = await supabase
    .from('quiz_questions')
    .select('id, style_tag, text, options, answer_index, explanation, source_page, hints, molecule, material_topics(title)')
    .eq('quiz_id', quiz.id)
    .order('sort_order')
    .returns<QRow[]>();
  if (e2) console.error('quiz_questions', e2);
  return { quizId: quiz.id, lang: quiz.lang, questions: (data ?? []).map(toQuestion) };
}

/** null: the pack for this course is not made yet (the server makes it about a week before the exam). */
export async function getExamPack(courseId: string): Promise<ExamPack | null> {
  const [quiz, summary] = await Promise.all([
    latestQuiz('exam_prep', { course: courseId }),
    supabase
      .from('summaries')
      .select('content')
      .eq('course_id', courseId)
      .eq('kind', 'exam_prep')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle<{ content: { topics: ExamTopic[] } }>(),
  ]);
  if (!quiz) return null;
  return { ...quiz, topics: summary.data?.content.topics ?? [] };
}

/** Courses that already have an exam-prep pack. */
export async function coursesWithPack(): Promise<string[]> {
  const { data } = await supabase.from('quizzes').select('course_id').eq('kind', 'exam_prep');
  return [...new Set((data ?? []).map((r) => r.course_id as string))];
}

/**
 * The short check after a section in the reader: up to 3 of the lesson's questions from that section's pages.
 * (Example lessons without lesson questions have a ready-made section_check quiz.) null = no questions there.
 */
export async function getSectionCheck(materialId: string, pageFrom?: number, pageTo?: number) {
  const lesson = await latestQuiz('lesson_end', { material: materialId });
  if (lesson) {
    const questions = lesson.questions
      .filter((q) => pageFrom === undefined || (q.page !== null && q.page >= pageFrom && q.page <= (pageTo ?? pageFrom)))
      .slice(0, 3);
    return questions.length ? { ...lesson, questions } : null;
  }
  return latestQuiz('section_check', { material: materialId });
}

/**
 * How many questions the check after each section would have, so the reader shows the box only where there are
 * questions. Returns a counter for a page range (max 3, like getSectionCheck).
 */
export async function sectionCheckCounter(materialId: string): Promise<{ count: (pageFrom: number, pageTo: number) => number }> {
  // (An object, not a bare function: React would call a function given to setState.)
  const lesson = await latestQuiz('lesson_end', { material: materialId });
  if (lesson) {
    const pages = lesson.questions.map((q) => q.page).filter((p): p is number => p !== null);
    return { count: (from, to) => Math.min(3, pages.filter((p) => p >= from && p <= to).length) };
  }
  const check = await latestQuiz('section_check', { material: materialId });
  const n = check?.questions.length ?? 0;
  return { count: () => n };
}

export type GivenAnswer = { questionId: string; chosen: number | null; hints: number; confidence?: 'sure' | 'unsure' | 'guess' };

/**
 * Saves a finished try, then asks the server to grade it (Edge Function grade-quiz): it sets right/wrong,
 * the score and level, topic mastery, and adds wrong answers given with "sure" to the "Hatalarım" cards.
 * The app itself never writes scores.
 */
export async function saveAttempt(quizId: string, answers: GivenAnswer[]) {
  const user = currentUser();
  if (!user || !answers.length) return;
  const id = crypto.randomUUID();
  const started = await supabase.from('quiz_attempts').insert({ id, quiz_id: quizId, user_id: user.id });
  if (started.error) return console.error('quiz_attempts', started.error);
  const rows = answers.map((a) => ({
    attempt_id: id,
    question_id: a.questionId,
    user_id: user.id,
    chosen_index: a.chosen,
    hints_used: a.hints,
    confidence: a.confidence ?? null,
  }));
  const saved = await supabase.from('quiz_answers').insert(rows);
  if (saved.error) return console.error('quiz_answers', saved.error);
  const done = await supabase.from('quiz_attempts').update({ finished_at: new Date().toISOString() }).eq('id', id);
  if (done.error) console.error('finish attempt', done.error);
  const graded = await supabase.functions.invoke('grade-quiz', { body: { attempt_id: id } });
  if (graded.error) console.error('grade-quiz', graded.error);
  return graded.data as { score: number | null; level: string | null } | null;
}

/** "Add wrong answers to my plan": a 15-minute mistakes task tomorrow (Edge Function build-plan). */
export async function addWrongsToPlan(courseId: string | null, count: number) {
  return (await runPlanner('add_mistakes', { course_id: courseId || null, count })) !== null;
}

/** Study reminder time ("Yarın saat kaçta?") = user_settings.notify_time. */
export async function setStudyReminder(time: string) {
  const user = currentUser();
  if (!user) return;
  const { error } = await supabase.from('user_settings').update({ notify_time: time }).eq('user_id', user.id);
  if (error) console.error('setStudyReminder', error);
}
