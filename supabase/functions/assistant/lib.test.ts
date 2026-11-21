// Run: node --experimental-strip-types supabase/functions/assistant/lib.test.ts
import { searchTargets, answerLang, costUsd, lessonText, queryTerms, rankChunks, splitTail, tsQuery } from './lib.ts';

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
check('haiku cost with cache', costUsd(1_000_000, 100_000, 1_000_000, 1_000_000, 'claude-haiku-5-5') === 0.285);
check('cost with cache', costUsd(1_000_000, 100_000, 1_000_000, 1_000_000) === 2 + 1 + 2.5 + 0.2);
const tail = splitTail('Cevap burada.\nİkinci satır.\nSOURCES: [2, 5, 2] OUTSIDE: no');
check('tail split off', tail.answer === 'Cevap burada.\nİkinci satır.' && tail.sources.join() === '2,5' && !tail.outside);
check('outside yes, empty sources', splitTail('A\nSOURCES: [] OUTSIDE: yes').outside && splitTail('A\nSOURCES: [] OUTSIDE: yes').sources.length === 0);
check('no tail line', splitTail('Sadece cevap').answer === 'Sadece cevap');
check('splitTail drops ** bold', splitTail('**Doz:** 4 g\nSOURCES: [] OUTSIDE: yes').answer === 'Doz: 4 g');


check('lang: Turkish question, interface en → tr', answerLang('Hoca derste neyi vurguladı?', 'en') === 'tr');
check('lang: "Bu sayfayı özetle" → tr', answerLang('Bu sayfayı özetle', 'en') === 'tr');
check('lang: English question, interface tr → en', answerLang('What did the teacher emphasize?', 'tr') === 'en');
check('lang: Persian letters → fa', answerLang('بتا بلوکرها چگونه کار می\u200cکنند؟', 'tr') === 'fa');
check('lang: Arabic → ar', answerLang('ما هي أعراض الدواء؟', 'tr') === 'ar');
check('lang: unclear term → interface language', answerLang('ACE?', 'tr') === 'tr' && answerLang('ACE?', 'en') === 'en' && answerLang('12', 'ar') === 'ar');
check('lang: Turkish without special letters', answerLang('Hoca bu konuyu nasil anlatti', 'en') === 'tr');
check('lang: "nothing found" style question stays tr', answerLang('Bu derste hoca neyi vurguladı, sınavda ne çıkar?', 'en') === 'tr');
check('search targets: Turkish question on a Persian lesson', JSON.stringify(searchTargets('tr', ['fa'])) === '["fa"]');
check('search targets: same language needs no translation', searchTargets('tr', ['tr', 'tr']).length === 0);
check('search targets: most common first, max 2', JSON.stringify(searchTargets('tr', ['fa', 'en', 'en', 'ar'])) === '["en","fa"]');
check('search targets: unknown / empty languages are ignored', searchTargets('en', [null, undefined, 'xx']).length === 0);
if (fails) process.exit(1);
