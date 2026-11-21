// Run: node --experimental-strip-types supabase/functions/process-material/ocr.test.ts
import { joinWrappedLines, pageTexts, toBase64 } from './ocr.ts';

let fails = 0;
const check = (name: string, ok: boolean) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
  if (!ok) fails++;
};
check('base64 of text', toBase64(new TextEncoder().encode('Kavis')) === btoa('Kavis'));
const big = new Uint8Array(200_000).map((_, i) => i % 256);
check('base64 of a large file', atob(toBase64(big)).length === 200_000);
const texts = pageTexts({ pages: [{ page: 6, text: ' B ' }, { page: 5, text: 'A' }] }, 5, 7);
check('pages in order, missing page empty', JSON.stringify(texts) === '["A","B",""]');
check('wrapped lines of one paragraph are joined', joinWrappedLines('Beta-blokerler adrenerjik\nreseptörleri bloke eder ve\nkalp hızını düşürür.') === 'Beta-blokerler adrenerjik reseptörleri bloke eder ve kalp hızını düşürür.');
check('heading, bullets and sentence ends stay apart', joinWrappedLines('Giriş\nBu bir cümle.\nİkinci cümle başlar\n• madde bir\n• madde iki') === 'Giriş\nBu bir cümle.\nİkinci cümle başlar\n• madde bir\n• madde iki');
check('table rows are never joined', joinWrappedLines('İlaç | Etki\nPropranolol | seçici değil\nmetoprolol | beta-1') === 'İlaç | Etki\nPropranolol | seçici değil\nmetoprolol | beta-1');
check('a word broken with a hyphen is joined back', joinWrappedLines('hipertansi-\nyon tedavisinde') === 'hipertansiyon tedavisinde');
check('words never change', joinWrappedLines('a b\nc d').replace(/\s+/g, ' ') === 'a b\nc d'.replace(/\s+/g, ' '));
if (fails) process.exit(1);
