// Run: node --experimental-strip-types web/src/audio/chapters.test.ts
import { buildChapters, sentences } from './chapters.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  if (!ok) fails++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
};

const topic = (id: string, title: string, from: number, to: number, more: object = {}) => ({
  id, title, page_from: from, page_to: to, importance: 1, teacher_minutes: null, teacher_repeats: null, teacher_said_exam: false, ...more,
});
const topics = [
  topic('a', 'Tanım', 1, 2),
  topic('b', 'ACE inhibitörleri', 3, 4, { teacher_said_exam: true }),
  topic('c', 'Tiyazidler', 5, 6, { teacher_minutes: 9 }),
  topic('d', 'Hipertansif kriz', 7, 8),
  topic('e', 'Gebelik', 9, 9, { importance: 3 }),
  topic('f', 'Diğer', 10, 12),
];
const points = [
  { text: 'Tanım bir. Tanım iki.', page_from: 1, page_to: 1 },
  { text: 'ACE öksürük yapar.', page_from: 3, page_to: 3 },
  { text: 'Tiyazid gut.', page_from: 5, page_to: 6 },
  { text: 'Kriz 180/120.', page_from: 7, page_to: 7, weak: true },
  { text: 'Kriz %25 düşür.', page_from: 8, page_to: 8, weak: true },
  { text: 'Gebelikte metildopa.', page_from: 9, page_to: 9 },
  { text: 'Son not.', page_from: 11, page_to: 11 },
  { text: 'Sayfasız konu.', page_from: 20, page_to: 20 },
];
const ch = buildChapters(points, topics, [{ id: 'd', title: 'Hipertansif kriz', page: 7, mastery: 38, sure: false }]);

check('at most 5 parts', ch.length === 5);
check('weak topic first, with its mastery', ch[0].title === 'Hipertansif kriz' && ch[0].tag.k === 'weak' && 'n' in ch[0].tag && ch[0].tag.n === 38);
check('points of one topic are one part', ch[0].sentences.length === 2 && ch[0].pageFrom === 7 && ch[0].pageTo === 8);
check('then "sınavda soruyorum", minutes, importance', ch[1].tag.k === 'exam' && ch[2].tag.k === 'minutes' && ch[3].tag.k === 'important');
check('then the rest in page order', ch[4].title === 'Tanım' && ch[4].tag.k === 'summary');
check('a point outside every topic has no title (pages are shown)', buildChapters([points[7]], topics, [])[0].title === '');
check('sentences split at . ! ? and the Persian question mark', sentences('Bir. İki! Üç? چهار؟ پنج').length === 5);
check('no points → no parts', buildChapters([], topics, []).length === 0);

if (fails) process.exit(1);
