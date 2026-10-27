// Pure rules of the nightly job daily-planner (no database, so they can be tested anywhere):
// the student's local time, which lesson gets today's short review, and the notification texts.

export type Lang = 'tr' | 'en' | 'fa' | 'ar';

/** The job plans a student's day when it is 04:xx at the student's place. */
export const PLANNER_HOUR = 4;

// ───────────── time zones ─────────────

function partsIn(ms: number, tz: string) {
  const f = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  });
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return { y: +p.year, mo: +p.month, d: +p.day, h: +p.hour, mi: +p.minute, s: +p.second };
}

/** A time zone the platform knows, else Istanbul (the default of user_settings). */
export function safeZone(tz: string | null | undefined) {
  try {
    new Intl.DateTimeFormat('en', { timeZone: tz ?? '' });
    return tz as string;
  } catch {
    return 'Europe/Istanbul';
  }
}

/** The student's own date (YYYY-MM-DD), hour and weekday (1 = Monday) at this moment. */
export function localNow(now: Date, tz: string) {
  const p = partsIn(now.getTime(), tz);
  const date = `${p.y}-${String(p.mo).padStart(2, '0')}-${String(p.d).padStart(2, '0')}`;
  const weekday = ((new Date(`${date}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;
  return { date, hour: p.h, weekday };
}

/** "09:00[:00]" on a local date in a time zone → the moment in UTC (ISO). */
export function zonedToUtc(date: string, time: string, tz: string) {
  const [y, mo, d] = date.split('-').map(Number);
  const [h, mi] = time.split(':').map(Number);
  const wall = Date.UTC(y, mo - 1, d, h, mi);
  const offset = (ms: number) => {
    const p = partsIn(ms, tz);
    return Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s) - ms;
  };
  let t = wall - offset(wall);
  const again = offset(t);
  if (wall - again !== t) t = wall - again; // the day the clocks change
  return new Date(t).toISOString();
}

// ───────────── today's review ("Bugünün tekrarı") ─────────────

export type ReviewTopic = {
  id: string;
  materialId: string;
  title: string;
  weak: boolean;
  /** next_review_at (forgetting), or null */
  dueOn: string | null;
  teacherSaidExam: boolean;
};
export type ReviewLesson = {
  id: string;
  courseId: string | null;
  dueCards: number;
  /** questions of the lesson's section check */
  questions: number;
  hasSummary: boolean;
  /** days to the course's next exam, or null */
  examInDays: number | null;
};
export type Reason = 'forgetting' | 'weak' | 'lecturer' | 'exam';
export type ReviewOut = {
  material_id: string;
  course_id: string | null;
  minutes: number;
  content: { topics: { id: string; title: string; reason: Reason }[]; cards: number; questions: number; summary: boolean };
};

const EXAM_SOON = 7;
const MAX_CARDS = 10;
const MAX_TOPICS = 5;

/** The lesson that most needs a short review today (topics due or weak, due cards, exam soon), or null. */
export function pickReview(today: string, lessons: ReviewLesson[], topics: ReviewTopic[]): ReviewOut | null {
  let best: { lesson: ReviewLesson; score: number; topics: ReviewOut['content']['topics'] } | null = null;
  for (const lesson of lessons) {
    const examSoon = lesson.examInDays !== null && lesson.examInDays >= 0 && lesson.examInDays <= EXAM_SOON;
    const picked: { id: string; title: string; reason: Reason; w: number }[] = [];
    for (const t of topics) {
      if (t.materialId !== lesson.id) continue;
      const due = t.dueOn !== null && t.dueOn <= today;
      if (t.weak) picked.push({ id: t.id, title: t.title, reason: 'weak', w: 3 + (examSoon ? 1 : 0) });
      else if (due) picked.push({ id: t.id, title: t.title, reason: 'forgetting', w: 2 });
      else if (examSoon && t.teacherSaidExam) picked.push({ id: t.id, title: t.title, reason: 'lecturer', w: 2 });
    }
    const cards = Math.min(lesson.dueCards, MAX_CARDS);
    if (!picked.length && !cards) continue;
    const score = picked.reduce((a, x) => a + x.w, 0) + cards * 0.3 + (examSoon ? 2 : 0);
    if (!best || score > best.score) {
      picked.sort((a, b) => b.w - a.w);
      best = { lesson, score, topics: picked.slice(0, MAX_TOPICS).map(({ id, title, reason }) => ({ id, title, reason })) };
    }
  }
  if (!best) return null;
  const cards = Math.min(best.lesson.dueCards, MAX_CARDS);
  const questions = Math.min(3, best.lesson.questions);
  const summary = best.lesson.hasSummary || best.topics.length > 0;
  const minutes = Math.max(5, Math.min(15, Math.round((summary ? 2 : 0) + cards * 0.5 + questions * 1.5)));
  return { material_id: best.lesson.id, course_id: best.lesson.courseId, minutes, content: { topics: best.topics, cards, questions, summary } };
}

// ───────────── notification texts (app language) ─────────────

const hm = (lang: Lang, min: number) => {
  const h = Math.floor(min / 60);
  const m = Math.round(min % 60);
  const u = { tr: ['sa', 'dk'], en: ['h', 'min'], fa: ['ساعت', 'دقیقه'], ar: ['ساعة', 'دقيقة'] }[lang];
  return h ? `${h} ${u[0]} ${m} ${u[1]}` : `${m} ${u[1]}`;
};

/** "Bugünün planı hazır" — the day's tasks of the Kavis plan. */
export function planNotice(lang: Lang, tasks: number, minutes: number, first: string) {
  switch (lang) {
    case 'en': return { title: "Today's plan is ready", body: `${tasks} tasks · ${hm(lang, minutes)} · first: ${first}` };
    case 'fa': return { title: 'برنامهٔ امروز آماده است', body: `${tasks} کار · ${hm(lang, minutes)} · اول: ${first}` };
    case 'ar': return { title: 'خطة اليوم جاهزة', body: `${tasks} مهام · ${hm(lang, minutes)} · أولاً: ${first}` };
    default: return { title: 'Bugünün planı hazır', body: `${tasks} görev · ${hm(lang, minutes)} · ilk: ${first}` };
  }
}

/** "Bugün tekrar günü" — the short review the job made. */
export function reviewNotice(lang: Lang, lesson: string, minutes: number, cards: number, questions: number) {
  switch (lang) {
    case 'en': return { title: 'Review day today', body: `${lesson} · ${minutes} min: summary, ${cards} cards, ${questions} questions` };
    case 'fa': return { title: 'امروز روز مرور است', body: `${lesson} · ${minutes} دقیقه: خلاصه، ${cards} کارت، ${questions} سؤال` };
    case 'ar': return { title: 'اليوم يوم المراجعة', body: `${lesson} · ${minutes} دقيقة: ملخص، ${cards} بطاقات، ${questions} أسئلة` };
    default: return { title: 'Bugün tekrar günü', body: `${lesson} · ${minutes} dk: özet, ${cards} kart, ${questions} soru` };
  }
}

/** The weekly report of last week (Monday morning). avg = average quiz score or null. */
export function weeklyNotice(lang: Lang, minutes: number, days: number, avg: number | null) {
  const a = avg === null ? '' : Math.round(avg);
  switch (lang) {
    case 'en': return { title: 'Your weekly report', body: `Last week: ${hm(lang, minutes)} · ${days} days${a !== '' ? ` · quiz average ${a}%` : ''}` };
    case 'fa': return { title: 'گزارش هفتگی تو', body: `هفتهٔ گذشته: ${hm(lang, minutes)} · ${days} روز${a !== '' ? ` · میانگین آزمون ${a}٪` : ''}` };
    case 'ar': return { title: 'تقريرك الأسبوعي', body: `الأسبوع الماضي: ${hm(lang, minutes)} · ${days} أيام${a !== '' ? ` · متوسط الاختبارات ${a}%` : ''}` };
    default: return { title: 'Haftalık raporun hazır', body: `Geçen hafta: ${hm(lang, minutes)} · ${days} gün${a !== '' ? ` · sınav ortalaman %${a}` : ''}` };
  }
}
