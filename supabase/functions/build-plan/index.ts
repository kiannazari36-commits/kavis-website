// Edge Function build-plan: the Kavis study plan of the signed-in student (rules in planner.ts, no AI, free).
// POST { action: 'build' | 'light_day' | 'add_mistakes', today: 'YYYY-MM-DD' (the student's own date), course_id?, count? }
//   build        → makes the rest of this week (today … Sunday): done tasks and past days stay, the rest is made
//                  again from courses, exams, timetable, unread pages, weak topics and due cards.
//   light_day    → "Bugün az vaktim var": today keeps the 2 most important tasks, the others move to later days.
//   add_mistakes → "Yanlışları plana ekle": a 15-minute mistakes task tomorrow.
// Writes study_plans + plan_items with the service role (the apps only tick tasks off and move missed ones).
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { addDays, buildPlan, daysBetween, lightDay, mondayOf, TEXT, type CourseIn, type ExamKind, type Lang, type LessonIn, type TopicIn } from './planner.ts';

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

const LANGS = ['tr', 'en', 'fa', 'ar'];
/** The first 2 weeks of an account the plan is basic (courses split evenly), then smart. */
const BASIC_DAYS = 14;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });

  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const { data: who } = await db.auth.getUser(token);
  if (!who?.user) return json({ error: 'not signed in' }, 401);
  const uid = who.user.id;

  const body = await req.json().catch(() => ({}));
  // The student's own date (time zones); only a day away from the server's date is believed.
  const serverToday = new Date().toISOString().slice(0, 10);
  const today = typeof body.today === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(body.today) && Math.abs(daysBetween(serverToday, body.today)) <= 1 ? body.today : serverToday;

  const { data: profile } = await db.from('profiles').select('app_lang, created_at').eq('id', uid).single();
  const lang = (LANGS.includes(profile?.app_lang) ? profile!.app_lang : 'tr') as Lang;

  try {
    if (body.action === 'light_day') return json(await light(db, uid, today));
    if (body.action === 'add_mistakes') return json(await addMistakes(db, uid, today, lang, body.course_id ?? null, Number(body.count) || 0));
    return json(await build(db, uid, today, lang, profile?.created_at ?? null));
  } catch (e) {
    console.error('build-plan', e);
    return json({ error: 'plan' }, 500);
  }
});

/** This week's plan row (made if missing). */
async function planFor(db: SupabaseClient, uid: string, weekStart: string, stage?: string, reasons?: unknown) {
  const { data: plan } = await db.from('study_plans').select('id').eq('user_id', uid).eq('week_start', weekStart).maybeSingle();
  if (plan && stage === undefined) return plan.id as string;
  const row = { user_id: uid, week_start: weekStart, ...(stage ? { stage, reasons, generated_at: new Date().toISOString() } : {}) };
  const { data, error } = await db.from('study_plans').upsert(row, { onConflict: 'user_id,week_start' }).select('id').single();
  if (error) throw error;
  return data.id as string;
}

async function build(db: SupabaseClient, uid: string, today: string, lang: Lang, createdAt: string | null) {
  const { data: settings } = await db.from('user_settings').select('plan_mode, study_days, study_hours').eq('user_id', uid).single();
  if (settings?.plan_mode !== 'aim') return { skipped: 'mode' };
  const weekStart = mondayOf(today);
  const endOfToday = `${today}T23:59:59Z`;

  const [courses, exams, timetable, materials, progress, quizzes, topics, cards, existing] = await Promise.all([
    db.from('courses').select('id, name, short_name').eq('user_id', uid).is('archived_at', null),
    db.from('course_exams').select('course_id, kind, exam_date').eq('user_id', uid).gte('exam_date', today).order('exam_date'),
    db.from('timetable_entries').select('course_id, weekday, start_time, end_time').eq('user_id', uid),
    db.from('materials').select('id, course_id, title, page_count').eq('user_id', uid).eq('status', 'ready'),
    db.from('reading_progress').select('material_id, pages_read').eq('user_id', uid),
    db.from('quizzes').select('material_id').eq('user_id', uid).eq('kind', 'lesson_end'),
    db.from('material_topics').select('id, material_id, title, importance, teacher_said_exam, topic_progress(state, mastery, next_review_at)').eq('user_id', uid),
    db.from('flashcards').select('from_mistake').eq('user_id', uid).lte('due_at', endOfToday),
    db.from('study_plans').select('id, plan_items(id, day, minutes, status)').eq('user_id', uid).eq('week_start', weekStart).maybeSingle(),
  ]);

  const firstExam = new Map<string, { date: string; kind: ExamKind }>();
  for (const e of exams.data ?? []) if (!firstExam.has(e.course_id)) firstExam.set(e.course_id, { date: e.exam_date, kind: e.kind });
  const classLoad: Record<number, number> = {};
  const classDays = new Map<string, number[]>();
  for (const t of timetable.data ?? []) {
    const [h1, m1] = String(t.start_time).split(':').map(Number);
    const [h2, m2] = String(t.end_time ?? t.start_time).split(':').map(Number);
    classLoad[t.weekday] = (classLoad[t.weekday] ?? 0) + Math.max(50, h2 * 60 + m2 - (h1 * 60 + m1));
    if (t.course_id) classDays.set(t.course_id, [...(classDays.get(t.course_id) ?? []), t.weekday]);
  }
  const courseIn: CourseIn[] = (courses.data ?? []).map((c) => ({
    id: c.id,
    name: c.short_name || c.name,
    exam: firstExam.get(c.id) ?? null,
    classDays: classDays.get(c.id) ?? [],
  }));
  const courseIds = new Set(courseIn.map((c) => c.id));
  const read = new Map((progress.data ?? []).map((r) => [r.material_id, r.pages_read as number[]]));
  const withQuiz = new Set((quizzes.data ?? []).map((q) => q.material_id));
  const lessonIn: LessonIn[] = (materials.data ?? [])
    .filter((m) => !m.course_id || courseIds.has(m.course_id))
    .map((m) => ({ id: m.id, courseId: m.course_id, title: m.title, pages: m.page_count ?? 0, pagesRead: read.get(m.id) ?? [], hasQuiz: withQuiz.has(m.id) }));
  const lessonCourse = new Map(lessonIn.map((l) => [l.id, l.courseId]));
  const topicIn: TopicIn[] = (topics.data ?? [])
    .filter((t) => lessonCourse.has(t.material_id))
    .map((t) => {
      const tp = (Array.isArray(t.topic_progress) ? t.topic_progress[0] : t.topic_progress) as { state: string; mastery: number | null; next_review_at: string | null } | null;
      return {
        courseId: lessonCourse.get(t.material_id) ?? null,
        materialId: t.material_id,
        title: t.title,
        mastery: tp?.mastery ?? null,
        importance: t.importance,
        weak: tp?.state === 'weak',
        dueOn: tp?.next_review_at ?? null,
        teacherSaidExam: t.teacher_said_exam,
      };
    });

  // Tasks that stay: past days, and anything already done.
  const old = (existing.data?.plan_items ?? []) as { id: string; day: string; minutes: number; status: string }[];
  const doneToday = old.filter((x) => x.day === today && x.status === 'done').reduce((a, x) => a + x.minutes, 0);
  const stage = createdAt && daysBetween(createdAt.slice(0, 10), today) >= BASIC_DAYS ? 'smart' : 'basic';

  const out = buildPlan({
    today,
    lang,
    stage,
    studyDays: settings.study_days,
    minutesPerDay: Math.round(Number(settings.study_hours) * 60),
    courses: courseIn,
    lessons: lessonIn,
    topics: topicIn,
    dueCards: (cards.data ?? []).filter((c) => !c.from_mistake).length,
    mistakeCards: (cards.data ?? []).filter((c) => c.from_mistake).length,
    classLoad,
    doneToday,
  });

  const planId = await planFor(db, uid, weekStart, stage, out.reasons);
  const drop = old.filter((x) => x.day >= today && x.status !== 'done').map((x) => x.id);
  if (drop.length) await db.from('plan_items').delete().in('id', drop);
  if (out.items.length) {
    const { error } = await db.from('plan_items').insert(out.items.map((x) => ({ ...x, plan_id: planId, user_id: uid })));
    if (error) throw error;
  }
  return { plan_id: planId, stage, items: out.items.length };
}

async function light(db: SupabaseClient, uid: string, today: string) {
  const { data: plan } = await db.from('study_plans').select('id, plan_items(id, day, minutes, status, sort_order)').eq('user_id', uid).eq('week_start', mondayOf(today)).maybeSingle();
  const items = (plan?.plan_items ?? []) as { id: string; day: string; minutes: number; status: string; sort_order: number }[];
  const todays = items.filter((x) => x.day === today && x.status === 'todo');
  const later: Record<string, number> = {};
  for (const x of items) if (x.day > today && x.status === 'todo') later[x.day] = (later[x.day] ?? 0) + x.minutes;
  const r = lightDay(today, todays, later);
  for (const m of r.move) await db.from('plan_items').update({ day: m.day }).eq('id', m.id);
  // Sunday: no later day this week; next week's plan takes the work up again.
  const stay = new Set([...r.keep, ...r.move.map((m) => m.id)]);
  const rest = todays.filter((x) => !stay.has(x.id)).map((x) => x.id);
  if (rest.length) await db.from('plan_items').update({ status: 'removed' }).in('id', rest);
  return { kept: r.keep.length, moved: r.move.map((m) => m.day) };
}

async function addMistakes(db: SupabaseClient, uid: string, today: string, lang: Lang, courseId: string | null, count: number) {
  const day = addDays(today, 1);
  const planId = await planFor(db, uid, mondayOf(day));
  const { data: last } = await db.from('plan_items').select('sort_order').eq('plan_id', planId).eq('day', day).order('sort_order', { ascending: false }).limit(1);
  const T = TEXT[lang];
  const { error } = await db.from('plan_items').insert({
    plan_id: planId,
    user_id: uid,
    day,
    course_id: courseId,
    kind: 'mistakes',
    title: T.mistakes(),
    minutes: 15,
    why: T.mistakesWhy(Math.max(1, count)),
    target: 'cards',
    sort_order: (last?.[0]?.sort_order ?? -1) + 1,
  });
  if (error) throw error;
  return { day };
}
