// Run: node --experimental-strip-types supabase/functions/add-card/card.test.ts
import { termCard } from './card.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const ex = {
  tr: { name: 'Provitamin', kind: 'öncü madde', text: 'Vücutta aktif vitamine dönüşen öncül madde.' },
  en: { name: 'Provitamin', kind: 'precursor', text: 'A precursor turned into an active vitamin.' },
};
const tr = termCard(ex, 'tr', 'provitamin');
check('Turkish card', tr?.question === 'Provitamin nedir?' && tr.answer.startsWith('Vücutta') && tr.note === 'öncü madde');
check('content language wins', termCard(ex, 'en', 'x')?.question === 'What is Provitamin?');
check('missing language → Turkish', termCard(ex, 'ar', 'x')?.lang === 'tr');
check('no name → surface word', termCard({ tr: { text: 'Açıklama.' } }, 'tr', 'kolin')?.question === 'kolin nedir?');
check('no explanation → null', termCard({}, 'tr', 'x') === null);
if (fails) process.exit(1);
