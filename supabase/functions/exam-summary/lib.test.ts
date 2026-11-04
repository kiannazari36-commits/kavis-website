// Run: node --experimental-strip-types supabase/functions/exam-summary/lib.test.ts
import { buildDoc, citedPages, mismatch, pageList, pageTexts, pickPages, searchTerms, tsQuery, type Topic } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const topics: Topic[] = [
  { title: 'Antitüberküloz ilaçlar', questions: 7, lessonTitle: 'Tüberküloz ve Lepra', pages: [3, 4, 5, 11], styles: ['knowledge', 'side_effects'], points: ['Rifampisin idrarı boyar'], examples: ['Hangisi rifampisinin yan etkisidir?'], parts: [{ heading: 'Birinci basamak', text: 'İzoniyazid, rifampisin.' }, { heading: 'Yan etkiler', text: 'Hepatit.' }] },
  { title: 'Anemi', questions: 6, lessonTitle: 'vitaminler', pages: [22, 23, 24, 25], styles: ['knowledge'], points: [], examples: [], parts: [{ heading: 'Tanım', text: 'Hb sınırları.' }] },
];
const doc = buildDoc('tr', topics);
check('overview first, one section per topic', doc.sections.length === 3 && doc.sections[0].blocks[0].pageFrom === 1);
check('overview line names pdf, pages, style and count', doc.sections[0].blocks[0].paragraphs[0].text === 'Antitüberküloz ilaçlar — PDF: Tüberküloz ve Lepra, s. 3-5, 11 — Bilgi, Yan etki — 7 soru');
check('overview table has a header and one row per topic', doc.sections[0].blocks[0].table?.head.length === 4 && doc.sections[0].blocks[0].table?.rows[1].join('|') === 'Anemi|vitaminler · s. 22-25|Bilgi|6');
check('topic page numbers follow the overview', doc.sections[1].blocks.every((b) => b.pageFrom === 2) && doc.sections[2].blocks.every((b) => b.pageFrom === 3));
check('empty points and examples are left out', doc.sections[2].blocks.length === 1);
check('first part heading carries the explanation label', doc.sections[1].blocks[0].heading === 'Konu anlatımı · Birinci basamak');
const pages = pageTexts('tr', topics);
check('one text per page', pages.length === 3 && pages[2].page === 3 && pages[1].text.includes('Rifampisin idrarı boyar'));

// A topic the PDFs do not explain, and figure questions listed apart.
const missing: Topic = { title: 'Plazmoliz', questions: 1, lessonTitle: 'Hücre', pages: [], styles: ['knowledge'], points: [], examples: [], parts: [] };
const doc2 = buildDoc('tr', [missing], ['Örnek 3: şekil sorusu, konu okunamadı']);
check('not found topic says so in the table', doc2.sections[0].blocks[0].table?.rows[0][1] === 'PDF’te bulunamadı');
check('not found topic page says so', doc2.sections[1].blocks[0].paragraphs[0].text === 'PDF’te bulunamadı');
check('figure questions get their own block', doc2.sections[0].blocks[1]?.heading === 'Konusu çıkarılamayan sorular' && doc2.sections[0].blocks[1].paragraphs[0].text.startsWith('Örnek 3'));
check('not found in the assistant text too', pageTexts('en', [missing])[1].text.includes('Not found in the PDFs'));

check('page list is short', pageList([12, 3, 4, 5, 4]) === '3-5, 12' && pageList([7]) === '7');
const terms = searchTerms(['Hipertonik ortam', 'plazmoliz', 'hücre', 've']);
check('search words: lower case, no common words', terms.join() === 'hipertonik,ortam,plazmoliz,hücre');
check('long search words by their first letters', tsQuery(terms) === 'hipert:* | ortam:* | plazmo:* | hücre:*');
const chunks = [
  { material_id: 'A', page: 4, text: 'Hücre zarı ve taşıma.' },
  { material_id: 'B', page: 10, text: 'Hipertonik ortamda hücre su kaybeder: plazmoliz.' },
  { material_id: 'B', page: 11, text: 'Plazmoliz bitki hücresinde görülür; hipertonik çözelti.' },
  { material_id: 'B', page: 30, text: 'Hücre bölünmesi.' },
  { material_id: 'A', page: 2, text: 'Hipertansiyon tedavisi' },
];
const place = pickPages(chunks, terms, { materialId: 'A', from: 2, to: 4 });
check('the lesson whose text has the words wins over the guess', place?.materialId === 'B');
check('only the pages with enough of the words', place?.pages.join() === '10,11');
check('no page with enough words: null', pickPages(chunks, ['farmakokinetik', 'klirens'], null) === null);
check('the guess breaks a tie', pickPages([{ material_id: 'A', page: 1, text: 'izoniyazid rifampisin' }, { material_id: 'B', page: 1, text: 'izoniyazid rifampisin' }], ['izoniyazid', 'rifampisin'], { materialId: 'B', from: 1, to: 1 })?.materialId === 'B');
check('cited pages, only those given', citedPages([{ text: 'Dapson (s. 6). Klofazimin (s. 5), ayrıca (s. 40).' }], [4, 5, 6])?.join() === '5,6');
check('no citation: null', citedPages([{ text: 'Metin.' }], [1]) === null);
check('English and Persian citations', citedPages([{ text: 'Dose (p. 3).' }, { text: 'دوز (ص. 4)' }], [3, 4])?.join() === '3,4');
check('mismatch: most topics not found', mismatch([null, null, { pages: [1] }]) && !mismatch([null, { pages: [1] }]) && !mismatch([]));
if (fails) process.exit(1);
