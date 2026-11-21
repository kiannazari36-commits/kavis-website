// Run: node --experimental-strip-types web/src/i18n/legalView.test.ts
import { cleanParagraph, cleanUpdated, visibleDoc } from './legalView.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
check('tr note removed', cleanParagraph('Hizmet olduğu gibi sunulur. [AVUKAT KONTROL EDECEK: sorumluluk sınırı]') === 'Hizmet olduğu gibi sunulur.');
check('en note removed', cleanParagraph('Data stored in the EU. [LAWYER TO CHECK]') === 'Data stored in the EU.');
check('en registration note removed', cleanParagraph('Contact: a@b.c. [Registration / EU representative details – to be set by a lawyer]') === 'Contact: a@b.c.');
check('tr VERBİS note removed', cleanParagraph('İletişim: a@b.c. [VERBİS / AB temsilcisi bilgisi – avukat belirleyecek]') === 'İletişim: a@b.c.');
check('fa note removed', cleanParagraph('متن. [وکیل بررسی کند: حدود]') === 'متن.');
check('ar note removed', cleanParagraph('نص. [على المحامي المراجعة: حدود المسؤولية]') === 'نص.');
check('other brackets stay', cleanParagraph('Kural [1] geçerli.') === 'Kural [1] geçerli.');
check('a paragraph of only a note is dropped', cleanParagraph('[LAWYER TO CHECK]') === null);
check('draft mark removed from the date', cleanUpdated('Son güncelleme: 27 Ekim 2026 (taslak)') === 'Son güncelleme: 27 Ekim 2026' && cleanUpdated('Last updated: 27 October 2026 (draft)') === 'Last updated: 27 October 2026');
const doc = { title: 't', sections: [{ h: 'h', p: ['a [LAWYER TO CHECK]', '[LAWYER TO CHECK]', 'b'] }] };
check('visible draft → unchanged', visibleDoc(doc, true) === doc);
check('hidden draft → notes stripped, empty paragraphs gone', JSON.stringify(visibleDoc(doc, false).sections[0].p) === '["a","b"]');
if (fails) process.exit(1);
