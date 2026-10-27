// Run: node --experimental-strip-types supabase/functions/process-material/lib.test.ts
import { batches, cleanHints, costUsd, looksGarbled, markTerms, paragraphsOf, plain, readyNotice } from './lib.ts';

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
const opts = ['Dışkıyla atılırlar', 'B grubu depolanmaz', 'Provitaminleri vardır'];
const kept = cleanHints(['(s. 5) Depolanma satırına bakın.', 'Suda eriyenler yağ dokusunda birikmez.', 'B grubu depolanmaz.'], opts, 1);
check('a hint that states the answer is removed', kept.length === 2 && !kept.some((h) => h.includes('B grubu')));
check('hints that do not give it away are kept', cleanHints(['Depolanmaya bak.'], opts, 1).length === 1);
check('answer check ignores case', cleanHints(['b GRUBU depolanmaz işte'], opts, 1).length === 0);
check('page reference is cut out of a hint', cleanHints(['(s. 4) Yağda eriyenler A, D, E, K harfleriyle hatırlanır.'], opts, 1)[0] === 'Yağda eriyenler A, D, E, K harfleriyle hatırlanır.');
check('a hint that only points to a page is dropped', cleanHints(['(s. 5)', 'sayfa 5'], opts, 1).length === 0);
const st = { pages: 5, terms: 4, cards: 4, questions: 2 };
check('ready notice in Turkish', readyNotice('tr', 'Vitaminler', st).title === 'Vitaminler dersin hazır');
check('ready notice in English', readyNotice('en', 'Vitamins', st).body === '5 pages · 4 terms · 4 cards · 2 questions prepared.');
check('unknown language → Turkish', readyNotice('de', 'X', {}).body.startsWith('0 sayfa'));
// The same text as the real broken PDF: every character moved by 29 (what a font without a text map gives).
const shift = (t: string) => [...t].map((c) => String.fromCharCode(c.charCodeAt(0) - 29)).join('');
const garbled = shift('Fizyoloji Nedir? Canlı organizmalardaki yapısal ve fonksiyonel işleyişi inceleyen bilim dalıdır. ').repeat(4);
check('garbled font text is detected', looksGarbled([garbled.repeat(3)]));
check('normal Turkish text is not garbled', !looksGarbled([page.repeat(4)]));
check('short text is never judged', !looksGarbled(['xyz\\]']));
check('Persian text is not judged', !looksGarbled(['فیزیولوژی علم مطالعه عملکرد موجودات زنده است و '.repeat(12)]));
if (fails) process.exit(1);
