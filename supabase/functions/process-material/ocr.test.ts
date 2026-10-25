// Run: node --experimental-strip-types supabase/functions/process-material/ocr.test.ts
import { pageTexts, toBase64 } from './ocr.ts';

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
if (fails) process.exit(1);
