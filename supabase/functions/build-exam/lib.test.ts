// Run: node --experimental-strip-types supabase/functions/build-exam/lib.test.ts
import { shortfall } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const a = shortfall(20, 12, 12);
check('fewer built than asked → short + reason', a.short === 8 && a.reason === 'not_enough_questions' && a.requested === 20 && a.built === 12 && a.available === 12);
const b = shortfall(20, 20, 50);
check('full exam → no reason', b.short === 0 && b.reason === null);
check('never negative', shortfall(5, 7, 7).short === 0);
if (fails) process.exit(1);
