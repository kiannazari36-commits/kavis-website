import { supabase } from './supabase';
import { currentUser } from './auth';
import { isoToday } from './courses';
import type { QuestionKind } from './types';

// "Sınav merkezi" (design ScrReview "exam" / "examAll" / "setWeek"): the exam week from the courses' exam days, and
// exams put together by the server from the questions already written for the student's lessons (Edge Function
// build-exam, no AI). The same data access as the iPhone app (ios/KavisStudy/API/Exams.swift).

export type ExamKindName = 'midterm' | 'final' | 'makeup';
export const EXAM_KINDS: ExamKindName[] = ['midterm', 'final', 'makeup'];
export type CourseExam = { id: string; courseId: string; kind: ExamKindName; date: string };

/** Upcoming exams (today or later), nearest first. */
export async function upcomingExams(): Promise<CourseExam[]> {
  const { data, error } = await supabase
    .from('course_exams')
    .select('id, course_id, kind, exam_date')
    .gte('exam_date', isoToday())
    .order('exam_date')
    .returns<{ id: string; course_id: string; kind: string; exam_date: string }[]>();
  if (error) console.error('course_exams', error);
  return (data ?? [])
    .filter((r): r is typeof r & { kind: ExamKindName } => (EXAM_KINDS as string[]).includes(r.kind))
    .map((r) => ({ id: r.id, courseId: r.course_id, kind: r.kind, date: r.exam_date }));
}

/** The coming exam week: the kind of the nearest exam and the days of that kind within three weeks of it. */
export function examWeek(exams: CourseExam[]) {
  const first = exams[0];
  if (!first) return null;
  const limit = new Date(`${first.date}T00:00:00`);
  limit.setDate(limit.getDate() + 21);
  const same = exams.filter((e) => e.kind === first.kind && new Date(`${e.date}T00:00:00`) <= limit);
  return {
    kind: first.kind,
    from: first.date,
    to:
      same
        .map((e) => e.date)
        .sort()
        .pop() ?? first.date,
  };
}

/** Saves each course's exam day of this kind (an upcoming one of the same kind is moved, else added; '' = no change). */
export async function saveExamDays(kind: ExamKindName, days: Record<string, string>, existing: CourseExam[]): Promise<boolean> {
  const user = currentUser();
  if (!user) return false;
  for (const [courseId, day] of Object.entries(days)) {
    if (!day) continue;
    const old = existing.find((e) => e.courseId === courseId && e.kind === kind);
    const { error } = old
      ? await supabase.from('course_exams').update({ exam_date: day }).eq('id', old.id)
      : await supabase.from('course_exams').insert({ user_id: user.id, course_id: courseId, kind, exam_date: day });
    if (error) {
      console.error('saveExamDays', error);
      return false;
    }
  }
  return true;
}

/** How many questions are ready per course. */
export async function readyQuestions(): Promise<Record<string, number>> {
  const { data, error } = await supabase.functions.invoke('build-exam', { body: { action: 'overview' } });
  if (error) {
    console.error('build-exam overview', error);
    return {};
  }
  return Object.fromEntries((data.courses as { course_id: string; questions: number }[]).map((c) => [c.course_id, c.questions]));
}

/** Puts an exam together: one course or several, `count` questions of the chosen kinds, half on weak topics when `weakFocus`. */
export async function buildExam(courseIds: string[], count: number, weakFocus: boolean, types: QuestionKind[] = ['multiple_choice']): Promise<{ quizId: string } | { error: 'empty' | 'failed' }> {
  const { data, error } = await supabase.functions.invoke('build-exam', {
    body: { action: 'build', course_ids: courseIds, count, weak_focus: weakFocus, types },
  });
  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return { error: status === 404 ? 'empty' : 'failed' };
  }
  return { quizId: (data as { quiz_id: string }).quiz_id };
}
