// Run: node --experimental-strip-types supabase/functions/assistant/lib.test.ts
import { costUsd, lessonText, queryTerms, rankChunks, tsQuery } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const q = queryTerms('ACE inhibitörleri neden kuru öksürük yapar?');
check('common words dropped, case lowered', JSON.stringify(q) === '["ace","inhibitörleri","kuru","öksürük","yapar"]');
check('long words become 6-letter prefixes', tsQuery(['inhibitörleri', 'ace']) === 'inhibi:* | ace:*');
check('Turkish ending still matches', rankChunks([{ text: 'Hipertansiyonda ilk basamak' }], queryTerms('hipertansiyon tedavisi'), 5).length === 1);
const chunks = [{ text: 'Diüretikler tuz atılımını artırır.' }, { text: 'ACE inhibitörleri bradikinin birikimiyle kuru öksürük yapar.' }, { text: 'ACE enzimi.' }];
const top = rankChunks(chunks, q, 2);
check('best piece first', top[0] === chunks[1]);
check('pieces without any word are left out', !top.includes(chunks[0]));
check('empty question → no words', queryTerms('ne?').length === 0);
const doc = lessonText([{ page: 2, text: 'İki' }, { page: 1, text: ' Bir ' }], 1000);
check('whole lesson in page order', doc === '[Page 1]\nBir\n\n[Page 2]\nİki');
check('too long lesson → null', lessonText([{ page: 1, text: 'x'.repeat(50) }], 20) === null);
check('cost with cache', costUsd(1_000_000, 100_000, 1_000_000, 1_000_000) === 2 + 1 + 2.5 + 0.2);
if (fails) process.exit(1);
