// Run: node --experimental-strip-types supabase/functions/exam-summary/lib.test.ts
import { buildDoc, pageTexts, type Topic } from './lib.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
const topics: Topic[] = [
  { title: 'Antitüberküloz ilaçlar', questions: 7, lessonTitle: 'Tüberküloz ve Lepra', pageFrom: 3, pageTo: 11, styles: ['knowledge', 'side_effects'], points: ['Rifampisin idrarı boyar'], examples: ['Hangisi rifampisinin yan etkisidir?'], parts: [{ heading: 'Birinci basamak', text: 'İzoniyazid, rifampisin.' }, { heading: 'Yan etkiler', text: 'Hepatit.' }] },
  { title: 'Anemi', questions: 6, lessonTitle: 'vitaminler', pageFrom: 22, pageTo: 25, styles: ['knowledge'], points: [], examples: [], parts: [{ heading: 'Tanım', text: 'Hb sınırları.' }] },
];
const doc = buildDoc('tr', topics);
check('overview first, one section per topic', doc.sections.length === 3 && doc.sections[0].blocks[0].pageFrom === 1);
check('overview line names pdf, pages, style and count', doc.sections[0].blocks[0].paragraphs[0].text === 'Antitüberküloz ilaçlar — PDF: Tüberküloz ve Lepra, s. 3-11 — Bilgi, Yan etki — 7 soru');
check('overview table has a header and one row per topic', doc.sections[0].blocks[0].table?.head.length === 4 && doc.sections[0].blocks[0].table?.rows[1].join('|') === 'Anemi|vitaminler · s. 22-25|Bilgi|6');
check('topic page numbers follow the overview', doc.sections[1].blocks.every((b) => b.pageFrom === 2) && doc.sections[2].blocks.every((b) => b.pageFrom === 3));
check('empty points and examples are left out', doc.sections[2].blocks.length === 1);
check('first part heading carries the explanation label', doc.sections[1].blocks[0].heading === 'Konu anlatımı · Birinci basamak');
const pages = pageTexts('tr', topics);
check('one text per page', pages.length === 3 && pages[2].page === 3 && pages[1].text.includes('Rifampisin idrarı boyar'));
if (fails) process.exit(1);
