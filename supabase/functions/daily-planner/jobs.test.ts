// Run: node --experimental-strip-types supabase/functions/daily-planner/jobs.test.ts
import { localNow, pickReview, planNotice, reviewNotice, safeZone, weeklyNotice, zonedToUtc, type ReviewLesson, type ReviewTopic } from './jobs.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

// time zones
const n = new Date('2026-10-27T01:30:00Z');
check('Istanbul 04:30 on the same day', JSON.stringify(localNow(n, 'Europe/Istanbul')) === JSON.stringify({ date: '2026-10-27', hour: 4, weekday: 2 }));
check('New York is still the day before', localNow(n, 'America/New_York').date === '2026-10-26');
check('Tehran +3:30', localNow(n, 'Asia/Tehran').hour === 5);
check('09:00 Istanbul = 06:00 UTC', zonedToUtc('2026-10-27', '09:00:00', 'Europe/Istanbul') === '2026-10-27T06:00:00.000Z');
check('09:00 Berlin in summer = 07:00 UTC', zonedToUtc('2026-07-01', '09:00', 'Europe/Berlin') === '2026-07-01T07:00:00.000Z');
check('09:00 Berlin in winter = 08:00 UTC', zonedToUtc('2026-11-02', '09:00', 'Europe/Berlin') === '2026-11-02T08:00:00.000Z');
check('09:00 Berlin on the change day (25 Oct)', zonedToUtc('2026-10-25', '09:00', 'Europe/Berlin') === '2026-10-25T08:00:00.000Z');
check('bad time zone falls back to Istanbul', safeZone('Mars/Base') === 'Europe/Istanbul' && safeZone('Asia/Tehran') === 'Asia/Tehran');

// review
const today = '2026-10-27';
const L = (id: string, o: Partial<ReviewLesson> = {}): ReviewLesson => ({ id, courseId: 'c', dueCards: 0, questions: 6, hasSummary: true, examInDays: null, ...o });
const T = (id: string, materialId: string, o: Partial<ReviewTopic> = {}): ReviewTopic => ({ id, materialId, title: id, weak: false, dueOn: null, teacherSaidExam: false, ...o });
check('nothing to repeat → no review', pickReview(today, [L('a'), L('b')], [T('t1', 'a'), T('t2', 'b', { dueOn: '2026-11-01' })]) === null);
const r1 = pickReview(today, [L('a'), L('b')], [T('t1', 'a', { dueOn: today }), T('t2', 'b', { weak: true }), T('t3', 'b', { weak: true })])!;
check('weakest lesson wins', r1.material_id === 'b' && r1.content.topics.length === 2 && r1.content.topics[0].reason === 'weak');
check('3 questions at most', r1.content.questions === 3);
check('minutes between 5 and 15', r1.minutes >= 5 && r1.minutes <= 15);
const r2 = pickReview(today, [L('a', { dueCards: 30 }), L('b', { examInDays: 3 })], [T('t1', 'b', { teacherSaidExam: true })])!;
check('exam soon + lecturer topic beats many cards', r2.material_id === 'b' && r2.content.topics[0].reason === 'lecturer');
const r3 = pickReview(today, [L('a', { dueCards: 30, questions: 0, hasSummary: false })], [])!;
check('cards only: 10 cards, no questions, no summary', r3.content.cards === 10 && r3.content.questions === 0 && !r3.content.summary && r3.minutes === 5);
check('exam passed does not count', pickReview(today, [L('a', { examInDays: -1 })], [T('t', 'a', { teacherSaidExam: true })]) === null);

// texts
check('plan text tr', planNotice('tr', 3, 95, 'Diyabet').body === '3 görev · 1 sa 35 dk · ilk: Diyabet');
check('review text en', reviewNotice('en', 'Diabetes', 8, 6, 3).title === 'Review day today');
check('weekly without quizzes', weeklyNotice('tr', 200, 4, null).body === 'Geçen hafta: 3 sa 20 dk · 4 gün');
check('weekly with quizzes', weeklyNotice('en', 45, 2, 77.6).body.endsWith('quiz average 78%'));

if (fails) process.exit(1);
