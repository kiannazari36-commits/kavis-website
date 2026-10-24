// Pure rules of build-plan (no database, no AI, so it is free and can be tested anywhere).
// Makes the rest of this week's plan, from today to Sunday: which days, which tasks, how long, and why.

export type Lang = 'tr' | 'en' | 'fa' | 'ar';
export type ExamKind = 'midterm' | 'final' | 'makeup' | 'quiz' | 'other';
export type Kind = 'read' | 'review' | 'quiz' | 'cards' | 'exam_prep' | 'mistakes';
export type Target = 'reader' | 'quiz' | 'cards' | 'review' | 'exam_prep';

export type CourseIn = { id: string; name: string; exam: { date: string; kind: ExamKind } | null; classDays: number[] };
export type LessonIn = { id: string; courseId: string | null; title: string; pages: number; pagesRead: number[]; hasQuiz: boolean };
export type TopicIn = {
  courseId: string | null;
  materialId: string;
  title: string;
  mastery: number | null;
  importance: number;
  weak: boolean;
  /** next_review_at: the day it should be repeated (forgetting), or null. */
  dueOn: string | null;
  teacherSaidExam: boolean;
};

export type PlanInput = {
  today: string;
  lang: Lang;
  stage: 'basic' | 'smart';
  studyDays: number;
  minutesPerDay: number;
  courses: CourseIn[];
  lessons: LessonIn[];
  topics: TopicIn[];
  dueCards: number;
  mistakeCards: number;
  /** Class minutes per weekday (1 = Monday) from the timetable. */
  classLoad: Record<number, number>;
  /** Minutes of today's tasks already done (they stay in the plan). */
  doneToday: number;
};

export type Item = {
  day: string;
  course_id: string | null;
  material_id: string | null;
  kind: Kind;
  title: string;
  minutes: number;
  why: string;
  target: Target;
  sort_order: number;
};
export type Reason = { text: string; color: 'pri' | 'amb' | 'good' };
export type PlanOut = { weekStart: string; items: Item[]; reasons: Reason[] };

/** Reading speed used for the plan: 2 minutes per page. */
const MIN_PER_PAGE = 2;
const PAGES_PER_TASK = 12;
/** At most this many tasks of one course on one day, so a day mixes courses. */
const PER_COURSE_DAY = 2;
/** Exam reviews start 7 days before an exam; at most 2 of them on one day. */
const EXAM_WINDOW = 7;
const EXAM_PER_DAY = 2;

// ───────────── dates (YYYY-MM-DD, no time zone) ─────────────

export function addDays(iso: string, n: number) {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
/** 1 = Monday … 7 = Sunday */
export const weekday = (iso: string) => ((new Date(`${iso}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;
export const mondayOf = (iso: string) => addDays(iso, 1 - weekday(iso));
export const daysBetween = (a: string, b: string) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
const round5 = (n: number) => Math.round(n / 5) * 5;
/** "4–9", or "4" for one page. */
const pages = (a: string | number, b: string | number) => (a === b ? `${a}` : `${a}–${b}`);

// ───────────── texts in the app language ─────────────

const LOCALE: Record<Lang, string> = { tr: 'tr-TR', en: 'en-GB', fa: 'fa-IR-u-ca-gregory', ar: 'ar-u-nu-latn' };
const dayMonth = (iso: string, lang: Lang) =>
  new Intl.DateTimeFormat(LOCALE[lang], { day: 'numeric', month: 'long', timeZone: 'UTC' }).format(new Date(`${iso}T00:00:00Z`));

const EXAM: Record<Lang, Record<ExamKind, string>> = {
  tr: { midterm: 'Vize', final: 'Final', makeup: 'Bütünleme', quiz: 'Quiz', other: 'Sınav' },
  en: { midterm: 'Midterm', final: 'Final', makeup: 'Make-up exam', quiz: 'Quiz', other: 'Exam' },
  fa: { midterm: 'میان‌ترم', final: 'پایان‌ترم', makeup: 'امتحان جبرانی', quiz: 'کوییز', other: 'امتحان' },
  ar: { midterm: 'الامتحان النصفي', final: 'الامتحان النهائي', makeup: 'امتحان الإعادة', quiz: 'اختبار قصير', other: 'امتحان' },
};

export const TEXT: Record<Lang, Record<string, (...a: (string | number)[]) => string>> = {
  tr: {
    examPrep: (c) => `${c} · sınava özel tekrar`,
    examWhy: (k, d, n) => (Number(n) === 0 ? `${k} bugün · ${d}` : `${k} · ${d} · ${n} gün kaldı`),
    mistakes: () => 'Hatalarım kartları',
    mistakesWhy: (n) => `${n} yanlış cevabın`,
    cards: () => 'Tekrar kartları',
    cardsWhy: (n) => `${n} kartın tekrar zamanı geldi`,
    weakWhy: (m) => `zayıf konun · %${m}`,
    dueWhy: () => 'tekrar zamanı · unutmadan',
    teacherWhy: () => 'hoca sınavda soracağını söyledi',
    pagesWhy: (a, b, n) => `s. ${pages(a, b)} · ${n} sayfa kaldı`,
    quiz: (t) => `${t} · soruları çöz`,
    quizWhy: () => 'okuduğunu sorularla pekiştir',
    rExam: (c, k, d) => `${c} ${String(k).toLocaleLowerCase('tr')}: ${d} · sınava özel tekrar öne alındı`,
    rWeak: (n) => `${n} zayıf konu tekrar ediliyor`,
    rClass: () => 'Dersin olduğu gün o dersin okuması konuldu',
    rBasic: () => 'İlk 2 hafta: dersler eşit dağıtılıyor',
    rEmpty: () => 'Henüz ders PDF\'in yok · PDF yükleyince plan dolacak',
  },
  en: {
    examPrep: (c) => `${c} · exam review`,
    examWhy: (k, d, n) => (Number(n) === 0 ? `${k} today · ${d}` : `${k} · ${d} · ${n} days left`),
    mistakes: () => 'My mistakes cards',
    mistakesWhy: (n) => `${n} wrong answers`,
    cards: () => 'Review cards',
    cardsWhy: (n) => `${n} cards are due`,
    weakWhy: (m) => `weak topic · ${m}%`,
    dueWhy: () => 'time to repeat · before you forget',
    teacherWhy: () => 'the lecturer said it will be in the exam',
    pagesWhy: (a, b, n) => `p. ${pages(a, b)} · ${n} pages left`,
    quiz: (t) => `${t} · practice questions`,
    quizWhy: () => 'check what you read with questions',
    rExam: (c, k, d) => `${c} ${String(k).toLowerCase()}: ${d} · exam review comes first`,
    rWeak: (n) => `${n} weak topics are repeated`,
    rClass: () => 'On a class day you read that course',
    rBasic: () => 'First 2 weeks: courses are split evenly',
    rEmpty: () => 'No lesson PDFs yet · the plan fills up once you upload one',
  },
  fa: {
    examPrep: (c) => `${c} · مرور ویژهٔ امتحان`,
    examWhy: (k, d, n) => (Number(n) === 0 ? `${k} امروز · ${d}` : `${k} · ${d} · ${n} روز مانده`),
    mistakes: () => 'کارت‌های اشتباه‌هایم',
    mistakesWhy: (n) => `${n} جواب اشتباه`,
    cards: () => 'کارت‌های مرور',
    cardsWhy: (n) => `وقت مرور ${n} کارت است`,
    weakWhy: (m) => `مبحث ضعیف · ${m}٪`,
    dueWhy: () => 'وقت مرور · قبل از فراموشی',
    teacherWhy: () => 'استاد گفت در امتحان می‌آید',
    pagesWhy: (a, b, n) => `ص. ${pages(a, b)} · ${n} صفحه مانده`,
    quiz: (t) => `${t} · حل سؤال`,
    quizWhy: () => 'خوانده‌هایت را با سؤال محکم کن',
    rExam: (c, k, d) => `${k} ${c}: ${d} · مرور امتحان جلو افتاد`,
    rWeak: (n) => `${n} مبحث ضعیف مرور می‌شود`,
    rClass: () => 'روز کلاس، همان درس خوانده می‌شود',
    rBasic: () => '2 هفته اول: درس‌ها مساوی تقسیم می‌شوند',
    rEmpty: () => 'هنوز PDF درسی نداری · با آپلود PDF برنامه پر می‌شود',
  },
  ar: {
    examPrep: (c) => `${c} · مراجعة خاصة بالامتحان`,
    examWhy: (k, d, n) => (Number(n) === 0 ? `${k} اليوم · ${d}` : `${k} · ${d} · بقي ${n} يوم`),
    mistakes: () => 'بطاقات أخطائي',
    mistakesWhy: (n) => `${n} إجابات خاطئة`,
    cards: () => 'بطاقات المراجعة',
    cardsWhy: (n) => `حان وقت مراجعة ${n} بطاقة`,
    weakWhy: (m) => `موضوع ضعيف · ${m}٪`,
    dueWhy: () => 'وقت المراجعة · قبل النسيان',
    teacherWhy: () => 'قال الأستاذ إنه سيأتي في الامتحان',
    pagesWhy: (a, b, n) => `ص. ${pages(a, b)} · بقي ${n} صفحة`,
    quiz: (t) => `${t} · حل الأسئلة`,
    quizWhy: () => 'ثبّت ما قرأته بالأسئلة',
    rExam: (c, k, d) => `${k} ${c}: ${d} · قُدّمت مراجعة الامتحان`,
    rWeak: (n) => `تتم مراجعة ${n} مواضيع ضعيفة`,
    rClass: () => 'في يوم المحاضرة تُقرأ تلك المادة',
    rBasic: () => 'أول أسبوعين: تُوزَّع المواد بالتساوي',
    rEmpty: () => 'لا توجد ملفات PDF بعد · ستمتلئ الخطة بعد رفع ملف',
  },
};

// ───────────── the planner ─────────────

type Task = {
  key: string;
  kind: Kind;
  target: Target;
  courseId: string | null;
  materialId: string | null;
  title: string;
  minutes: number;
  /** Tasks of one group keep their order (pages of one lesson). */
  group?: string;
  order?: number;
  prio: (day: string) => number;
  allowed: (day: string) => boolean;
  why: (day: string) => string;
  /** Placed reasons, to explain the plan. */
  tags?: string[];
};

/** Which of the remaining days of the week are study days: the ones with the fewest classes. */
export function studyDaysLeft(input: Pick<PlanInput, 'today' | 'studyDays' | 'classLoad' | 'courses'>) {
  const sunday = addDays(mondayOf(input.today), 6);
  const left: string[] = [];
  for (let d = input.today; d <= sunday; d = addDays(d, 1)) left.push(d);
  // In an exam week (an exam in the next 7 days) every day is a study day.
  const examSoon = input.courses.some((c) => c.exam && daysBetween(input.today, c.exam.date) >= 0 && daysBetween(input.today, c.exam.date) <= 7);
  const n = examSoon ? left.length : Math.min(left.length, Math.max(1, Math.round((input.studyDays * left.length) / 7)));
  return left
    .map((d) => ({ d, load: input.classLoad[weekday(d)] ?? 0 }))
    .sort((a, b) => a.load - b.load || a.d.localeCompare(b.d))
    .slice(0, n)
    .map((x) => x.d)
    .sort();
}

export function buildPlan(input: PlanInput): PlanOut {
  const T = TEXT[input.lang];
  const lang = input.lang;
  const weekStart = mondayOf(input.today);
  const course = new Map(input.courses.map((c) => [c.id, c]));
  const days = studyDaysLeft(input);

  // Exam pressure of a course on a day: up to +40 when the exam is close (14 days), 0 when it is past or far.
  const examBoost = (courseId: string | null, day: string) => {
    const e = courseId ? course.get(courseId)?.exam : null;
    if (!e) return 0;
    const d = daysBetween(day, e.date);
    return d < 0 || d > 14 ? 0 : 40 - 2 * d;
  };
  const classBoost = (courseId: string | null, day: string) => (courseId && course.get(courseId)?.classDays.includes(weekday(day)) ? 8 : 0);

  const pool: Task[] = [];

  // 1. Exam review in the 7 days before an exam (twice when it is 3 days away or less); the closer, the earlier.
  for (const c of input.courses) {
    if (!c.exam) continue;
    const left = daysBetween(input.today, c.exam.date);
    if (left < 1 || left > 14) continue;
    const exam = c.exam;
    const before = (day: string) => daysBetween(day, exam.date);
    for (let i = 0; i < (left <= 3 ? 2 : 1); i++) {
      pool.push({
        key: `exam:${c.id}:${i}`,
        kind: 'exam_prep',
        target: 'exam_prep',
        courseId: c.id,
        materialId: null,
        title: T.examPrep(c.name),
        minutes: 30,
        group: `exam:${c.id}`,
        order: i,
        prio: (day) => 60 + 6 * (EXAM_WINDOW - before(day)),
        allowed: (day) => before(day) >= 1 && before(day) <= EXAM_WINDOW,
        why: (day) => T.examWhy(EXAM[lang][exam.kind], dayMonth(exam.date, lang), daysBetween(day, exam.date)),
        tags: ['exam'],
      });
    }
  }

  // 2. Wrong answers ("Hatalarım" cards), once a week.
  if (input.mistakeCards > 0) {
    pool.push({
      key: 'mistakes',
      kind: 'mistakes',
      target: 'cards',
      courseId: null,
      materialId: null,
      title: T.mistakes(),
      minutes: 15,
      prio: () => 75,
      allowed: () => true,
      why: () => T.mistakesWhy(input.mistakeCards),
    });
  }

  // 3. Cards that are due: about one short session per 15 cards, at most one a day.
  const cardSessions = Math.min(days.length, Math.ceil(input.dueCards / 15));
  for (let i = 0; i < cardSessions; i++) {
    pool.push({
      key: `cards:${i}`,
      kind: 'cards',
      target: 'cards',
      courseId: null,
      materialId: null,
      title: T.cards(),
      minutes: 10,
      group: 'cards',
      order: i,
      prio: () => 45,
      allowed: () => true,
      why: () => T.cardsWhy(input.dueCards),
    });
  }

  // 4. Topics to repeat: weak ones (from quizzes); the smart plan also repeats before forgetting and what the
  //    lecturer said will be in the exam.
  for (const [i, tp] of input.topics.entries()) {
    const smart = input.stage === 'smart';
    if (!tp.weak && !(smart && (tp.dueOn || tp.teacherSaidExam))) continue;
    pool.push({
      key: `topic:${i}`,
      kind: 'review',
      target: 'reader',
      courseId: tp.courseId,
      materialId: tp.materialId,
      title: tp.title,
      minutes: 15,
      prio: (day) => 55 + tp.importance * 5 + examBoost(tp.courseId, day) / 2 + (smart && tp.teacherSaidExam ? 10 : 0),
      allowed: (day) => !smart || !tp.dueOn || tp.weak || tp.dueOn <= day,
      why: () => (smart && tp.teacherSaidExam ? T.teacherWhy() : tp.weak ? T.weakWhy(tp.mastery ?? 0) : T.dueWhy()),
      tags: tp.weak ? ['weak'] : [],
    });
  }

  // 5. Pages not read yet, in parts of about 25 minutes, in page order (at most 6 parts of a lesson a week).
  for (const l of input.lessons) {
    const read = new Set(l.pagesRead);
    const unread: number[] = [];
    for (let p = 1; p <= l.pages; p++) if (!read.has(p)) unread.push(p);
    for (let i = 0; i < 6 && i * PAGES_PER_TASK < unread.length; i++) {
      const part = unread.slice(i * PAGES_PER_TASK, (i + 1) * PAGES_PER_TASK);
      const leftAfter = unread.length - i * PAGES_PER_TASK;
      pool.push({
        key: `read:${l.id}:${i}`,
        kind: 'read',
        target: 'reader',
        courseId: l.courseId,
        materialId: l.id,
        title: l.title,
        minutes: Math.min(30, Math.max(10, round5(part.length * MIN_PER_PAGE))),
        group: `read:${l.id}`,
        order: i,
        prio: (day) => 50 + examBoost(l.courseId, day) / 2 + classBoost(l.courseId, day) - 3 * i,
        allowed: () => true,
        why: () => T.pagesWhy(part[0], part[part.length - 1], leftAfter),
        tags: [],
      });
    }
  }

  // 6. Questions of a lesson that is at least half read.
  for (const l of input.lessons) {
    if (!l.hasQuiz || !l.pages || l.pagesRead.length / l.pages < 0.5) continue;
    pool.push({
      key: `quiz:${l.id}`,
      kind: 'quiz',
      target: 'quiz',
      courseId: l.courseId,
      materialId: l.id,
      title: T.quiz(l.title),
      minutes: 10,
      prio: (day) => 40 + examBoost(l.courseId, day),
      allowed: () => true,
      why: () => T.quizWhy(),
    });
  }

  // Fill the days, most important first. A course that already has tasks this week gets a bit less
  // (courses are split evenly); a day has at most 2 tasks of one course, 2 exam reviews and one of each group.
  const placed = new Set<string>();
  const perCourseWeek = new Map<string, number>();
  const items: Item[] = [];
  const used = { exam: false, weak: 0, classDay: false };
  for (const day of days) {
    let budget = input.minutesPerDay - (day === input.today ? input.doneToday : 0);
    const perCourseDay = new Map<string, number>();
    const groupsToday = new Set<string>();
    let examsToday = 0;
    let order = 0;
    while (budget >= 10) {
      let best: Task | null = null;
      let bestScore = -Infinity;
      for (const t of pool) {
        if (placed.has(t.key) || !t.allowed(day)) continue;
        if (t.minutes > budget) continue;
        if (t.courseId && t.kind !== 'exam_prep' && (perCourseDay.get(t.courseId) ?? 0) >= PER_COURSE_DAY) continue;
        if (t.group && groupsToday.has(t.group) && t.kind !== 'read') continue;
        if (t.kind === 'exam_prep' && examsToday >= EXAM_PER_DAY) continue;
        // Parts of a lesson in order.
        if (t.group && t.order && !placed.has(t.key.replace(/:\d+$/, `:${t.order - 1}`))) continue;
        // Exam reviews keep their place however much of the course is planned already.
        const score = t.prio(day) - (t.courseId && t.kind !== 'exam_prep' ? 6 * (perCourseWeek.get(t.courseId) ?? 0) : 0);
        if (score > bestScore) {
          best = t;
          bestScore = score;
        }
      }
      if (!best) break;
      const minutes = best.minutes;
      placed.add(best.key);
      if (best.group) groupsToday.add(best.group);
      if (best.courseId && best.kind !== 'exam_prep') {
        perCourseDay.set(best.courseId, (perCourseDay.get(best.courseId) ?? 0) + 1);
        perCourseWeek.set(best.courseId, (perCourseWeek.get(best.courseId) ?? 0) + 1);
      }
      if (best.kind === 'exam_prep') examsToday++;
      if (best.tags?.includes('exam')) used.exam = true;
      if (best.tags?.includes('weak')) used.weak++;
      if (best.kind === 'read' && classBoost(best.courseId, day)) used.classDay = true;
      items.push({
        day,
        course_id: best.courseId,
        material_id: best.materialId,
        kind: best.kind,
        title: best.title,
        minutes,
        why: best.why(day),
        target: best.target,
        sort_order: order++,
      });
      budget -= minutes;
    }
  }

  // Why the plan looks like this (at most 4 lines).
  const reasons: Reason[] = [];
  const next = input.courses
    .filter((c) => c.exam && daysBetween(input.today, c.exam.date) >= 0)
    .sort((a, b) => a.exam!.date.localeCompare(b.exam!.date))[0];
  if (next && used.exam) reasons.push({ text: T.rExam(next.name, EXAM[lang][next.exam!.kind], dayMonth(next.exam!.date, lang)), color: 'pri' });
  if (used.weak) reasons.push({ text: T.rWeak(used.weak), color: 'amb' });
  if (used.classDay) reasons.push({ text: T.rClass(), color: 'good' });
  if (input.stage === 'basic') reasons.push({ text: T.rBasic(), color: 'good' });
  if (!input.lessons.length) reasons.push({ text: T.rEmpty(), color: 'amb' });
  return { weekStart, items, reasons: reasons.slice(0, 4) };
}

/**
 * "Bugün az vaktim var": today only the 2 most important tasks stay; the others move to the coming study days
 * of this week (the day with the fewest minutes first). Returns the new day of each moved task.
 */
export function lightDay(
  today: string,
  todayTasks: { id: string; minutes: number; sort_order: number }[],
  laterLoad: Record<string, number>,
): { keep: string[]; move: { id: string; day: string }[] } {
  const sorted = [...todayTasks].sort((a, b) => a.sort_order - b.sort_order);
  const keep = sorted.slice(0, 2).map((x) => x.id);
  const load = new Map(Object.entries(laterLoad).filter(([d]) => d > today));
  // No later study day this week: tomorrow (if it is still this week).
  if (!load.size && weekday(today) < 7) load.set(addDays(today, 1), 0);
  const move: { id: string; day: string }[] = [];
  for (const x of sorted.slice(2)) {
    if (!load.size) break;
    const [day] = [...load.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]))[0];
    load.set(day, (load.get(day) ?? 0) + x.minutes);
    move.push({ id: x.id, day });
  }
  return { keep, move };
}
