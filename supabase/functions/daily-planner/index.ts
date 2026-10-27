// Edge Function daily-planner: the nightly job (pg_cron every hour at :05, migration 20261027105541).
// For every student whose local time is 04:xx it
//   1. makes this week's Kavis plan again (same rules as build-plan, plan_mode 'aim' only),
//   2. makes today's short review ("Bugünün tekrarı", review_sessions) for the lesson that needs it most,
//   3. writes the day's reminder at the student's notification time: 'review_day' (review_reminder on) or
//      'start_now' (today's plan), and on Monday the 'weekly_report' of last week (weekly_report on).
// Every step skips what already exists for today, so a second run does nothing new.
// POST {} with header x-cron-key (private.app_secrets 'cron_key'); { force: true, user_id?, weekday? } runs now,
// whatever the hour (for tests). Writes with the service role only.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { build } from '../build-plan/build.ts';
import { addDays, daysBetween, mondayOf } from '../build-plan/planner.ts';
import { localNow, pickReview, planNotice, PLANNER_HOUR, reviewNotice, safeZone, weeklyNotice, zonedToUtc, type Lang, type ReviewLesson, type ReviewTopic } from './jobs.ts';

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function secretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
  return Object.values(keys)[0] ?? '';
}

const LANGS = ['tr', 'en', 'fa', 'ar'];
/** Stop starting new students after this long (the platform ends a run after 150 s). */
const BUDGET_MS = 120_000;

type Student = {
  user_id: string;
  time_zone: string;
  plan_mode: string;
  notify_time: string;
  review_reminder: boolean;
  weekly_report: boolean;
  profiles: { app_lang: string; created_at: string } | null;
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method' }, 405);
  const db = createClient(Deno.env.get('SUPABASE_URL')!, secretKey(), { auth: { persistSession: false } });
  const { data: ok } = await db.rpc('check_cron_key', { key: req.headers.get('x-cron-key') ?? '' });
  if (ok !== true) return json({ error: 'key' }, 401);

  const body = await req.json().catch(() => ({}));
  const force = body.force === true;
  const started = Date.now();
  const now = new Date();
  const done = { students: 0, plans: 0, reviews: 0, notices: 0, errors: 0, left: 0 };

  for (let from = 0; ; from += 1000) {
    let q = db
      .from('user_settings')
      .select('user_id, time_zone, plan_mode, notify_time, review_reminder, weekly_report, profiles(app_lang, created_at)')
      .order('user_id')
      .range(from, from + 999);
    if (typeof body.user_id === 'string') q = q.eq('user_id', body.user_id);
    const { data, error } = await q;
    if (error) return json({ error: 'students' }, 500);
    for (const s of (data ?? []) as unknown as Student[]) {
      const tz = safeZone(s.time_zone);
      const local = localNow(now, tz);
      if (!force && local.hour !== PLANNER_HOUR) continue;
      if (Date.now() - started > BUDGET_MS) {
        done.left++;
        continue;
      }
      done.students++;
      try {
        // Tests may ask for Monday's weekly report on another day ({ force: true, weekday: 1 }).
        const r = await runStudent(db, s, tz, local.date, force && body.weekday ? Number(body.weekday) : local.weekday);
        done.plans += r.plan;
        done.reviews += r.review;
        done.notices += r.notices;
      } catch (e) {
        done.errors++;
        console.error('daily-planner', s.user_id, e);
      }
    }
    if ((data ?? []).length < 1000) break;
  }
  if (done.left) console.error('daily-planner: out of time, students left', done.left);
  return json(done);
});

async function runStudent(db: SupabaseClient, s: Student, tz: string, today: string, weekday: number) {
  const uid = s.user_id;
  const lang = (LANGS.includes(s.profiles?.app_lang ?? '') ? s.profiles!.app_lang : 'tr') as Lang;
  const out = { plan: 0, review: 0, notices: 0 };

  if (s.plan_mode === 'aim') {
    const r = await build(db, uid, today, lang, s.profiles?.created_at ?? null);
    if (!('skipped' in r)) out.plan = 1;
  }

  const review = await todaysReview(db, uid, today);
  if (review.made) out.review = 1;

  // Notifications already written for today (one of each kind per day).
  const { data: have } = await db.from('notifications').select('kind').eq('user_id', uid).eq('data->>day', today);
  const had = new Set((have ?? []).map((n) => n.kind));
  const sendAt = zonedToUtc(today, s.notify_time ?? '09:00', tz);
  const rows: Record<string, unknown>[] = [];

  const reviewNote = !!review.row && s.review_reminder;
  if (reviewNote && !had.has('review_day')) {
    const c = review.row!.content as { cards?: number; questions?: number };
    const n = reviewNotice(lang, review.title, review.row!.minutes, c.cards ?? 0, c.questions ?? 0);
    rows.push({ kind: 'review_day', ...n, data: { to: `/review?id=${review.row!.id}`, day: today }, send_at: sendAt });
  } else if (!reviewNote && s.plan_mode === 'aim' && !had.has('start_now')) {
    const { data: tasks } = await db
      .from('plan_items')
      .select('title, minutes')
      .eq('user_id', uid)
      .eq('day', today)
      .eq('status', 'todo')
      .order('sort_order');
    if (tasks?.length) {
      const n = planNotice(lang, tasks.length, tasks.reduce((a, x) => a + x.minutes, 0), tasks[0].title);
      rows.push({ kind: 'start_now', ...n, data: { to: '/plan', day: today }, send_at: sendAt });
    }
  }

  if (weekday === 1 && s.weekly_report && !had.has('weekly_report')) {
    const w = await lastWeek(db, uid, today, tz);
    if (w.minutes >= 1 || w.avg !== null) {
      rows.push({ kind: 'weekly_report', ...weeklyNotice(lang, w.minutes, w.days, w.avg), data: { to: '/progress', day: today }, send_at: sendAt });
    }
  }

  if (rows.length) {
    const { error } = await db.from('notifications').insert(rows.map((r) => ({ ...r, user_id: uid })));
    if (error) throw error;
    out.notices = rows.length;
  }
  return out;
}

type ReviewRow = { id: string; minutes: number; content: unknown; materials: { title: string } | null };

/** Today's review: the one already there (also one moved to today), else a new one if a lesson needs it. */
async function todaysReview(db: SupabaseClient, uid: string, today: string) {
  const { data: existing } = await db
    .from('review_sessions')
    .select('id, minutes, content, materials(title)')
    .eq('user_id', uid)
    .eq('scheduled_for', today)
    .limit(1)
    .maybeSingle();
  if (existing) {
    const r = existing as unknown as ReviewRow;
    return { made: false, row: r, title: r.materials?.title ?? '' };
  }

  const endOfToday = `${today}T23:59:59Z`;
  const [materials, topics, cards, decks, checks, summaries, exams] = await Promise.all([
    db.from('materials').select('id, course_id, title').eq('user_id', uid).eq('status', 'ready'),
    db.from('material_topics').select('id, material_id, title, teacher_said_exam, topic_progress(state, next_review_at)').eq('user_id', uid),
    db.from('flashcards').select('deck_id').eq('user_id', uid).lte('due_at', endOfToday),
    db.from('card_decks').select('id, material_id').eq('user_id', uid).not('material_id', 'is', null),
    db.from('quizzes').select('material_id, quiz_questions(count)').eq('user_id', uid).eq('kind', 'section_check'),
    db.from('summaries').select('material_id').eq('user_id', uid).eq('kind', 'lesson'),
    db.from('course_exams').select('course_id, exam_date').eq('user_id', uid).gte('exam_date', today).order('exam_date'),
  ]);

  const deckLesson = new Map((decks.data ?? []).map((d) => [d.id, d.material_id as string]));
  const dueCards = new Map<string, number>();
  for (const c of cards.data ?? []) {
    const m = deckLesson.get(c.deck_id);
    if (m) dueCards.set(m, (dueCards.get(m) ?? 0) + 1);
  }
  const questions = new Map<string, number>();
  for (const q of checks.data ?? []) {
    const n = (q.quiz_questions as unknown as { count: number }[])?.[0]?.count ?? 0;
    if (q.material_id) questions.set(q.material_id, (questions.get(q.material_id) ?? 0) + n);
  }
  const withSummary = new Set((summaries.data ?? []).map((x) => x.material_id));
  const nextExam = new Map<string, string>();
  for (const e of exams.data ?? []) if (!nextExam.has(e.course_id)) nextExam.set(e.course_id, e.exam_date);

  const lessons: ReviewLesson[] = (materials.data ?? []).map((m) => {
    const exam = m.course_id ? nextExam.get(m.course_id) : undefined;
    return {
      id: m.id,
      courseId: m.course_id,
      dueCards: dueCards.get(m.id) ?? 0,
      questions: questions.get(m.id) ?? 0,
      hasSummary: withSummary.has(m.id),
      examInDays: exam ? daysBetween(today, exam) : null,
    };
  });
  const topicIn: ReviewTopic[] = (topics.data ?? []).map((t) => {
    const tp = (Array.isArray(t.topic_progress) ? t.topic_progress[0] : t.topic_progress) as { state: string; next_review_at: string | null } | null;
    return { id: t.id, materialId: t.material_id, title: t.title, weak: tp?.state === 'weak', dueOn: tp?.next_review_at ?? null, teacherSaidExam: t.teacher_said_exam };
  });

  const pick = pickReview(today, lessons, topicIn);
  if (!pick) return { made: false, row: null, title: '' };
  const { data: row, error } = await db
    .from('review_sessions')
    .insert({ user_id: uid, scheduled_for: today, ...pick })
    .select('id, minutes, content, materials(title)')
    .single();
  if (error) throw error;
  const r = row as unknown as ReviewRow;
  return { made: true, row: r, title: r.materials?.title ?? '' };
}

/** Last week (Monday … Sunday before today's Monday): study minutes, days with ≥ 5 minutes, quiz average. */
async function lastWeek(db: SupabaseClient, uid: string, today: string, tz: string) {
  const start = addDays(mondayOf(today), -7);
  const from = zonedToUtc(start, '00:00', tz);
  const to = zonedToUtc(mondayOf(today), '00:00', tz);
  const [sessions, attempts] = await Promise.all([
    db.from('study_sessions').select('started_at, minutes').eq('user_id', uid).gte('started_at', from).lt('started_at', to),
    db.from('quiz_attempts').select('score').eq('user_id', uid).not('score', 'is', null).gte('started_at', from).lt('started_at', to),
  ]);
  const perDay = new Map<string, number>();
  let minutes = 0;
  for (const x of sessions.data ?? []) {
    const m = Number(x.minutes) || 0;
    minutes += m;
    const day = new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(new Date(x.started_at));
    perDay.set(day, (perDay.get(day) ?? 0) + m);
  }
  const days = [...perDay.values()].filter((m) => m >= 5).length;
  const scores = (attempts.data ?? []).map((a) => Number(a.score));
  const avg = scores.length ? scores.reduce((a, b) => a + b, 0) / scores.length : null;
  return { minutes: Math.round(minutes), days, avg };
}
