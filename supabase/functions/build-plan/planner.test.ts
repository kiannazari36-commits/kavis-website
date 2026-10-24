// Run: node --experimental-strip-types supabase/functions/build-plan/planner.test.ts
import { addDays, buildPlan, lightDay, mondayOf, studyDaysLeft, weekday, type PlanInput } from './planner.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

// Wednesday 14 Oct 2026; exams far away unless a test sets one.
const base: PlanInput = {
  today: '2026-10-14',
  lang: 'tr',
  stage: 'basic',
  studyDays: 4,
  minutesPerDay: 90,
  courses: [
    { id: 'A', name: 'Farmakoterapi', exam: null, classDays: [1] },
    { id: 'B', name: 'Toksikoloji', exam: null, classDays: [2] },
  ],
  lessons: [
    { id: 'L1', courseId: 'A', title: 'Hipertansiyon', pages: 48, pagesRead: [], hasQuiz: true },
    { id: 'L2', courseId: 'B', title: 'Ağır metaller', pages: 34, pagesRead: [], hasQuiz: false },
    { id: 'L3', courseId: 'B', title: 'Organofosfatlar', pages: 28, pagesRead: [], hasQuiz: false },
  ],
  topics: [],
  dueCards: 0,
  mistakeCards: 0,
  classLoad: { 1: 110, 2: 110, 3: 240, 4: 110, 5: 110 },
  doneToday: 0,
};

check('dates: weekday and Monday', weekday('2026-10-14') === 3 && mondayOf('2026-10-14') === '2026-10-12' && mondayOf('2026-10-18') === '2026-10-12');

const days = studyDaysLeft(base);
check('study days: share of the 5 days left, fewest classes first', days.length === 3 && !days.includes('2026-10-14') && days.includes('2026-10-17') && days.includes('2026-10-18'));

const p = buildPlan(base);
const perDay = (d: string) => p.items.filter((x) => x.day === d).reduce((a, x) => a + x.minutes, 0);
check('no day over the daily time', days.every((d) => perDay(d) <= 90));
check('days are filled', days.every((d) => perDay(d) >= 70));
check('only study days get tasks', p.items.every((x) => days.includes(x.day)));
check('pages of a lesson in order', (() => {
  const parts = p.items.filter((x) => x.material_id === 'L1' && x.kind === 'read').map((x) => x.why);
  return parts.length > 0 && parts[0].startsWith('s. 1–12');
})());
check('courses are mixed', new Set(p.items.map((x) => x.course_id)).size === 2);
check('at most 2 tasks of a course on a day', days.every((d) => ['A', 'B'].every((c) => p.items.filter((x) => x.day === d && x.course_id === c).length <= 2)));
check('basic plan says so', p.reasons.some((r) => r.text.startsWith('İlk 2 hafta')));

// Exam in 3 days: every day is a study day, exam review first, twice, never on or after the exam day.
const exam = buildPlan({ ...base, courses: [{ ...base.courses[0], exam: { date: '2026-10-17', kind: 'midterm' } }, base.courses[1]] });
const prep = exam.items.filter((x) => x.kind === 'exam_prep');
check('exam week: every day left is a study day', new Set(exam.items.map((x) => x.day)).size >= 3);
check('exam review twice, before the exam', prep.length === 2 && prep.every((x) => x.day < '2026-10-17') && prep[0].day !== prep[1].day);
check('exam review first on its day', exam.items.find((x) => x.day === '2026-10-14')?.kind === 'exam_prep');
check('exam reason', exam.reasons[0]?.text === 'Farmakoterapi vize: 17 Ekim · sınava özel tekrar öne alındı');
check('days left in the why', prep[0].why === 'Vize · 17 Ekim · 3 gün kaldı');

// Weak topics, wrong answers and due cards.
const more = buildPlan({
  ...base,
  dueCards: 20,
  mistakeCards: 4,
  topics: [{ courseId: 'A', materialId: 'L1', title: 'Hipertansif kriz', mastery: 33, importance: 3, weak: true, dueOn: null, teacherSaidExam: false }],
});
check('weak topic in the plan', more.items.some((x) => x.kind === 'review' && x.why === 'zayıf konun · %33'));
check('mistakes once', more.items.filter((x) => x.kind === 'mistakes').length === 1);
check('cards at most once a day', more.items.filter((x) => x.kind === 'cards').length === 2);

// Already done today is subtracted; English texts.
const en = buildPlan({ ...base, today: '2026-10-17', doneToday: 60, lang: 'en' });
check('done minutes count for today', en.items.filter((x) => x.day === '2026-10-17').reduce((a, x) => a + x.minutes, 0) <= 30);
check('English texts', en.items.some((x) => x.why.startsWith('p. ')));
check('no lessons → reason', buildPlan({ ...base, lessons: [] }).reasons.some((r) => r.text.includes('PDF')));

// Many exams in one week: at most 2 exam reviews a day; a single page is written without a range.
const busy = buildPlan({
  ...base,
  courses: ['A', 'B', 'C', 'D'].map((id, i) => ({ id, name: id, exam: { date: addDays('2026-10-14', 3 + i), kind: 'midterm' as const }, classDays: [] })),
  lessons: [{ id: 'L9', courseId: 'A', title: 'Kısa', pages: 13, pagesRead: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], hasQuiz: false }],
});
check('at most 2 exam reviews a day', [...new Set(busy.items.map((x) => x.day))].every((d) => busy.items.filter((x) => x.day === d && x.kind === 'exam_prep').length <= 2));
check('one page without a range', busy.items.some((x) => x.why === 's. 13 · 1 sayfa kaldı'));

// "Bugün az vaktim var"
const light = lightDay('2026-10-14', [
  { id: 'a', minutes: 30, sort_order: 0 },
  { id: 'b', minutes: 20, sort_order: 1 },
  { id: 'c', minutes: 25, sort_order: 2 },
  { id: 'd', minutes: 15, sort_order: 3 },
], { '2026-10-16': 60, '2026-10-17': 30 });
check('light day keeps the 2 first', light.keep.join() === 'a,b');
check('light day moves the rest to the emptiest days', light.move.map((m) => m.day).join() === '2026-10-17,2026-10-17');
check('Sunday: nothing to move to', lightDay('2026-10-18', [{ id: 'a', minutes: 5, sort_order: 0 }, { id: 'b', minutes: 5, sort_order: 1 }, { id: 'c', minutes: 5, sort_order: 2 }], {}).move.length === 0);

if (fails) process.exit(1);
