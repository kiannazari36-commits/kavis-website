// Run: node --experimental-strip-types supabase/functions/process-recording/lib.test.ts
import { cleanSegments, transcriptLines } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
check('not a list → null', cleanSegments('x') === null && cleanSegments([]) === null);
const segs = cleanSegments([{ start: 12.34, end: 15, text: ' iki ' }, { start: 0, end: 5, text: 'bir' }, { start: 'x', end: 1, text: 'bozuk' }, { start: 20, end: 25, text: '' }]);
check('cleaned, sorted, bad ones dropped', JSON.stringify(segs) === JSON.stringify([{ start: 0, end: 5, text: 'bir' }, { start: 12.3, end: 15, text: 'iki' }]));
const lines = transcriptLines([
  { start: 0, end: 8, text: 'a' },
  { start: 8, end: 21, text: 'b' },
  { start: 21, end: 30, text: 'c' },
]);
check('about 20-second lines with the start second', JSON.stringify(lines) === JSON.stringify(['[0] a b', '[21] c']));
if (fails) process.exit(1);
