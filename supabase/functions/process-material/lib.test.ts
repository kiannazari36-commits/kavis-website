// Run: node --experimental-strip-types supabase/functions/process-material/lib.test.ts
import { batches, costUsd, markTerms, paragraphsOf, plain } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};

const page = `Hipertansiyon nedir?
Hipertansiyon, tekrarlanan ölçümlerde sistolik kan basıncının 140 mmHg
veya üzerinde olmasıdır. Vakaların çoğu primer hiper-
tansiyon grubundadır.

İlk basamak tedavide diüretikler kullanılır.
• ACE inhibitörleri
• ARB'ler`;
const paras = paragraphsOf(page);
check('heading is its own paragraph', paras[0] === 'Hipertansiyon nedir?');
check('lines are joined into one sentence paragraph', paras[1].startsWith('Hipertansiyon, tekrarlanan') && paras[1].endsWith('grubundadır.'));
check('hyphenated word is joined back', paras[1].includes('primer hipertansiyon grubundadır'));
check('blank line starts a new paragraph', paras[2] === 'İlk basamak tedavide diüretikler kullanılır.');
check('bullets are separate paragraphs', paras[3] === '• ACE inhibitörleri' && paras[4] === "• ARB'ler");

const used = new Set<string>();
const segs = markTerms(paras[1], [{ key: 't1', surface: 'primer hipertansiyon' }, { key: 't2', surface: 'mmHg' }], used);
check('marking never changes the text', plain(segs) === paras[1]);
check('both terms are marked', segs.filter((x) => typeof x !== 'string').length === 2);
check('a term is marked only once in the lesson', markTerms(paras[1], [{ key: 't1', surface: 'primer hipertansiyon' }], used).length === 1);
check('case-insensitive match keeps the original spelling', (markTerms('ACE İnhibitörleri etkili', [{ key: 'x', surface: 'ace inhibitörleri' }], new Set())[0] as { text: string }).text === 'ACE İnhibitörleri');
check('no match inside another word', markTerms('antihipertansif', [{ key: 'y', surface: 'hipertansif' }], new Set()).length === 1);
check('batches of 8: 20 pages → 3', JSON.stringify(batches(20, 8)) === '[[1,8],[9,16],[17,20]]');
check('cost: 100k in + 10k out = $0.30', costUsd(100_000, 10_000) === 0.3);
if (fails) process.exit(1);
