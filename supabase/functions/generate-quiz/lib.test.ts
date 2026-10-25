// Run: node --experimental-strip-types supabase/functions/generate-quiz/lib.test.ts
import { cleanHints, pickPages } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
check('hint with the answer dropped', cleanHints(['Antidotu NAC değildir mi?', 'Toksik metaboliti düşün.'], ['NAC', 'Atropin'], 0).length === 1);
check('page reference cut', cleanHints(['Bak sayfa 4 tekrar düşün'], ['A', 'B'], 0)[0] === 'Bak tekrar düşün');
const pages = [
  { lesson: 1, page: 1, text: 'a'.repeat(1000), weight: 0 },
  { lesson: 1, page: 2, text: 'b'.repeat(1000), weight: 5 },
  { lesson: 2, page: 1, text: 'c'.repeat(1000), weight: 3 },
];
const picked = pickPages(pages, 2100);
check('most important pages first, within the limit', picked.length === 2 && picked.every((p) => p.weight > 0));
check('returned in lesson and page order', picked[0].lesson === 1 && picked[1].lesson === 2);
check('long pages shortened', pickPages([{ lesson: 1, page: 1, text: 'x'.repeat(5000), weight: 1 }], 9999, 1200)[0].text.length === 1200);
if (fails) process.exit(1);
