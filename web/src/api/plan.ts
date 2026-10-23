import { supabase } from './supabase';
import { isoToday } from './courses';

// The plan is made by the server (Edge Function build-plan, daily planner); the app reads it and updates
// a task's status and day (done, moved after a missed day).

export type PlanStage = 'basic' | 'smart';
export type TaskKind = 'read' | 'review' | 'quiz' | 'cards' | 'exam_prep' | 'mistakes' | 'placement';
export type TaskTarget = 'reader' | 'quiz' | 'cards' | 'review' | 'exam_prep';
export type TaskStatus = 'todo' | 'done' | 'missed' | 'moved' | 'removed';

export type PlanTask = {
  id: string;
  /** YYYY-MM-DD */
  day: string;
  courseId: string | null;
  materialId: string | null;
  kind: TaskKind;
  title: string;
  minutes: number;
  /** Why it is in the plan (content language), e.g. "zayıf konun · %38". */
  why: string;
  target: TaskTarget;
  status: TaskStatus;
};

/** A reason shown under "Why does the plan look like this?" (content language). */
export type PlanReason = { text: string; color: 'pri' | 'amb' | 'good' };

export type WeekPlan = { id: string; stage: PlanStage; weekStart: string; reasons: PlanReason[]; tasks: PlanTask[] };

/** Monday of this week (YYYY-MM-DD). */
export function mondayOf(iso = isoToday()) {
  return addDays(iso, -((new Date(`${iso}T12:00:00`).getDay() + 6) % 7));
}

export function addDays(iso: string, n: number) {
  const d = new Date(`${iso}T12:00:00`);
  d.setDate(d.getDate() + n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

type Row = {
  id: string;
  day: string;
  course_id: string | null;
  material_id: string | null;
  kind: TaskKind;
  title: string;
  minutes: number;
  why: string | null;
  target: TaskTarget;
  status: TaskStatus;
};
const toTask = (r: Row): PlanTask => ({
  id: r.id,
  day: r.day,
  courseId: r.course_id,
  materialId: r.material_id,
  kind: r.kind,
  title: r.title,
  minutes: r.minutes,
  why: r.why ?? '',
  target: r.target,
  status: r.status,
});

/** This week's plan, or null when the server has not made one yet. */
export async function getWeekPlan(): Promise<WeekPlan | null> {
  const weekStart = mondayOf();
  const { data: plan, error } = await supabase
    .from('study_plans')
    .select('id, stage, week_start, reasons')
    .eq('week_start', weekStart)
    .maybeSingle<{ id: string; stage: PlanStage; week_start: string; reasons: PlanReason[] }>();
  if (error) console.error('study_plans', error);
  if (!plan) return null;
  const { data, error: e2 } = await supabase
    .from('plan_items')
    .select('id, day, course_id, material_id, kind, title, minutes, why, target, status')
    .eq('plan_id', plan.id)
    .neq('status', 'removed')
    .order('day')
    .order('sort_order');
  if (e2) console.error('plan_items', e2);
  return { id: plan.id, stage: plan.stage, weekStart: plan.week_start, reasons: plan.reasons ?? [], tasks: ((data ?? []) as Row[]).map(toTask) };
}

export async function setTaskDone(id: string, done: boolean) {
  const { error } = await supabase
    .from('plan_items')
    .update({ status: done ? 'done' : 'todo', done_at: done ? new Date().toISOString() : null })
    .eq('id', id);
  if (error) console.error('setTaskDone', error);
}

/**
 * "I missed yesterday": unfinished tasks of past days move to the coming study days of this week
 * (the day with the fewest minutes first). Returns the days they moved to.
 */
export async function rescheduleMissed(plan: WeekPlan): Promise<string[]> {
  const today = isoToday();
  const missed = plan.tasks.filter((x) => x.day < today && x.status === 'todo');
  const sunday = addDays(plan.weekStart, 6);
  // Coming days that already have tasks (rest days stay free); today counts too.
  const load = new Map<string, number>();
  for (const x of plan.tasks) if (x.day >= today && x.day <= sunday) load.set(x.day, (load.get(x.day) ?? 0) + x.minutes);
  if (!load.size) load.set(today, 0);
  const moved: string[] = [];
  for (const x of missed) {
    const [day] = [...load.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))[0];
    load.set(day, (load.get(day) ?? 0) + x.minutes);
    const { error } = await supabase.from('plan_items').update({ day }).eq('id', x.id);
    if (error) console.error('rescheduleMissed', error);
    else moved.push(day);
  }
  return moved;
}

/** Today's short review ("Bugün tekrar günü"): summary + cards + questions, made by the daily planner. */
export type TodayReview = { id: string; title: string; minutes: number; cards: number; questions: number; summary: boolean; status: TaskStatus };

export async function getTodayReview(): Promise<TodayReview | null> {
  const { data, error } = await supabase
    .from('review_sessions')
    .select('id, minutes, content, status, materials(title)')
    .eq('scheduled_for', isoToday())
    .eq('status', 'todo')
    .limit(1)
    .maybeSingle<{ id: string; minutes: number; status: TaskStatus; content: { cards?: number; questions?: number; summary?: boolean }; materials: { title: string } | null }>();
  if (error) console.error('review_sessions', error);
  if (!data) return null;
  return {
    id: data.id,
    title: data.materials?.title ?? '',
    minutes: data.minutes,
    cards: data.content.cards ?? 0,
    questions: data.content.questions ?? 0,
    summary: !!data.content.summary,
    status: data.status,
  };
}

/** "Later" moves the review to tomorrow; "done" closes it. */
export async function setReview(id: string, action: 'done' | 'tomorrow') {
  const change = action === 'done' ? { status: 'done', done_at: new Date().toISOString() } : { scheduled_for: addDays(isoToday(), 1) };
  const { error } = await supabase.from('review_sessions').update(change).eq('id', id);
  if (error) console.error('setReview', error);
}

/** Where a task opens. */
export function taskLink(x: PlanTask) {
  const c = x.courseId ? `course=${x.courseId}` : '';
  if (x.target === 'reader' && x.materialId) return `/reader?${c}&pdf=${x.materialId}`;
  if (x.target === 'quiz' || x.target === 'exam_prep') return `/quiz?${c}${x.target === 'quiz' ? '&tab=quiz' : ''}`;
  if (x.target === 'cards' || x.target === 'review') return `/cards${c ? `?${c}` : ''}`;
  return x.courseId ? `/courses/${x.courseId}` : '/courses';
}
