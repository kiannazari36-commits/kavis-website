import { supabase } from './supabase';
import { addDays, mondayOf } from './plan';
import { listCourses } from './courses';
import type { CourseColor } from './types';

// "İlerleme": everything is computed from the student's own rows. Scores and levels are written by the server
// (Edge Function grade-quiz); minutes come from the stopwatch (study_sessions).

export type RankLevel = 'good' | 'mid' | 'low';
export type CourseRank = {
  courseId: string;
  name: string;
  color: CourseColor;
  level: RankLevel;
  badge: 'strong' | 'rising' | 'steady' | 'weak';
  /** Graded scores (0–100), oldest first. */
  scores: number[];
  /** Score now, score at the start of the growth window, and the days between them. */
  current: number;
  from: number;
  days: number;
  /** For the note: the lesson read best, or the weakest topic with its mastery. */
  bestLesson?: string;
  hardest?: { title: string; mastery: number };
};
export type WeakTopic = { title: string; lesson: string; mastery: number; courseId: string | null; materialId: string };
export type BestHours = { from: number; to: number; rate: number; late: number | null };

export type Progress = {
  /** Minutes per weekday this week, Monday first. */
  weekMinutes: number[];
  streak: number;
  lastScore: number | null;
  /** Points compared with the exam before the last one. */
  lastDiff: number | null;
  level: string | null;
  termsTapped: number;
  ranking: CourseRank[];
  weak: WeakTopic[];
  bestHours: BestHours | null;
};

type Attempt = { score: number; level: string | null; started_at: string; quizzes: { course_id: string | null } | null };

const DAY = 86_400_000;

export async function getProgress(): Promise<Progress> {
  const monday = mondayOf();
  const [minutes, streak, attempts, weak, taps, courses] = await Promise.all([
    supabase.from('daily_minutes').select('day, minutes').gte('day', monday).lte('day', addDays(monday, 6)),
    supabase.rpc('study_streak'),
    supabase
      .from('quiz_attempts')
      .select('score, level, started_at, quizzes(course_id)')
      .not('score', 'is', null)
      .order('started_at')
      .returns<Attempt[]>(),
    supabase
      .from('topic_progress')
      .select('mastery, material_topics(title, material_id, materials(title, course_id))')
      .eq('state', 'weak')
      .order('mastery'),
    supabase.from('term_lookups').select('term_id', { count: 'exact', head: true }),
    listCourses(),
  ]);
  for (const r of [minutes, streak, attempts, weak, taps]) if (r.error) console.error('getProgress', r.error);

  const weekMinutes = Array.from({ length: 7 }, (_, i) => {
    const day = addDays(monday, i);
    return Math.round(Number((minutes.data ?? []).find((r) => r.day === day)?.minutes ?? 0));
  });

  const all = (attempts.data ?? []).map((a) => ({ ...a, score: Number(a.score) }));
  const last = all[all.length - 1];
  const prev = all[all.length - 2];

  type WeakRow = { mastery: number; material_topics: { title: string; material_id: string; materials: { title: string; course_id: string | null } } };
  const weakTopics: WeakTopic[] = ((weak.data ?? []) as unknown as WeakRow[]).map((w) => ({
    title: w.material_topics.title,
    lesson: w.material_topics.materials.title,
    mastery: w.mastery,
    courseId: w.material_topics.materials.course_id,
    materialId: w.material_topics.material_id,
  }));

  // Courses with graded exams, best current score first.
  const ranked = courses
    .map((c) => {
      const mine = all.filter((a) => a.quizzes?.course_id === c.id);
      if (!mine.length) return null;
      const current = mine[mine.length - 1];
      // Growth over the last 14 days (or since the first exam).
      const since = Date.parse(current.started_at) - 14 * DAY;
      const start = mine.find((a) => Date.parse(a.started_at) >= since) ?? mine[0];
      const hardest = weakTopics.find((w) => w.courseId === c.id);
      const bestLesson = [...c.pdfs].sort((a, b) => b.read - a.read)[0]?.title;
      return {
        courseId: c.id,
        name: c.short ?? c.name,
        color: c.color,
        scores: mine.map((a) => Math.round(a.score)),
        current: Math.round(current.score),
        from: Math.round(start.score),
        days: Math.max(1, Math.round((Date.parse(current.started_at) - Date.parse(start.started_at)) / DAY)),
        bestLesson,
        hardest: hardest && { title: hardest.title, mastery: hardest.mastery },
      };
    })
    .filter((x): x is NonNullable<typeof x> => x !== null)
    .sort((a, b) => b.current - a.current);
  const ranking: CourseRank[] = ranked.map((r, i) => {
    const top = i === 0 && ranked.length > 1;
    const bottom = i === ranked.length - 1 && ranked.length > 1;
    const level: RankLevel = top ? 'good' : bottom ? 'low' : 'mid';
    const badge = top ? 'strong' : bottom ? 'weak' : r.current > r.from ? 'rising' : 'steady';
    return { ...r, level, badge };
  });

  return {
    weekMinutes,
    streak: (streak.data as number | null) ?? 0,
    lastScore: last ? Math.round(last.score) : null,
    lastDiff: last && prev ? Math.round(last.score - prev.score) : null,
    level: last?.level ?? null,
    termsTapped: taps.count ?? 0,
    ranking,
    weak: weakTopics,
    bestHours: bestHours(all),
  };
}

/** The 2-hour window with the best average score (at least 2 exams), and the average after 22:00. */
function bestHours(all: { score: number; started_at: string }[]): BestHours | null {
  const hour = (a: { started_at: string }) => new Date(a.started_at).getHours();
  let best: BestHours | null = null;
  for (let h = 6; h <= 22; h++) {
    const inside = all.filter((a) => hour(a) >= h && hour(a) < h + 2);
    if (inside.length < 2) continue;
    const rate = Math.round(inside.reduce((x, a) => x + a.score, 0) / inside.length);
    if (!best || rate > best.rate) best = { from: h, to: h + 2, rate, late: null };
  }
  const late = all.filter((a) => hour(a) >= 22 || hour(a) < 4);
  if (best && late.length) best.late = Math.round(late.reduce((x, a) => x + a.score, 0) / late.length);
  return best;
}

/** Days in a row with at least 5 minutes of study (for the flame button on the top bar). */
export async function getStreak() {
  const { data, error } = await supabase.rpc('study_streak');
  if (error) console.error('study_streak', error);
  return (data as number | null) ?? 0;
}
